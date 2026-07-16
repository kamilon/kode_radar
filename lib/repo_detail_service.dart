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
    this.draft = false,
    this.url,
  });

  final String label; // e.g. "PR #7"
  final String title;
  final String author;
  final String reviewState; // one of PrReviewState
  final int? ageDays;
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

  /// Normalizes a GitHub open-PR list. GitHub approved/changes-requested state
  /// needs the per-PR reviews API (a later milestone), so review state here is
  /// `waiting` (reviewers still requested) or `none`.
  static List<RepoPr> parseGithubPulls(List<dynamic> data, DateTime now) {
    final result = <RepoPr>[];
    for (final pr in data) {
      if (pr is! Map) continue;
      final number = pr['number'];
      final title = _str(pr, 'title') ?? 'Untitled PR';
      final author = _nested(pr['user'], 'login') ?? 'unknown';
      final url = _str(pr, 'html_url');
      final draft = pr['draft'] == true;
      final reviewers = pr['requested_reviewers'];
      final teams = pr['requested_teams'];
      final waiting =
          (reviewers is List && reviewers.isNotEmpty) ||
          (teams is List && teams.isNotEmpty);
      result.add(
        RepoPr(
          label: 'PR #$number',
          title: title,
          author: author,
          reviewState: waiting ? PrReviewState.waiting : PrReviewState.none,
          ageDays: _ageDays(pr['created_at'], now),
          draft: draft,
          url: url,
        ),
      );
    }
    return result;
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
      final title = _str(pr, 'title') ?? 'Untitled PR';
      final author = _nested(pr['createdBy'], 'displayName') ?? 'unknown';
      final draft = pr['isDraft'] == true;
      final url = id == null
          ? null
          : 'https://dev.azure.com/$organization/$project/_git/$name/'
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
    for (final raw in prefs.getStringList(RepoStore.adoKey) ?? const []) {
      final map = _decode(raw);
      if (map == null) continue;
      final organization = _str(map, 'organization');
      final project = _str(map, 'project');
      final name = _str(map, 'repoName');
      if (organization == null || project == null || name == null) continue;
      if (RepoDiscoveryService.adoKey(organization, project, name) != repoKey) {
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
          final response = await httpClient
              .get(
                Uri.https('api.github.com', '/repos/$owner/$name/pulls', {
                  'state': 'open',
                  'per_page': '50',
                }),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (response.statusCode != 200) return null;
          final body = jsonDecode(response.body);
          return body is List ? parseGithubPulls(body, effectiveNow) : null;
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
          if (repositoryId == null) return const <RepoRun>[];
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
