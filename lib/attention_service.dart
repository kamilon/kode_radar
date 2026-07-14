import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'repo_store.dart';
import 'token_store.dart';

/// A single actionable item surfaced in the Attention Inbox.
class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.repoDisplay,
    this.url,
    this.ageDays,
  });

  /// Stable identity for the item (enables list keys and future snooze).
  final String id;

  /// One of: `reviewRequested`, `changesRequested`, `oldOpenPr`, `error`.
  final String category;

  /// Higher = more urgent (used for ranking). Category dominates age.
  final int severity;

  final String title;
  final String subtitle;
  final String repoDisplay;
  final String? url;
  final int? ageDays;
}

/// Computes a ranked, team-wide list of pull requests that need action across
/// all monitored repos (waiting on review, changes requested, or open a long
/// time). It is NOT personalized to the current user yet — that needs identity
/// (a later milestone). CI-failing repos are surfaced on the Radar, not here.
class AttentionService {
  AttentionService._();

  /// A PR open longer than this many days (with no pending review/changes) is
  /// surfaced as an "old open PR".
  static const int oldOpenPrDays = 7;
  static const Duration _requestTimeout = Duration(seconds: 20);

  // Category tiers; severity = tier * 1000 + age, so category always dominates
  // age in ranking while older items still sort first within a category.
  static const int _tierReviewRequested = 3;
  static const int _tierChangesRequested = 2;
  static const int _tierOldOpen = 1;
  static const int _tierError = 0;

  static int _severity(int tier, int? ageDays) =>
      tier * 1000 + (ageDays ?? 0).clamp(0, 999);

  // ---- Pure, testable rule helpers -----------------------------------------

  /// Builds attention items for a GitHub repo from its open PR list.
  static List<AttentionItem> githubItems({
    required String repoDisplay,
    required List<dynamic> prs,
    required DateTime now,
  }) {
    final items = <AttentionItem>[];
    for (final pr in prs) {
      if (pr is! Map) continue;
      if (pr['draft'] == true) continue;
      final number = pr['number'];
      final title = pr['title'] as String? ?? 'Untitled PR';
      final author = _nestedString(pr['user'], 'login') ?? 'unknown';
      final url = pr['html_url'] as String?;
      final age = _ageDays(pr['created_at'], now);

      // Waiting on review = individual reviewers still requested, or a team
      // review requested. (GitHub drops a reviewer from this list once they
      // submit a review, so a non-empty list means "still waiting".)
      final reviewers = pr['requested_reviewers'];
      final teams = pr['requested_teams'];
      final waitingOnReview = (reviewers is List && reviewers.isNotEmpty) ||
          (teams is List && teams.isNotEmpty);

      if (waitingOnReview) {
        items.add(_reviewRequested(
            repoDisplay, 'PR #$number', title, author, age, url));
      } else if ((age ?? 0) > oldOpenPrDays) {
        items
            .add(_oldOpen(repoDisplay, 'PR #$number', title, author, age, url));
      }
    }
    return items;
  }

  /// Builds attention items for an Azure DevOps repo from its active PR list.
  static List<AttentionItem> adoItems({
    required String repoDisplay,
    required String organization,
    required String project,
    required String name,
    required List<dynamic> prs,
    required DateTime now,
  }) {
    final items = <AttentionItem>[];
    for (final pr in prs) {
      if (pr is! Map) continue;
      if (pr['isDraft'] == true) continue;
      final id = pr['pullRequestId'];
      final title = pr['title'] as String? ?? 'Untitled PR';
      final author = _nestedString(pr['createdBy'], 'displayName') ?? 'unknown';
      final age = _ageDays(pr['creationDate'], now);
      final url = id == null
          ? null
          : 'https://dev.azure.com/$organization/$project/_git/$name/'
              'pullrequest/$id';

      // ADO reviewer votes: 10 approved, 5 approved-with-suggestions,
      // 0 no vote yet, -5 waiting for author, -10 rejected.
      final reviewers = pr['reviewers'];
      final votes = reviewers is List
          ? reviewers.whereType<Map>().map((r) => r['vote']).toList()
          : const [];
      final changesRequested = votes.any((v) => v is int && v < 0);
      final waitingOnReview = votes.any((v) => v == 0);

      if (changesRequested) {
        items.add(
            _changesRequested(repoDisplay, 'PR #$id', title, author, age, url));
      } else if (waitingOnReview) {
        items.add(
            _reviewRequested(repoDisplay, 'PR #$id', title, author, age, url));
      } else if ((age ?? 0) > oldOpenPrDays) {
        items.add(_oldOpen(repoDisplay, 'PR #$id', title, author, age, url));
      }
    }
    return items;
  }

  static AttentionItem _reviewRequested(String repoDisplay, String prLabel,
      String title, String author, int? ageDays, String? url) {
    return AttentionItem(
      id: 'reviewRequested:$repoDisplay:$prLabel',
      category: 'reviewRequested',
      severity: _severity(_tierReviewRequested, ageDays),
      title: '$prLabel waiting on review',
      subtitle:
          '$repoDisplay · $title · opened ${_ageText(ageDays)} by $author',
      repoDisplay: repoDisplay,
      url: url,
      ageDays: ageDays,
    );
  }

  static AttentionItem _changesRequested(String repoDisplay, String prLabel,
      String title, String author, int? ageDays, String? url) {
    return AttentionItem(
      id: 'changesRequested:$repoDisplay:$prLabel',
      category: 'changesRequested',
      severity: _severity(_tierChangesRequested, ageDays),
      title: '$prLabel has changes requested',
      subtitle:
          '$repoDisplay · $title · opened ${_ageText(ageDays)} by $author',
      repoDisplay: repoDisplay,
      url: url,
      ageDays: ageDays,
    );
  }

  static AttentionItem _oldOpen(String repoDisplay, String prLabel,
      String title, String author, int? ageDays, String? url) {
    return AttentionItem(
      id: 'oldOpenPr:$repoDisplay:$prLabel',
      category: 'oldOpenPr',
      severity: _severity(_tierOldOpen, ageDays),
      title: '$prLabel open for ${_ageText(ageDays)}',
      subtitle: '$repoDisplay · $title · by $author · no pending review',
      repoDisplay: repoDisplay,
      url: url,
      ageDays: ageDays,
    );
  }

  static AttentionItem _errorItem(String repoDisplay, String reason) {
    return AttentionItem(
      id: 'error:$repoDisplay',
      category: 'error',
      severity: _severity(_tierError, null),
      title: reason,
      subtitle: repoDisplay,
      repoDisplay: repoDisplay,
    );
  }

  static String _ageText(int? ageDays) {
    if (ageDays == null) return 'recently';
    if (ageDays <= 0) return 'today';
    if (ageDays == 1) return '1 day';
    return '$ageDays days';
  }

  static int? _ageDays(dynamic isoDate, DateTime now) {
    if (isoDate is! String) return null;
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return null;
    final diff = now.difference(parsed).inDays;
    return diff < 0 ? 0 : diff;
  }

  static String? _nestedString(dynamic map, String key) =>
      map is Map ? map[key] as String? : null;

  static String? _stringValue(Map map, String key) {
    final value = map[key];
    return value is String ? value : null;
  }

  // ---- Fetching ------------------------------------------------------------

  static Future<List<AttentionItem>> computeAll({
    http.Client? client,
    int concurrency = 5,
    DateTime? now,
  }) async {
    final httpClient = client ?? http.Client();
    final effectiveNow = now ?? DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final githubRepos =
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[];
      final adoRepos =
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[];

      final tasks = <Future<List<AttentionItem>> Function()>[];

      for (final raw in githubRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final owner = _stringValue(map, 'owner');
        final name = _stringValue(map, 'repoName');
        if (owner == null || name == null) continue;
        final tokenId = _stringValue(map, 'tokenId');
        tasks.add(() =>
            _githubRepoItems(httpClient, owner, name, tokenId, effectiveNow));
      }

      for (final raw in adoRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final organization = _stringValue(map, 'organization');
        final project = _stringValue(map, 'project');
        final name = _stringValue(map, 'repoName');
        if (organization == null || project == null || name == null) continue;
        final tokenId = _stringValue(map, 'tokenId');
        tasks.add(() => _adoRepoItems(
            httpClient, organization, project, name, tokenId, effectiveNow));
      }

      final grouped = await _runBounded(tasks, concurrency);
      final items = grouped.expand((e) => e).toList();

      items.sort((a, b) {
        final bySeverity = b.severity.compareTo(a.severity);
        if (bySeverity != 0) return bySeverity;
        return a.repoDisplay.compareTo(b.repoDisplay);
      });
      return items;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<List<AttentionItem>> _githubRepoItems(http.Client client,
      String owner, String name, String? tokenId, DateTime now) async {
    final repoDisplay = '$owner/$name';
    try {
      final secret =
          (await TokenStore.resolveGithubSecret(owner, tokenId: tokenId))
              ?.trim();
      if (secret == null || secret.isEmpty) {
        return [_errorItem(repoDisplay, 'No token set')];
      }
      final response = await client.get(
        Uri.https('api.github.com', '/repos/$owner/$name/pulls',
            {'state': 'open', 'per_page': '100'}),
        headers: {
          'Authorization': 'Bearer $secret',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return [
          _errorItem(repoDisplay, 'GitHub returned ${response.statusCode}')
        ];
      }
      final body = jsonDecode(response.body);
      if (body is! List) return const [];
      return githubItems(repoDisplay: repoDisplay, prs: body, now: now);
    } catch (e) {
      return [_errorItem(repoDisplay, 'Error: $e')];
    }
  }

  static Future<List<AttentionItem>> _adoRepoItems(
      http.Client client,
      String organization,
      String project,
      String name,
      String? tokenId,
      DateTime now) async {
    final repoDisplay = '$organization/$project/$name';
    try {
      final secret =
          (await TokenStore.resolveAdoSecret(organization, tokenId: tokenId))
              ?.trim();
      if (secret == null || secret.isEmpty) {
        return [_errorItem(repoDisplay, 'No token set')];
      }
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
      if (response.statusCode != 200) {
        return [
          _errorItem(
              repoDisplay, 'Azure DevOps returned ${response.statusCode}')
        ];
      }
      final body = jsonDecode(response.body);
      final value = body is Map ? body['value'] : body;
      if (value is! List) return const [];
      return adoItems(
        repoDisplay: repoDisplay,
        organization: organization,
        project: project,
        name: name,
        prs: value,
        now: now,
      );
    } catch (e) {
      return [_errorItem(repoDisplay, 'Error: $e')];
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

  static Future<List<T>> _runBounded<T>(
    List<Future<T> Function()> tasks,
    int concurrency,
  ) async {
    if (tasks.isEmpty) return <T>[];
    final results = <T>[];
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= tasks.length) break;
        results.add(await tasks[i]());
      }
    }

    final workerCount = concurrency.clamp(1, tasks.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }
}
