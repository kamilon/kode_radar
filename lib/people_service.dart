import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'identity_store.dart';
import 'person.dart';
import 'repo_store.dart';
import 'token_store.dart';

class PeopleService {
  PeopleService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  static List<Person> aggregateGithub({
    required List<dynamic> prs,
    required DateTime now,
    Set<String> self = const {},
  }) {
    final selfLogins = self.map(_normalizeLogin).where(_isNotEmpty).toSet();
    final people = <String, _MutablePerson>{};

    for (final pr in prs) {
      if (pr is! Map) continue;
      if (pr['draft'] == true) continue;
      final state = _stringValue(pr, 'state');
      if (state != null && state.toLowerCase() != 'open') continue;

      final lastSeen = _dateValue(pr['created_at'], now);
      final authorLogin = _normalizeLogin(
        _nestedString(pr['user'], 'login') ?? '',
      );
      if (authorLogin.isNotEmpty) {
        final author = people.putIfAbsent(
          authorLogin,
          () => _MutablePerson.github(authorLogin),
        );
        author.authoredOpenPrs++;
        author.markSelf(selfLogins.contains(authorLogin));
        author.see(lastSeen);
      }

      final reviewers = pr['requested_reviewers'];
      if (reviewers is! List) continue;
      for (final reviewer in reviewers) {
        final login = _normalizeLogin(
          _nestedString(reviewer, 'login') ?? '',
        );
        if (login.isEmpty) continue;
        final person = people.putIfAbsent(
          login,
          () => _MutablePerson.github(login),
        );
        person.reviewRequests++;
        person.markSelf(selfLogins.contains(login));
        person.see(lastSeen);
      }
    }

    final result = people.values.map((person) => person.toPerson()).toList();
    _sortPeople(result);
    return result;
  }

  static List<Person> aggregateAdo({
    required List<dynamic> prs,
    required DateTime now,
    Set<String> self = const {},
  }) {
    final selfNames = self.map(_adoIdentity).where(_isNotEmpty).toSet();
    final people = <String, _MutablePerson>{};

    for (final pr in prs) {
      if (pr is! Map) continue;
      if (pr['isDraft'] == true) continue;
      final status = _stringValue(pr, 'status');
      if (status != null && status.toLowerCase() != 'active') continue;

      final lastSeen = _dateValue(pr['creationDate'], now);
      final authorName = _normalizeName(
        _nestedString(pr['createdBy'], 'displayName') ?? '',
      );
      final authorKey = _adoIdentity(authorName);
      if (authorKey.isNotEmpty) {
        final author = people.putIfAbsent(
          authorKey,
          () => _MutablePerson.ado(authorName),
        );
        author.authoredOpenPrs++;
        author.markSelf(selfNames.contains(authorKey));
        author.see(lastSeen);
      }

      final reviewers = pr['reviewers'];
      if (reviewers is! List) continue;
      for (final reviewer in reviewers) {
        // Only pending reviews (no vote yet) count as a review request, to
        // match GitHub's requested-reviewers semantics. ADO votes: 10 approved,
        // 5 approved-with-suggestions, 0 waiting, -5 waiting-for-author,
        // -10 rejected.
        final vote = reviewer is Map ? reviewer['vote'] : null;
        if (vote is int && vote != 0) continue;
        final name = _normalizeName(
          _nestedString(reviewer, 'displayName') ?? '',
        );
        final key = _adoIdentity(name);
        if (key.isEmpty) continue;
        final person = people.putIfAbsent(
          key,
          () => _MutablePerson.ado(name),
        );
        person.reviewRequests++;
        person.markSelf(selfNames.contains(key));
        person.see(lastSeen);
      }
    }

    final result = people.values.map((person) => person.toPerson()).toList();
    _sortPeople(result);
    return result;
  }

  static List<Person> mergePeople(List<Person> all) {
    if (all.isEmpty) return <Person>[];

    final parents = List<int>.generate(all.length, (index) => index);

    int find(int index) {
      var current = index;
      while (parents[current] != current) {
        parents[current] = parents[parents[current]];
        current = parents[current];
      }
      return current;
    }

    void union(int a, int b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) parents[rootB] = rootA;
    }

    final githubOwners = <String, int>{};
    final adoOwners = <String, int>{};

    for (var i = 0; i < all.length; i++) {
      for (final login in all[i].githubLogins) {
        final key = _normalizeLogin(login);
        if (key.isEmpty) continue;
        final existing = githubOwners[key];
        if (existing == null) {
          githubOwners[key] = i;
        } else {
          union(i, existing);
        }
      }

      for (final name in all[i].adoNames) {
        final key = _adoIdentity(name);
        if (key.isEmpty) continue;
        final existing = adoOwners[key];
        if (existing == null) {
          adoOwners[key] = i;
        } else {
          union(i, existing);
        }
      }
    }

    final groups = <int, _MutablePerson>{};
    for (var i = 0; i < all.length; i++) {
      final person = all[i];
      final root = find(i);
      final group = groups.putIfAbsent(
        root,
        () => _MutablePerson.person(person),
      );
      group.addPerson(person);
    }

    final result = groups.values.map((person) => person.toPerson()).toList();
    _sortPeople(result);
    return result;
  }

  static Future<List<Person>> computeAll({
    http.Client? client,
    int concurrency = 5,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final prefs = await SharedPreferences.getInstance();
      final githubRepos =
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[];
      final adoRepos =
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[];
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      final now = DateTime.now();
      final tasks = <Future<List<Person>> Function()>[];

      for (final raw in githubRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final owner = _stringValue(map, 'owner');
        final name = _stringValue(map, 'repoName');
        if (owner == null || name == null) continue;
        final tokenId = _stringValue(map, 'tokenId');
        tasks.add(
          () => _githubRepoPeople(
            httpClient,
            owner,
            name,
            tokenId,
            now,
            selfGithub,
          ),
        );
      }

      for (final raw in adoRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final organization = _stringValue(map, 'organization');
        final project = _stringValue(map, 'project');
        final name = _stringValue(map, 'repoName');
        if (organization == null || project == null || name == null) continue;
        final tokenId = _stringValue(map, 'tokenId');
        tasks.add(
          () => _adoRepoPeople(
            httpClient,
            organization,
            project,
            name,
            tokenId,
            now,
            selfAdo,
          ),
        );
      }

      final grouped = await _runBounded(tasks, concurrency);
      return mergePeople(grouped.expand((people) => people).toList());
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<List<Person>> _githubRepoPeople(
    http.Client client,
    String owner,
    String name,
    String? tokenId,
    DateTime now,
    Set<String> self,
  ) async {
    final repoDisplay = '$owner/$name';
    try {
      final secret =
          (await TokenStore.resolveGithubSecret(owner, tokenId: tokenId))
              ?.trim();
      if (secret == null || secret.isEmpty) return const <Person>[];

      final response = await client.get(
        Uri.https('api.github.com', '/repos/$owner/$name/pulls', {
          'state': 'open',
          'per_page': '100',
        }),
        headers: {
          'Authorization': 'Bearer $secret',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(_requestTimeout);
      if (response.statusCode != 200) return const <Person>[];

      final body = jsonDecode(response.body);
      if (body is! List) return const <Person>[];
      return aggregateGithub(
        prs: body,
        now: now,
        self: self,
      );
    } catch (e) {
      debugPrint('PeopleService GitHub fetch failed for $repoDisplay: $e');
      return const <Person>[];
    }
  }

  static Future<List<Person>> _adoRepoPeople(
    http.Client client,
    String organization,
    String project,
    String name,
    String? tokenId,
    DateTime now,
    Set<String> self,
  ) async {
    final repoDisplay = '$organization/$project/$name';
    try {
      final secret =
          (await TokenStore.resolveAdoSecret(organization, tokenId: tokenId))
              ?.trim();
      if (secret == null || secret.isEmpty) return const <Person>[];

      final response = await client.get(
        Uri.https(
          'dev.azure.com',
          '/$organization/$project/_apis/git/repositories/$name/pullrequests',
          {'searchCriteria.status': 'active', 'api-version': '6.0'},
        ),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
        },
      ).timeout(_requestTimeout);
      if (response.statusCode != 200) return const <Person>[];

      final body = jsonDecode(response.body);
      final value = body is Map ? body['value'] : body;
      if (value is! List) return const <Person>[];
      return aggregateAdo(
        prs: value,
        now: now,
        self: self,
      );
    } catch (e) {
      debugPrint('PeopleService ADO fetch failed for $repoDisplay: $e');
      return const <Person>[];
    }
  }

  static Map<String, dynamic>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static String? _nestedString(dynamic map, String key) =>
      map is Map && map[key] is String ? map[key] as String : null;

  static String? _stringValue(Map map, String key) {
    final value = map[key];
    return value is String ? value : null;
  }

  static DateTime? _dateValue(dynamic isoDate, DateTime now) {
    if (isoDate is! String) return null;
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return null;
    return parsed.isAfter(now) ? now : parsed;
  }

  static Future<List<T>> _runBounded<T>(
    List<Future<T> Function()> tasks,
    int concurrency,
  ) async {
    if (tasks.isEmpty) return <T>[];
    final results = <T>[];
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= tasks.length) break;
        results.add(await tasks[index]());
      }
    }

    final workerCount = concurrency.clamp(1, tasks.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }

  static void _sortPeople(List<Person> people) {
    people.sort((a, b) {
      final byReviewRequests = b.reviewRequests.compareTo(a.reviewRequests);
      if (byReviewRequests != 0) return byReviewRequests;
      final byAuthoredOpenPrs = b.authoredOpenPrs.compareTo(a.authoredOpenPrs);
      if (byAuthoredOpenPrs != 0) return byAuthoredOpenPrs;
      return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
    });
  }

  static String _normalizeLogin(String value) => value.trim().toLowerCase();

  static String _normalizeName(String value) => value.trim();

  static String _adoIdentity(String value) => value.trim().toLowerCase();

  static bool _isNotEmpty(String value) => value.isNotEmpty;
}

class _MutablePerson {
  _MutablePerson(this.key, this.displayName);

  factory _MutablePerson.github(String login) {
    final person = _MutablePerson('github:$login', login);
    person.githubLogins.add(login);
    return person;
  }

  factory _MutablePerson.ado(String name) {
    final trimmed = PeopleService._normalizeName(name);
    final person = _MutablePerson('ado:${PeopleService._adoIdentity(name)}',
        trimmed.isEmpty ? name : trimmed);
    person.addAdoName(name);
    return person;
  }

  factory _MutablePerson.person(Person person) =>
      _MutablePerson(person.key, person.displayName);

  String key;
  String displayName;
  final Set<String> githubLogins = <String>{};
  final Map<String, String> adoNames = <String, String>{};
  int authoredOpenPrs = 0;
  int reviewRequests = 0;
  DateTime? lastSeen;
  bool isSelf = false;

  void addPerson(Person person) {
    if (displayName.trim().isEmpty && person.displayName.trim().isNotEmpty) {
      displayName = person.displayName.trim();
    }
    for (final login in person.githubLogins) {
      final normalized = PeopleService._normalizeLogin(login);
      if (normalized.isNotEmpty) githubLogins.add(normalized);
    }
    for (final name in person.adoNames) {
      addAdoName(name);
    }
    authoredOpenPrs += person.authoredOpenPrs;
    reviewRequests += person.reviewRequests;
    see(person.lastSeen);
    markSelf(person.isSelf);
  }

  void addAdoName(String name) {
    final trimmed = PeopleService._normalizeName(name);
    final key = PeopleService._adoIdentity(trimmed);
    if (key.isEmpty) return;
    adoNames.putIfAbsent(key, () => trimmed);
  }

  void see(DateTime? value) {
    if (value == null) return;
    if (lastSeen == null || value.isAfter(lastSeen!)) lastSeen = value;
  }

  void markSelf(bool value) {
    isSelf = isSelf || value;
  }

  Person toPerson() {
    final logins = githubLogins.toList()..sort();
    final adoKeys = adoNames.keys.toList()..sort();
    final stableKey = logins.isNotEmpty
        ? 'github:${logins.first}'
        : adoKeys.isNotEmpty
            ? 'ado:${adoKeys.first}'
            : key;
    final fallbackName = logins.isNotEmpty
        ? logins.first
        : adoKeys.isNotEmpty
            ? adoNames[adoKeys.first]!
            : stableKey;
    final shownName =
        displayName.trim().isEmpty ? fallbackName : displayName.trim();

    return Person(
      key: stableKey,
      displayName: shownName,
      githubLogins: logins.toSet(),
      adoNames: adoKeys.map((key) => adoNames[key]!).toSet(),
      authoredOpenPrs: authoredOpenPrs,
      reviewRequests: reviewRequests,
      lastSeen: lastSeen,
      isSelf: isSelf,
    );
  }
}
