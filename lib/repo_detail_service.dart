import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// Review state of an open pull request, provider-normalized.
abstract final class PrReviewState {
  static const String waiting = 'waiting';
  static const String approved = 'approved';
  static const String changesRequested = 'changesRequested';
  static const String none = 'none';
}

/// An open pull request shown on the repo detail screen.
class RepoPr {
  const RepoPr({
    required this.label,
    required this.title,
    required this.author,
    required this.reviewState,
    this.ageDays,
    this.createdAt,
    this.draft = false,
    this.url,
  });

  final String label; // e.g. "PR #7"
  final String title;
  final String author;
  final String reviewState; // one of PrReviewState
  final int? ageDays;

  /// When the PR was opened (UTC). Persisted so a cached PR's age can be
  /// recomputed on read instead of freezing at its fetch-time value.
  final DateTime? createdAt;
  final bool draft;
  final String? url;
}

/// A CI run/build for the repo.
class RepoRun {
  const RepoRun({
    required this.name,
    required this.status,
    required this.conclusion,
    this.branch,
    this.finishedAt,
    this.url,
  });

  final String name;

  /// Provider status, e.g. `completed`/`in_progress` (GitHub) or
  /// `completed`/`inProgress` (ADO).
  final String status;

  /// Outcome when finished: `success`/`failure`/`cancelled`/... or '' when the
  /// run is still in progress.
  final String conclusion;
  final String? branch;
  final DateTime? finishedAt;
  final String? url;
}

/// A published release/tag.
class RepoRelease {
  const RepoRelease({
    required this.tag,
    this.name,
    this.author,
    this.publishedAt,
    this.url,
  });

  final String tag;
  final String? name;
  final String? author;
  final DateTime? publishedAt;
  final String? url;
}

/// Everything the repo detail screen renders (besides the reused activity feed).
class RepoDetailData {
  const RepoDetailData({
    this.pulls = const [],
    this.ci = const [],
    this.releases = const [],
    this.releasesSupported = true,
    this.pullsFailed = false,
    this.ciFailed = false,
    this.releasesFailed = false,
  });

  final List<RepoPr> pulls;
  final List<RepoRun> ci;
  final List<RepoRelease> releases;

  /// False for providers without a releases concept (Azure DevOps).
  final bool releasesSupported;

  /// Per-source load failures so each tab can distinguish "empty" from "failed".
  final bool pullsFailed;
  final bool ciFailed;
  final bool releasesFailed;

  /// Number of sources that errored or returned a non-200 status.
  int get failedSources =>
      (pullsFailed ? 1 : 0) + (ciFailed ? 1 : 0) + (releasesFailed ? 1 : 0);
}

/// Fetches per-repository detail — open pull requests (with review state), CI
/// history, and releases — for the repo detail screen. Per-source failures are
/// isolated. The activity timeline is sourced separately via
/// `ActivityFeedService`.
class RepoDetailService {
  RepoDetailService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  // ---- Pure, testable normalizers ------------------------------------------

  /// The GraphQL query for a repo's open pull requests, including the exact
  /// [reviewDecision] (approved / changes requested / review required).
  static const String _openPullsQuery =
      r'query($owner:String!,$name:String!){'
      r'repository(owner:$owner,name:$name){'
      r'pullRequests(states:OPEN,first:50,orderBy:{field:UPDATED_AT,direction:DESC}){'
      r'nodes{number title url isDraft createdAt '
      r'author{login} reviewDecision reviewRequests(first:1){totalCount}}'
      r'}}}';

  /// Normalizes a GitHub GraphQL open-PR response into work items with a full
  /// review state derived from `reviewDecision`.
  static List<RepoPr> parseGithubGraphqlPulls(dynamic body, DateTime now) {
    final nodes = _graphqlPullNodes(body);
    if (nodes == null) return const [];
    final result = <RepoPr>[];
    for (final pr in nodes) {
      if (pr is! Map) continue;
      final number = pr['number'];
      if (number is! int) continue;
      final reviewRequests = pr['reviewRequests'];
      final pending =
          reviewRequests is Map && reviewRequests['totalCount'] is int
          ? reviewRequests['totalCount'] as int
          : 0;
      result.add(
        RepoPr(
          label: 'PR #$number',
          title: _str(pr, 'title') ?? 'Untitled PR',
          author: _nested(pr['author'], 'login') ?? 'unknown',
          reviewState: _reviewStateFromDecision(
            _str(pr, 'reviewDecision'),
            pending,
          ),
          ageDays: _ageDays(pr['createdAt'], now),
          createdAt: _parseDate(pr['createdAt']),
          draft: pr['isDraft'] == true,
          url: _str(pr, 'url'),
        ),
      );
    }
    return result;
  }

  /// Extracts `data.repository.pullRequests.nodes` from a GraphQL response, or
  /// null when the response shape is invalid (missing repository/pull requests).
  /// A valid-but-empty repo returns an empty list, letting callers distinguish
  /// "no open PRs" (success) from a malformed/failed response.
  static List<dynamic>? _graphqlPullNodes(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final repository = data is Map ? data['repository'] : null;
    final pullRequests = repository is Map ? repository['pullRequests'] : null;
    final nodes = pullRequests is Map ? pullRequests['nodes'] : null;
    return nodes is List ? nodes : null;
  }

  /// Maps a GitHub `reviewDecision` (+ pending review-request count) to the
  /// provider-normalized [PrReviewState].
  static String _reviewStateFromDecision(
    String? decision,
    int pendingReviewRequests,
  ) {
    switch (decision) {
      case 'APPROVED':
        return PrReviewState.approved;
      case 'CHANGES_REQUESTED':
        return PrReviewState.changesRequested;
      case 'REVIEW_REQUIRED':
        return PrReviewState.waiting;
      default:
        return pendingReviewRequests > 0
            ? PrReviewState.waiting
            : PrReviewState.none;
    }
  }

  /// Normalizes an Azure DevOps active-PR list; reviewer votes map to review
  /// state (10/5 approved, <0 changes requested, 0 waiting).
  static List<RepoPr> parseAdoPulls(
    List<dynamic> data,
    DateTime now, {
    required String organization,
    required String project,
    required String name,
  }) {
    final result = <RepoPr>[];
    for (final pr in data) {
      if (pr is! Map) continue;
      final id = pr['pullRequestId'];
      if (id is! int) continue; // skip malformed entries (no "PR #null")
      final title = _str(pr, 'title') ?? 'Untitled PR';
      final author = _nested(pr['createdBy'], 'displayName') ?? 'unknown';
      final draft = pr['isDraft'] == true;
      final url =
          'https://dev.azure.com/$organization/$project/_git/$name/'
          'pullrequest/$id';
      final reviewers = pr['reviewers'];
      final votes = <int>[];
      if (reviewers is List) {
        for (final r in reviewers) {
          if (r is Map && r['vote'] is int) votes.add(r['vote'] as int);
        }
      }
      final String state;
      if (votes.any((v) => v < 0)) {
        state = PrReviewState.changesRequested;
      } else if (votes.any((v) => v == 0)) {
        // A pending (0) vote outranks approvals: the PR still needs review.
        state = PrReviewState.waiting;
      } else if (votes.any((v) => v > 0)) {
        state = PrReviewState.approved;
      } else {
        state = PrReviewState.none;
      }
      result.add(
        RepoPr(
          label: 'PR #$id',
          title: title,
          author: author,
          reviewState: state,
          ageDays: _ageDays(pr['creationDate'], now),
          createdAt: _parseDate(pr['creationDate']),
          draft: draft,
          url: url,
        ),
      );
    }
    return result;
  }

  /// Normalizes a GitHub Actions `/actions/runs` response into CI runs.
  static List<RepoRun> parseGithubRuns(dynamic body) {
    final runs = body is Map ? body['workflow_runs'] : null;
    if (runs is! List) return const [];
    final result = <RepoRun>[];
    for (final run in runs) {
      if (run is! Map) continue;
      result.add(
        RepoRun(
          name: _str(run, 'name') ?? _str(run, 'display_title') ?? 'Workflow',
          status: _str(run, 'status') ?? 'unknown',
          conclusion: _str(run, 'conclusion') ?? '',
          branch: _str(run, 'head_branch'),
          finishedAt: _parseDate(run['updated_at']),
          url: _str(run, 'html_url'),
        ),
      );
    }
    return result;
  }

  /// Normalizes an Azure DevOps builds response into CI runs.
  static List<RepoRun> parseAdoBuilds(dynamic body) {
    final builds = body is Map ? body['value'] : body;
    if (builds is! List) return const [];
    final result = <RepoRun>[];
    for (final build in builds) {
      if (build is! Map) continue;
      result.add(
        RepoRun(
          name: _nested(build['definition'], 'name') ?? 'Build',
          status: _str(build, 'status') ?? 'unknown',
          conclusion: _str(build, 'result') ?? '',
          branch: _branchFromRef(_str(build, 'sourceBranch')),
          finishedAt: _parseDate(build['finishTime']),
          url: _nested(_nested2(build['_links'], 'web'), 'href'),
        ),
      );
    }
    return result;
  }

  /// Normalizes a GitHub `/releases` response.
  static List<RepoRelease> parseGithubReleases(List<dynamic> data) {
    final result = <RepoRelease>[];
    for (final release in data) {
      if (release is! Map) continue;
      final tag = _str(release, 'tag_name');
      if (tag == null || tag.isEmpty) continue;
      result.add(
        RepoRelease(
          tag: tag,
          name: _str(release, 'name'),
          author: _nested(release['author'], 'login'),
          publishedAt: _parseDate(release['published_at']),
          url: _str(release, 'html_url'),
        ),
      );
    }
    return result;
  }

  // ---- Fetching ------------------------------------------------------------

  /// Resolves the persisted repo record for [repoKey] (so the repo's own
  /// `tokenId` and structured identity are used, not a scope-guessed fallback)
  /// and loads its detail. [provider] is `github` or `ado`.
  static Future<RepoDetailData> load({
    required String repoKey,
    required String provider,
    http.Client? client,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == 'github') {
      for (final raw in prefs.getStringList(RepoStore.githubKey) ?? const []) {
        final map = _decode(raw);
        if (map == null) continue;
        final owner = _str(map, 'owner');
        final name = _str(map, 'repoName');
        if (owner == null || name == null) continue;
        if (RepoDiscoveryService.githubKey(owner, name) != repoKey) continue;
        return loadGithub(
          owner: owner,
          name: name,
          tokenId: _str(map, 'tokenId'),
          client: client,
          now: now,
        );
      }
      return const RepoDetailData(
        pullsFailed: true,
        ciFailed: true,
        releasesFailed: true,
      );
    }
    if (provider == 'ado') {
      for (final raw in prefs.getStringList(RepoStore.adoKey) ?? const []) {
        final map = _decode(raw);
        if (map == null) continue;
        final organization = _str(map, 'organization');
        final project = _str(map, 'project');
        final name = _str(map, 'repoName');
        if (organization == null || project == null || name == null) continue;
        if (RepoDiscoveryService.adoKey(organization, project, name) !=
            repoKey) {
          continue;
        }
        return loadAdo(
          organization: organization,
          project: project,
          name: name,
          tokenId: _str(map, 'tokenId'),
          client: client,
          now: now,
        );
      }
      return const RepoDetailData(
        releasesSupported: false,
        pullsFailed: true,
        ciFailed: true,
      );
    }
    // Unknown provider — surface as a failure rather than guessing.
    return const RepoDetailData(
      pullsFailed: true,
      ciFailed: true,
      releasesFailed: true,
    );
  }

  static Future<RepoDetailData> loadGithub({
    required String owner,
    required String name,
    String? tokenId,
    http.Client? client,
    DateTime? now,
  }) async {
    final httpClient = client ?? http.Client();
    final effectiveNow = now ?? DateTime.now();
    try {
      final secret = (await TokenStore.resolveGithubSecret(
        owner,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) {
        return const RepoDetailData(
          pullsFailed: true,
          ciFailed: true,
          releasesFailed: true,
        );
      }
      final headers = {
        'Authorization': 'Bearer $secret',
        'Accept': 'application/vnd.github+json',
      };

      final results = await Future.wait([
        _guard('GitHub pulls', () async {
          // GraphQL gives the exact reviewDecision (approved / changes
          // requested / review required) in a single request, avoiding a
          // per-PR reviews-API fan-out.
          final response = await httpClient
              .post(
                Uri.https('api.github.com', '/graphql'),
                headers: {
                  'Authorization': 'Bearer $secret',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'query': _openPullsQuery,
                  'variables': {'owner': owner, 'name': name},
                }),
              )
              .timeout(_requestTimeout);
          if (response.statusCode != 200) return null;
          final body = jsonDecode(response.body);
          if (body is Map && body['errors'] != null) return null;
          // A malformed/null-repository 200 response is a failure, not an
          // empty PR list — surface it via pullsFailed instead of "no PRs".
          if (_graphqlPullNodes(body) == null) return null;
          return parseGithubGraphqlPulls(body, effectiveNow);
        }),
        _guard('GitHub runs', () async {
          final response = await httpClient
              .get(
                Uri.https(
                  'api.github.com',
                  '/repos/$owner/$name/actions/runs',
                  {'per_page': '15'},
                ),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (response.statusCode != 200) return null;
          return parseGithubRuns(jsonDecode(response.body));
        }),
        _guard('GitHub releases', () async {
          final response = await httpClient
              .get(
                Uri.https('api.github.com', '/repos/$owner/$name/releases', {
                  'per_page': '10',
                }),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (response.statusCode != 200) return null;
          final body = jsonDecode(response.body);
          return body is List ? parseGithubReleases(body) : null;
        }),
      ]);
      final pulls = results[0] as List<RepoPr>?;
      final ci = results[1] as List<RepoRun>?;
      final releases = results[2] as List<RepoRelease>?;

      return RepoDetailData(
        pulls: pulls ?? const [],
        ci: ci ?? const [],
        releases: releases ?? const [],
        pullsFailed: pulls == null,
        ciFailed: ci == null,
        releasesFailed: releases == null,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<RepoDetailData> loadAdo({
    required String organization,
    required String project,
    required String name,
    String? tokenId,
    http.Client? client,
    DateTime? now,
  }) async {
    final httpClient = client ?? http.Client();
    final effectiveNow = now ?? DateTime.now();
    try {
      final secret = (await TokenStore.resolveAdoSecret(
        organization,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) {
        return const RepoDetailData(
          releasesSupported: false,
          pullsFailed: true,
          ciFailed: true,
        );
      }
      final headers = {
        'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
      };

      final results = await Future.wait([
        _guard('ADO pulls', () async {
          final response = await httpClient
              .get(
                Uri.https(
                  'dev.azure.com',
                  '/$organization/$project/_apis/git/repositories/$name/pullrequests',
                  {
                    'searchCriteria.status': 'active',
                    r'$top': '50',
                    'api-version': '6.0',
                  },
                ),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (response.statusCode != 200) return null;
          final body = jsonDecode(response.body);
          final value = body is Map ? body['value'] : body;
          return value is List
              ? parseAdoPulls(
                  value,
                  effectiveNow,
                  organization: organization,
                  project: project,
                  name: name,
                )
              : null;
        }),
        _guard('ADO builds', () async {
          // Builds are project-wide; scope to THIS repo by resolving its GUID.
          final repoResp = await httpClient
              .get(
                Uri.https(
                  'dev.azure.com',
                  '/$organization/$project/_apis/git/repositories/$name',
                  {'api-version': '6.0'},
                ),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (repoResp.statusCode != 200) return null;
          final decoded = jsonDecode(repoResp.body);
          final repositoryId = decoded is Map ? _str(decoded, 'id') : null;
          // A repo we can't resolve to a GUID means CI couldn't be scoped —
          // treat it as a failure, not "no runs".
          if (repositoryId == null) return null;
          final response = await httpClient
              .get(
                Uri.https(
                  'dev.azure.com',
                  '/$organization/$project/_apis/build/builds',
                  {
                    'repositoryId': repositoryId,
                    'repositoryType': 'TfsGit',
                    r'$top': '15',
                    'api-version': '6.0',
                  },
                ),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (response.statusCode != 200) return null;
          return parseAdoBuilds(jsonDecode(response.body));
        }),
      ]);
      final pulls = results[0] as List<RepoPr>?;
      final ci = results[1] as List<RepoRun>?;

      return RepoDetailData(
        pulls: pulls ?? const [],
        ci: ci ?? const [],
        releasesSupported: false,
        pullsFailed: pulls == null,
        ciFailed: ci == null,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  // ---- Helpers -------------------------------------------------------------

  static Future<T?> _guard<T>(
    String source,
    Future<T?> Function() action,
  ) async {
    try {
      return await action();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RepoDetailService: $source failed: $e');
      }
      return null;
    }
  }

  static int? _ageDays(dynamic isoDate, DateTime now) {
    final parsed = _parseDate(isoDate);
    if (parsed == null) return null;
    final diff = now.toUtc().difference(parsed).inDays;
    return diff < 0 ? 0 : diff;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static String _branchFromRef(String? ref) {
    if (ref == null || ref.isEmpty) return '';
    const prefixes = ['refs/heads/', 'refs/tags/'];
    for (final prefix in prefixes) {
      if (ref.startsWith(prefix)) return ref.substring(prefix.length);
    }
    return ref;
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

  static String? _nested(dynamic map, String key) =>
      map is Map && map[key] is String ? map[key] as String : null;

  static dynamic _nested2(dynamic map, String key) =>
      map is Map ? map[key] : null;
}
