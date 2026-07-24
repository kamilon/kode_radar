import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'team.dart';
import 'token_store.dart';

/// A current-state snapshot of a repo's open issues, for the "Issues" insight.
/// Provider-agnostic and pure so it's easy to unit-test.
class RepoIssues {
  const RepoIssues({
    required this.repoKey,
    required this.repoDisplay,
    required this.openCount,
    required this.staleCount,
    required this.oldestAgeDays,
  });

  final String repoKey;
  final String repoDisplay;

  /// Exact count of open issues (excludes pull requests).
  final int openCount;

  /// Of those, how many are older than the staleness threshold.
  final int staleCount;

  /// Age in days of the oldest open issue, or null when there are none.
  final int? oldestAgeDays;

  bool get isEmpty => openCount == 0;
}

/// The issue snapshots plus a source-health signal, so the UI can tell an
/// all-fetched "no issues" apart from a partial/failed fetch.
class IssuesResult {
  const IssuesResult({this.snapshots = const [], this.failedRepos = 0});

  final List<RepoIssues> snapshots;

  /// Number of monitored GitHub repos whose issue fetch failed (auth/network/
  /// malformed), so their issues aren't represented in [snapshots].
  final int failedRepos;
}

/// Pure roll-ups over [RepoIssues], for the per-team section.
class IssueStats {
  const IssueStats._();

  /// Per-team totals (open + stale), for teams that have any open issues.
  /// Sorted most-stale first, then most-open, then name, then id.
  static List<TeamIssues> perTeam(
    Iterable<RepoIssues> snapshots,
    List<Team> teams,
  ) {
    final byRepo = <String, RepoIssues>{
      for (final s in snapshots) s.repoKey: s,
    };
    final result = <TeamIssues>[];
    for (final team in teams) {
      if (team.repoKeys.isEmpty) continue;
      var open = 0;
      var stale = 0;
      for (final key in team.repoKeys) {
        final s = byRepo[key];
        if (s == null) continue;
        open += s.openCount;
        stale += s.staleCount;
      }
      if (open == 0) continue;
      result.add(
        TeamIssues(
          teamId: team.id,
          teamName: team.name,
          openCount: open,
          staleCount: stale,
        ),
      );
    }
    result.sort((a, b) {
      if (a.staleCount != b.staleCount) {
        return b.staleCount.compareTo(a.staleCount);
      }
      if (a.openCount != b.openCount) return b.openCount.compareTo(a.openCount);
      final byName = a.teamName.toLowerCase().compareTo(
        b.teamName.toLowerCase(),
      );
      return byName != 0 ? byName : a.teamId.compareTo(b.teamId);
    });
    return result;
  }

  /// Repos with open issues, sorted most-stale first, then most-open, then
  /// display, then key.
  static List<RepoIssues> rankRepos(Iterable<RepoIssues> snapshots) {
    final result = snapshots.where((s) => !s.isEmpty).toList();
    result.sort((a, b) {
      if (a.staleCount != b.staleCount) {
        return b.staleCount.compareTo(a.staleCount);
      }
      if (a.openCount != b.openCount) return b.openCount.compareTo(a.openCount);
      final byName = a.repoDisplay.toLowerCase().compareTo(
        b.repoDisplay.toLowerCase(),
      );
      return byName != 0 ? byName : a.repoKey.compareTo(b.repoKey);
    });
    return result;
  }
}

/// A per-team open-issue roll-up.
class TeamIssues {
  const TeamIssues({
    required this.teamId,
    required this.teamName,
    required this.openCount,
    required this.staleCount,
  });

  final String teamId;
  final String teamName;
  final int openCount;
  final int staleCount;
}

/// Fetches open-issue counts for the monitored GitHub repos, so the "Issues"
/// insight can surface where open (and stale) issue backlogs are piling up.
///
/// Uses GitHub GraphQL for exact, issues-only counts: the `issues(states:OPEN)`
/// connection excludes pull requests (so no cap/PR-mixing guesswork), a
/// `search(... is:issue is:open created:<cutoff)` field gives the exact stale
/// count, and `orderBy CREATED_AT ASC` yields the true oldest issue. Issues are
/// a current-state snapshot (not accumulated history). ADO work items are
/// project-scoped WIQL queries and aren't covered yet (a planned follow-up), so
/// ADO repos contribute no issue data. Parsers are pure static methods for
/// unit-testing; [computeAll] wires the network fetch, mirroring
/// [CycleTimeService].
class IssueService {
  IssueService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Open issues older than this are counted as "stale".
  static const Duration staleThreshold = Duration(days: 30);

  /// GraphQL query: exact open-issue count, the oldest open issue's creation
  /// time, and the stale count (open issues created before the cutoff). `$stale`
  /// carries the full search query (`repo:o/n is:issue is:open created:<DATE`).
  static const String openIssuesQuery =
      r'query($owner:String!,$name:String!,$stale:String!){'
      r'repository(owner:$owner,name:$name){'
      r'issues(states:OPEN){totalCount}'
      r'oldest:issues(states:OPEN,first:1,orderBy:{field:CREATED_AT,direction:ASC}){nodes{createdAt}}'
      r'}'
      r'stale:search(query:$stale,type:ISSUE){issueCount}'
      r'}';

  // ---- Pure parser ---------------------------------------------------------

  /// Normalizes a GitHub GraphQL response (see [openIssuesQuery]) into a
  /// [RepoIssues] snapshot, or null when the response is malformed (missing
  /// `repository`), so the caller can count it as a failed fetch. [now] anchors
  /// the oldest-issue age.
  static RepoIssues? issuesFromGithubGraphql(
    dynamic body, {
    required String repoKey,
    required String repoDisplay,
    required DateTime now,
  }) {
    final data = body is Map ? body['data'] : null;
    final repository = data is Map ? data['repository'] : null;
    if (repository is! Map) return null;
    final issues = repository['issues'];
    final open = issues is Map ? _int(issues['totalCount']) : null;
    if (open == null) return null;

    final staleField = data is Map ? data['stale'] : null;
    final stale = staleField is Map ? _int(staleField['issueCount']) ?? 0 : 0;

    int? oldestAgeDays;
    final oldest = repository['oldest'];
    final nodes = oldest is Map ? oldest['nodes'] : null;
    if (nodes is List && nodes.isNotEmpty && nodes.first is Map) {
      final created = _parseDate((nodes.first as Map)['createdAt']);
      if (created != null) {
        final days = now.difference(created).inDays;
        oldestAgeDays = days < 0 ? 0 : days;
      }
    }

    return RepoIssues(
      repoKey: repoKey,
      repoDisplay: repoDisplay,
      openCount: open,
      staleCount: stale,
      oldestAgeDays: oldestAgeDays,
    );
  }

  static int? _int(dynamic v) => v is int ? v : null;

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String? _str(Map map, String key) {
    final v = map[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// The `<YYYY-MM-DD` search cutoff for staleness, relative to [now] (UTC).
  static String staleCutoffDate(DateTime now) {
    final cutoff = now.toUtc().subtract(staleThreshold);
    final m = cutoff.month.toString().padLeft(2, '0');
    final d = cutoff.day.toString().padLeft(2, '0');
    return '${cutoff.year}-$m-$d';
  }

  // ---- Network -------------------------------------------------------------

  /// Fetches open-issue snapshots for every monitored GitHub repo, plus a count
  /// of repos whose fetch failed. Never throws — top-level setup failures
  /// return an empty result. Bounded to [concurrency] in-flight requests.
  static Future<IssuesResult> computeAll({
    http.Client? client,
    int concurrency = 5,
    Set<String>? onlyRepoKeys,
    DateTime? now,
  }) async {
    final httpClient = client ?? http.Client();
    final at = now ?? DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final githubRepos =
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[];

      final tasks = <Future<RepoIssues?> Function()>[];
      // Repos we couldn't even attempt (malformed stored entry / missing
      // fields) count toward failedRepos too, so the partial-coverage signal
      // stays honest — but an intentional onlyRepoKeys filter-out does not.
      var setupFailed = 0;
      for (final raw in githubRepos) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) {
            setupFailed++;
            continue;
          }
          final owner = _str(decoded, 'owner');
          final name = _str(decoded, 'repoName');
          if (owner == null || name == null) {
            setupFailed++;
            continue;
          }
          final repoKey = RepoDiscoveryService.githubKey(owner, name);
          if (onlyRepoKeys != null && !onlyRepoKeys.contains(repoKey)) continue;
          final tokenId = _str(decoded, 'tokenId');
          tasks.add(
            () => _fetchGithub(
              httpClient,
              owner: owner,
              name: name,
              repoKey: repoKey,
              tokenId: tokenId,
              now: at,
            ),
          );
        } catch (_) {
          // A malformed entry we couldn't parse — count it as unavailable.
          setupFailed++;
        }
      }

      final results = await _runBounded(tasks, concurrency);
      final snapshots = <RepoIssues>[];
      var failed = setupFailed;
      for (final r in results) {
        if (r == null) {
          failed++;
        } else {
          snapshots.add(r);
        }
      }
      return IssuesResult(snapshots: snapshots, failedRepos: failed);
    } catch (_) {
      // Top-level setup (prefs) failure: report nothing rather than throw so a
      // caller (e.g. the Insights hub) isn't taken down with it.
      return const IssuesResult();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<RepoIssues?> _fetchGithub(
    http.Client httpClient, {
    required String owner,
    required String name,
    required String repoKey,
    String? tokenId,
    required DateTime now,
  }) async {
    try {
      final secret = (await TokenStore.resolveGithubSecret(
        owner,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) return null;
      final staleQuery =
          'repo:$owner/$name is:issue is:open '
          'created:<${staleCutoffDate(now)}';
      final response = await httpClient
          .post(
            Uri.https('api.github.com', '/graphql'),
            headers: {
              'Authorization': 'Bearer $secret',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'query': openIssuesQuery,
              'variables': {'owner': owner, 'name': name, 'stale': staleQuery},
            }),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is Map && body['errors'] != null) return null;
      return issuesFromGithubGraphql(
        body,
        repoKey: repoKey,
        repoDisplay: '$owner/$name',
        now: now,
      );
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
