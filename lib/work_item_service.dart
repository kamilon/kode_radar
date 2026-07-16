import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// A work item (GitHub issue or Azure DevOps work item) assigned to the user.
class WorkItem {
  const WorkItem({
    required this.id,
    required this.provider,
    required this.groupKey,
    required this.groupDisplay,
    required this.reference,
    required this.title,
    required this.state,
    this.assignees = const <String>{},
    this.updatedAt,
    this.url,
  });

  /// Stable id (provider-scoped) for list keys and de-duplication.
  final String id;

  /// `github` or `ado`.
  final String provider;

  /// Grouping key — a repo key (GitHub) or `ado:org/project` (ADO work items
  /// are project-scoped, not repo-scoped).
  final String groupKey;
  final String groupDisplay;

  /// Human reference, e.g. `#123` (GitHub) or `WI 456` (ADO).
  final String reference;
  final String title;
  final String state;
  final Set<String> assignees;
  final DateTime? updatedAt;
  final String? url;
}

/// The assigned work items plus a source-health signal.
class WorkItemResult {
  const WorkItemResult({
    this.items = const [],
    this.failedSources = 0,
    this.githubSkippedNoIdentity = false,
  });

  final List<WorkItem> items;
  final int failedSources;

  /// True when GitHub repos are monitored but no identity is set, so their
  /// issues couldn't be filtered to "assigned to you" and were skipped.
  final bool githubSkippedNoIdentity;
}

/// Fetches open work items assigned to the current user: GitHub issues assigned
/// to any of the user's logins, and Azure DevOps work items assigned to the
/// token owner (WIQL `@Me`). Per-source failures are isolated.
class WorkItemService {
  WorkItemService._();

  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _maxAdoIds = 50;

  // ---- Pure, testable normalizers ------------------------------------------

  /// Normalizes a GitHub `/issues` list into assigned work items. Pull requests
  /// (which the issues endpoint also returns) are skipped, and only issues
  /// assigned to one of [selfGithubLogins] are kept.
  static List<WorkItem> parseGithubIssues(
    List<dynamic> data, {
    required String repoKey,
    required String repoDisplay,
    required Set<String> selfGithubLogins,
  }) {
    final self = selfGithubLogins.map((e) => e.trim().toLowerCase()).toSet();
    if (self.isEmpty) return const [];
    final result = <WorkItem>[];
    for (final issue in data) {
      if (issue is! Map) continue;
      // Skip pull requests, which the /issues endpoint also returns.
      if (issue.containsKey('pull_request')) continue;
      final number = issue['number'];
      if (number is! int) continue;
      final assignees = <String>{};
      final rawAssignees = issue['assignees'];
      if (rawAssignees is List) {
        for (final a in rawAssignees) {
          final login = a is Map && a['login'] is String
              ? a['login'] as String
              : null;
          if (login != null) assignees.add(login);
        }
      }
      final mine = assignees.any((a) => self.contains(a.trim().toLowerCase()));
      if (!mine) continue;
      result.add(
        WorkItem(
          id: 'gh-issue:$repoKey:$number',
          provider: 'github',
          groupKey: repoKey,
          groupDisplay: repoDisplay,
          reference: '#$number',
          title: _str(issue, 'title') ?? 'Untitled issue',
          state: _str(issue, 'state') ?? 'open',
          assignees: assignees,
          updatedAt: _parseDate(issue['updated_at']),
          url: _str(issue, 'html_url'),
        ),
      );
    }
    return result;
  }

  /// Normalizes an Azure DevOps work-item batch (`/wit/workitems`) response.
  static List<WorkItem> parseAdoWorkItems(
    dynamic body, {
    required String organization,
    required String project,
  }) {
    final value = body is Map ? body['value'] : body;
    if (value is! List) return const [];
    final groupKey =
        'ado:${organization.toLowerCase()}/${project.toLowerCase()}';
    final groupDisplay = '$organization/$project';
    final result = <WorkItem>[];
    for (final item in value) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id is! int) continue;
      final fields = item['fields'];
      final map = fields is Map ? fields : const {};
      final assigned = map['System.AssignedTo'];
      final assignee = assigned is Map && assigned['displayName'] is String
          ? assigned['displayName'] as String
          : null;
      result.add(
        WorkItem(
          id: 'ado-wi:${organization.toLowerCase()}:$id',
          provider: 'ado',
          groupKey: groupKey,
          groupDisplay: groupDisplay,
          reference: 'WI $id',
          title: map['System.Title'] is String
              ? map['System.Title'] as String
              : 'Untitled work item',
          state: map['System.State'] is String
              ? map['System.State'] as String
              : 'Active',
          assignees: assignee == null ? const {} : {assignee},
          updatedAt: _parseDate(map['System.ChangedDate']),
          url:
              'https://dev.azure.com/$organization/$project/_workitems/edit/$id',
        ),
      );
    }
    return result;
  }

  /// The WIQL query for open work items assigned to the token owner. Excludes
  /// the terminal states used across the common processes (Agile/Scrum/Basic/
  /// CMMI): Closed, Removed, Done, Completed.
  static String assignedWiql() =>
      'SELECT [System.Id] FROM WorkItems '
      "WHERE [System.AssignedTo] = @Me "
      "AND [System.State] <> 'Closed' AND [System.State] <> 'Removed' "
      "AND [System.State] <> 'Done' AND [System.State] <> 'Completed' "
      'ORDER BY [System.ChangedDate] DESC';

  /// Extracts the (capped) work-item ids from a WIQL response.
  static List<int> parseWiqlIds(dynamic body) {
    final workItems = body is Map ? body['workItems'] : null;
    if (workItems is! List) return const [];
    final ids = <int>[];
    for (final w in workItems) {
      final id = w is Map ? w['id'] : null;
      if (id is int) ids.add(id);
      if (ids.length >= _maxAdoIds) break;
    }
    return ids;
  }

  // ---- Fetching ------------------------------------------------------------

  static Future<WorkItemResult> computeAssigned({
    http.Client? client,
    int concurrency = 5,
    Set<String> selfGithubLogins = const {},
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final prefs = await SharedPreferences.getInstance();
      final githubRepos =
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[];
      final adoRepos =
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[];

      final tasks = <Future<_SourceResult> Function()>[];

      if (selfGithubLogins.isNotEmpty) {
        for (final raw in githubRepos) {
          final map = _decode(raw);
          if (map == null) continue;
          final owner = _str(map, 'owner');
          final name = _str(map, 'repoName');
          if (owner == null || name == null) continue;
          final tokenId = _str(map, 'tokenId');
          tasks.add(
            () => _githubRepoIssues(
              httpClient,
              owner,
              name,
              tokenId,
              selfGithubLogins,
            ),
          );
        }
      }

      // ADO work items are project-scoped; query each unique org/project once.
      final adoProjects = <String, Map<String, String>>{};
      for (final raw in adoRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final organization = _str(map, 'organization');
        final project = _str(map, 'project');
        if (organization == null || project == null) continue;
        final key = '${organization.toLowerCase()}/${project.toLowerCase()}';
        adoProjects.putIfAbsent(
          key,
          () => {
            'organization': organization,
            'project': project,
            if (_str(map, 'tokenId') != null) 'tokenId': _str(map, 'tokenId')!,
          },
        );
      }
      for (final project in adoProjects.values) {
        tasks.add(
          () => _adoProjectWorkItems(
            httpClient,
            project['organization']!,
            project['project']!,
            project['tokenId'],
          ),
        );
      }

      final results = await _runBounded(tasks, concurrency);
      final items = <WorkItem>[];
      final seen = <String>{};
      var failed = 0;
      for (final result in results) {
        failed += result.failed ? 1 : 0;
        for (final item in result.items) {
          if (seen.add(item.id)) items.add(item);
        }
      }
      items.sort((a, b) {
        final at = a.updatedAt;
        final bt = b.updatedAt;
        if (at == null && bt == null) return a.reference.compareTo(b.reference);
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return WorkItemResult(
        items: items,
        failedSources: failed,
        githubSkippedNoIdentity:
            selfGithubLogins.isEmpty && githubRepos.isNotEmpty,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<_SourceResult> _githubRepoIssues(
    http.Client client,
    String owner,
    String name,
    String? tokenId,
    Set<String> selfGithubLogins,
  ) async {
    final repoKey = RepoDiscoveryService.githubKey(owner, name);
    final repoDisplay = '$owner/$name';
    // "Assigned to you" needs an identity; without one there is nothing to
    // fetch (parseGithubIssues would filter everything out anyway).
    if (selfGithubLogins.isEmpty) return const _SourceResult(<WorkItem>[]);
    try {
      final secret = (await TokenStore.resolveGithubSecret(
        owner,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) return _SourceResult.failure;
      final items = <WorkItem>[];
      final seen = <String>{};
      // Filter server-side by assignee so a repo with more than one page of
      // open issues can't push the assigned ones off the first page. GitHub's
      // `assignee` accepts a single login, so query once per known identity.
      for (final login in selfGithubLogins) {
        final response = await client
            .get(
              Uri.https('api.github.com', '/repos/$owner/$name/issues', {
                'state': 'open',
                'assignee': login,
                'per_page': '100',
              }),
              headers: {
                'Authorization': 'Bearer $secret',
                'Accept': 'application/vnd.github+json',
              },
            )
            .timeout(_requestTimeout);
        if (response.statusCode != 200) return _SourceResult.failure;
        final body = jsonDecode(response.body);
        if (body is! List) continue;
        // parseGithubIssues still skips pull requests (the /issues endpoint
        // returns them too) and de-dupes across identities by work-item id.
        for (final item in parseGithubIssues(
          body,
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          selfGithubLogins: selfGithubLogins,
        )) {
          if (seen.add(item.id)) items.add(item);
        }
      }
      return _SourceResult(items);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'WorkItemService: GitHub issues failed for $repoDisplay: $e',
        );
      }
      return _SourceResult.failure;
    }
  }

  static Future<_SourceResult> _adoProjectWorkItems(
    http.Client client,
    String organization,
    String project,
    String? tokenId,
  ) async {
    try {
      final secret = (await TokenStore.resolveAdoSecret(
        organization,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) return _SourceResult.failure;
      final headers = {
        'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
      };

      final wiqlResponse = await client
          .post(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/wit/wiql',
              {'api-version': '6.0'},
            ),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'query': assignedWiql()}),
          )
          .timeout(_requestTimeout);
      if (wiqlResponse.statusCode != 200) return _SourceResult.failure;
      final ids = parseWiqlIds(jsonDecode(wiqlResponse.body));
      if (ids.isEmpty) return const _SourceResult(<WorkItem>[]);

      final response = await client
          .get(
            Uri.https('dev.azure.com', '/$organization/_apis/wit/workitems', {
              'ids': ids.join(','),
              'fields':
                  'System.Title,System.State,System.AssignedTo,System.ChangedDate',
              'api-version': '6.0',
            }),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return _SourceResult.failure;
      return _SourceResult(
        parseAdoWorkItems(
          jsonDecode(response.body),
          organization: organization,
          project: project,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'WorkItemService: ADO work items failed for $organization/$project: $e',
        );
      }
      return _SourceResult.failure;
    }
  }

  // ---- Helpers -------------------------------------------------------------

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static String? _str(Map map, String key) {
    final value = map[key];
    return value is String ? value : null;
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

    final workerCount = concurrency.clamp(1, tasks.length).toInt();
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }
}

class _SourceResult {
  const _SourceResult(this.items, {this.failed = false});

  static const _SourceResult failure = _SourceResult(
    <WorkItem>[],
    failed: true,
  );

  final List<WorkItem> items;
  final bool failed;
}
