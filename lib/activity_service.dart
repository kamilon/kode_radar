import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ci_run_history.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

class RepoActivity {
  const RepoActivity({
    required this.repoKey,
    required this.provider,
    required this.displayName,
    required this.url,
    required this.openPrCount,
    required this.needsReviewCount,
    required this.oldestOpenPrAgeDays,
    required this.lastActivity,
    required this.ciStatus,
    required this.contributors,
    required this.activityScore,
    this.recentRuns = const [],
    this.error,
  });

  /// A lightweight reference used purely for navigation (e.g. from search).
  /// The detail screen re-fetches everything via `repoKey`/`provider`.
  factory RepoActivity.reference({
    required String repoKey,
    required String provider,
    required String displayName,
    required String url,
  }) => RepoActivity(
    repoKey: repoKey,
    provider: provider,
    displayName: displayName,
    url: url,
    openPrCount: 0,
    needsReviewCount: 0,
    oldestOpenPrAgeDays: null,
    lastActivity: null,
    ciStatus: 'unknown',
    contributors: const [],
    activityScore: 0,
  );

  final String repoKey;
  final String provider;
  final String displayName;
  final String url;
  final int openPrCount;
  final int needsReviewCount;
  final int? oldestOpenPrAgeDays;
  final DateTime? lastActivity;
  final String ciStatus;
  final List<String> contributors;
  final num activityScore;

  /// Recent CI runs observed for this repo this fetch, accumulated into the CI
  /// run-history store to power the "CI trends" insight. Empty for reference
  /// entries and providers/repos with no CI.
  final List<CiRunSample> recentRuns;
  final String? error;
}

/// How the Radar orders repositories.
enum RadarSort { attention, ciStatus, openPrs, oldestPr, name }

class ActivityService {
  ActivityService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// A short label for a [RadarSort] option.
  static String radarSortLabel(RadarSort sort) => switch (sort) {
    RadarSort.attention => 'Attention',
    RadarSort.ciStatus => 'CI — failing first',
    RadarSort.openPrs => 'Most open PRs',
    RadarSort.oldestPr => 'Oldest PR first',
    RadarSort.name => 'Name (A–Z)',
  };

  /// Sorts errored/misconfigured repos ahead of healthy ones. Used as the
  /// primary key for the metric sorts so a repo whose data failed to load (and
  /// therefore reads as 0 PRs / unknown CI / no PR) is never buried among
  /// genuinely healthy repos and mistaken for one.
  static int _errorFirst(RepoActivity a, RepoActivity b) =>
      (a.error != null ? 0 : 1) - (b.error != null ? 0 : 1);

  /// Orders repositories for the Radar. A stable secondary sort by name keeps
  /// the order deterministic within ties.
  static List<RepoActivity> sortActivities(
    List<RepoActivity> activities,
    RadarSort sort,
  ) {
    int byName(RepoActivity a, RepoActivity b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    final list = List<RepoActivity>.of(activities);
    switch (sort) {
      case RadarSort.attention:
        list.sort((a, b) {
          // Repos with errors / missing tokens surface first (they need
          // attention or configuration), then by activity score, then name.
          final byErr = _errorFirst(a, b);
          if (byErr != 0) return byErr;
          final byScore = b.activityScore.compareTo(a.activityScore);
          if (byScore != 0) return byScore;
          return byName(a, b);
        });
      case RadarSort.ciStatus:
        list.sort((a, b) {
          final byErr = _errorFirst(a, b);
          if (byErr != 0) return byErr;
          final byCi = _ciRank(a.ciStatus).compareTo(_ciRank(b.ciStatus));
          if (byCi != 0) return byCi;
          final byScore = b.activityScore.compareTo(a.activityScore);
          if (byScore != 0) return byScore;
          return byName(a, b);
        });
      case RadarSort.openPrs:
        list.sort((a, b) {
          final byErr = _errorFirst(a, b);
          if (byErr != 0) return byErr;
          final byPrs = b.openPrCount.compareTo(a.openPrCount);
          if (byPrs != 0) return byPrs;
          return byName(a, b);
        });
      case RadarSort.oldestPr:
        list.sort((a, b) {
          final byErr = _errorFirst(a, b);
          if (byErr != 0) return byErr;
          // Oldest (largest age) first; repos with no open PR sort last.
          final ax = a.oldestOpenPrAgeDays ?? -1;
          final bx = b.oldestOpenPrAgeDays ?? -1;
          final byAge = bx.compareTo(ax);
          if (byAge != 0) return byAge;
          return byName(a, b);
        });
      case RadarSort.name:
        // Name is an explicit alphabetical ordering — errors are not hoisted.
        list.sort(byName);
    }
    return list;
  }

  /// Ranks CI status so failing repos surface first, then running, then
  /// unknown, then success.
  static int _ciRank(String status) {
    switch (status) {
      case 'failure':
        return 0;
      case 'running':
        return 1;
      case 'success':
        return 3;
      default:
        return 2;
    }
  }

  static List<String> extractPrAuthorsGithub(List data) {
    final authors = <String>[];
    final seen = <String>{};
    for (final item in data) {
      if (item is! Map) continue;
      final user = item['user'];
      if (user is! Map) continue;
      final login = user['login'];
      if (login is! String || login.isEmpty || seen.contains(login)) {
        continue;
      }
      seen.add(login);
      authors.add(login);
      if (authors.length == 5) break;
    }
    return authors;
  }

  static int needsReviewCountGithub(List data) {
    var count = 0;
    for (final item in data) {
      if (item is! Map) continue;
      final reviewers = item['requested_reviewers'];
      if (reviewers is List && reviewers.isNotEmpty) count++;
    }
    return count;
  }

  static DateTime? latestUpdatedAt(List data) {
    DateTime? latest;
    for (final item in data) {
      if (item is! Map) continue;
      final parsed = _parseDate(item['updated_at']);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) latest = parsed;
    }
    return latest;
  }

  static int? oldestOpenPrAgeDays(List data, DateTime now) {
    DateTime? oldest;
    for (final item in data) {
      if (item is! Map) continue;
      final parsed = _parseDate(item['created_at']);
      if (parsed == null) continue;
      if (oldest == null || parsed.isBefore(oldest)) oldest = parsed;
    }
    if (oldest == null) return null;
    final days = now.difference(oldest).inDays;
    return days < 0 ? 0 : days;
  }

  static String ciStatusFromGithubRuns(dynamic runsJson) {
    final run = _firstMapFrom(runsJson, 'workflow_runs');
    if (run == null) return 'unknown';

    final conclusion = _lowerString(run['conclusion']);
    if (conclusion == 'success') return 'success';
    if (const {
      'failure',
      'cancelled',
      'timed_out',
      'action_required',
      'startup_failure',
    }.contains(conclusion)) {
      return 'failure';
    }

    final status = _lowerString(run['status']);
    if (const {
      'queued',
      'requested',
      'waiting',
      'pending',
      'in_progress',
    }.contains(status)) {
      return 'running';
    }
    return 'unknown';
  }

  static String ciStatusFromAdoBuilds(dynamic buildsJson) {
    final build = _firstMapFrom(buildsJson, 'value');
    if (build == null) return 'unknown';

    final result = _lowerString(build['result']);
    if (result == 'succeeded') return 'success';
    if (const {
      'failed',
      'canceled',
      'cancelled',
      'partiallysucceeded',
    }.contains(result)) {
      return 'failure';
    }

    final status = _lowerString(build['status']);
    if (const {
      'inprogress',
      'notstarted',
      'postponed',
      'cancelling',
    }.contains(status)) {
      return 'running';
    }
    return 'unknown';
  }

  // ---- Per-run CI samples (for the accumulated CI trends history) ----------

  /// Normalized [CiOutcome] for a single GitHub `workflow_run` object. Only a
  /// real red result counts as a failure — a `cancelled` run (e.g. superseded
  /// by concurrency) is [CiOutcome.other] so it can't manufacture flakiness.
  static String githubRunOutcome(Map run) {
    final conclusion = _lowerString(run['conclusion']);
    if (conclusion == 'success') return CiOutcome.success;
    if (const {
      'failure',
      'timed_out',
      'startup_failure',
    }.contains(conclusion)) {
      return CiOutcome.failure;
    }
    final status = _lowerString(run['status']);
    if (const {
      'queued',
      'requested',
      'waiting',
      'pending',
      'in_progress',
    }.contains(status)) {
      return CiOutcome.running;
    }
    // cancelled / action_required / neutral / skipped / stale / unknown:
    // context only, never counted toward pass/fail rates.
    return CiOutcome.other;
  }

  /// Normalized [CiOutcome] for a single Azure DevOps build object. Only
  /// `failed` is a failure — `canceled` and `partiallySucceeded` are
  /// [CiOutcome.other] so they don't inflate the failure/flakiness rates.
  static String adoBuildOutcome(Map build) {
    final result = _lowerString(build['result']);
    if (result == 'succeeded') return CiOutcome.success;
    if (result == 'failed') return CiOutcome.failure;
    final status = _lowerString(build['status']);
    if (const {
      'inprogress',
      'notstarted',
      'postponed',
      'cancelling',
    }.contains(status)) {
      return CiOutcome.running;
    }
    return CiOutcome.other;
  }

  /// Parses a GitHub Actions `/actions/runs` response into [CiRunSample]s.
  /// Runs without an `id` are skipped (no stable de-dup key). The de-dup key
  /// includes `run_attempt` so a failed attempt kept before a successful rerun
  /// (which reuses the run id) isn't overwritten — preserving the flake signal.
  ///
  /// Only runs on the repo's **default branch** are kept (the run payload's
  /// `repository.default_branch`), so PR / feature-branch runs — which
  /// legitimately fail — don't pollute a workflow's trend. A [defaultBranch]
  /// override wins over the payload; when neither is known, all branches are
  /// kept (a safe fallback).
  static List<CiRunSample> ciRunSamplesFromGithubRuns(
    dynamic json, {
    required String repoKey,
    required String repoDisplay,
    String? defaultBranch,
  }) {
    final runs = json is Map ? json['workflow_runs'] : null;
    if (runs is! List) return const [];
    final result = <CiRunSample>[];
    for (final run in runs) {
      if (run is! Map) continue;
      final id = run['id'];
      if (id == null) continue;
      final repository = run['repository'];
      final payloadDefault = repository is Map
          ? _stringValue(repository, 'default_branch')
          : null;
      final effectiveDefault = defaultBranch ?? payloadDefault;
      final headBranch = _stringValue(run, 'head_branch');
      // Scope to the default branch when we can determine it.
      if (effectiveDefault != null && headBranch != effectiveDefault) continue;
      final attempt = _intValue(run['run_attempt']) ?? 1;
      final name =
          _stringValue(run, 'name') ??
          _stringValue(run, 'display_title') ??
          'Workflow';
      result.add(
        CiRunSample(
          provider: TokenStore.providerGithub,
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          workflow: name,
          workflowId: run['workflow_id']?.toString(),
          runKey: '$repoKey:$id:$attempt',
          outcome: githubRunOutcome(run),
          conclusion: _stringValue(run, 'conclusion') ?? '',
          branch: headBranch,
          finishedAt: _parseDate(run['updated_at']),
          url: _stringValue(run, 'html_url'),
        ),
      );
    }
    return result;
  }

  /// Parses an Azure DevOps `/build/builds` response into [CiRunSample]s.
  /// Builds without an `id` are skipped (no stable de-dup key). ADO retries
  /// create new build ids, so the id alone is a stable per-run key.
  ///
  /// Only builds on the repo's [defaultBranch] (e.g. `refs/heads/main`, from
  /// the repository GET) are kept, so PR / topic-branch builds don't pollute a
  /// pipeline's trend. When [defaultBranch] is null, all branches are kept.
  static List<CiRunSample> ciRunSamplesFromAdoBuilds(
    dynamic json, {
    required String repoKey,
    required String repoDisplay,
    String? defaultBranch,
  }) {
    final builds = json is Map ? json['value'] : json;
    if (builds is! List) return const [];
    final result = <CiRunSample>[];
    for (final build in builds) {
      if (build is! Map) continue;
      final id = build['id'];
      if (id == null) continue;
      final sourceBranch = _stringValue(build, 'sourceBranch');
      // Scope to the default branch when we know it.
      if (defaultBranch != null && sourceBranch != defaultBranch) continue;
      final definition = build['definition'];
      final defName = definition is Map ? definition['name'] : null;
      final workflow = defName is String && defName.isNotEmpty
          ? defName
          : 'Build';
      final defId = definition is Map ? definition['id'] : null;
      String? url;
      final links = build['_links'];
      if (links is Map) {
        final web = links['web'];
        if (web is Map && web['href'] is String) url = web['href'] as String;
      }
      result.add(
        CiRunSample(
          provider: TokenStore.providerAdo,
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          workflow: workflow,
          workflowId: defId?.toString(),
          runKey: '$repoKey:$id',
          outcome: adoBuildOutcome(build),
          conclusion: _stringValue(build, 'result') ?? '',
          branch: sourceBranch,
          finishedAt: _parseDate(build['finishTime']),
          url: url,
        ),
      );
    }
    return result;
  }

  /// Whether [runs] contains a run that counts toward trend rates — a completed
  /// (pass/fail) run with a finish time. This is stricter than the store's
  /// record filter (which also persists `other`/cancelled runs): a page whose
  /// only default-branch runs are in-progress or cancelled has no rate-bearing
  /// sample, so we still want the branch-scoped trend follow-up to fire.
  static bool _hasCompletedTrendRun(List<CiRunSample> runs) => runs.any(
    (run) => CiOutcome.isCompleted(run.outcome) && run.finishedAt != null,
  );

  /// The repo's default branch as reported inside a GitHub `/actions/runs`
  /// payload (each run carries a minimal `repository` with `default_branch`),
  /// or null when no run exposes it. Lets a caller do a branch-scoped follow-up
  /// fetch when the unscoped page contained no default-branch runs.
  static String? defaultBranchFromGithubRuns(dynamic json) {
    final runs = json is Map ? json['workflow_runs'] : null;
    if (runs is! List) return null;
    for (final run in runs) {
      if (run is! Map) continue;
      final repository = run['repository'];
      if (repository is Map) {
        final branch = _stringValue(repository, 'default_branch');
        if (branch != null) return branch;
      }
    }
    return null;
  }

  static num scoreActivity({
    required int openPrCount,
    required int needsReviewCount,
    required DateTime? lastActivity,
    required DateTime now,
    String ciStatus = 'unknown',
    int? oldestOpenPrAgeDays,
  }) {
    final recencyBonus = _recencyBonus(lastActivity, now);
    // Attention weighting: failing CI and long-stuck PRs raise the score so
    // repos that need a human bubble up, not just busy ones.
    final ciBonus = ciStatus == 'failure' ? 5 : 0;
    final staleBonus = (oldestOpenPrAgeDays != null && oldestOpenPrAgeDays > 14)
        ? 3
        : 0;
    return openPrCount +
        (needsReviewCount * 2) +
        recencyBonus +
        ciBonus +
        staleBonus;
  }

  static List<String> extractPrAuthorsAdo(List data) {
    final authors = <String>[];
    final seen = <String>{};
    for (final item in data) {
      if (item is! Map) continue;
      final createdBy = item['createdBy'];
      if (createdBy is! Map) continue;
      final displayName = createdBy['displayName'];
      if (displayName is! String ||
          displayName.isEmpty ||
          seen.contains(displayName)) {
        continue;
      }
      seen.add(displayName);
      authors.add(displayName);
      if (authors.length == 5) break;
    }
    return authors;
  }

  static int needsReviewCountAdo(List data) {
    var count = 0;
    for (final item in data) {
      if (item is! Map) continue;
      final reviewers = item['reviewers'];
      if (reviewers is List &&
          reviewers.any(
            (reviewer) => reviewer is Map && _intValue(reviewer['vote']) == 0,
          )) {
        count++;
      }
    }
    return count;
  }

  static DateTime? latestCreatedAtAdo(List data) {
    DateTime? latest;
    for (final item in data) {
      if (item is! Map) continue;
      final parsed = _parseDate(item['creationDate']);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) latest = parsed;
    }
    return latest;
  }

  static int? oldestOpenPrAgeDaysAdo(List data, DateTime now) {
    DateTime? oldest;
    for (final item in data) {
      if (item is! Map) continue;
      final parsed = _parseDate(item['creationDate']);
      if (parsed == null) continue;
      if (oldest == null || parsed.isBefore(oldest)) oldest = parsed;
    }
    if (oldest == null) return null;
    final days = now.difference(oldest).inDays;
    return days < 0 ? 0 : days;
  }

  static Future<RepoActivity> computeForGithub({
    required String owner,
    required String name,
    required String? secret,
    required String repoKey,
    http.Client? client,
  }) async {
    final displayName = '$owner/$name';
    final url = 'https://github.com/$owner/$name';
    if (secret == null || secret.trim().isEmpty) {
      return _githubActivity(
        repoKey: repoKey,
        displayName: displayName,
        url: url,
        error: 'Token not set',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final errors = <String>[];
      final headers = {
        'Authorization': 'Bearer ${secret.trim()}',
        'Accept': 'application/vnd.github+json',
      };
      var prs = <dynamic>[];
      var ciStatus = 'unknown';
      var recentRuns = const <CiRunSample>[];

      try {
        final response = await httpClient
            .get(
              Uri.https('api.github.com', '/repos/$owner/$name/pulls', {
                'state': 'open',
                'per_page': '100',
              }),
              headers: headers,
            )
            .timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            prs = decoded;
          } else {
            errors.add('GitHub pulls returned unexpected data');
          }
        } else {
          errors.add('GitHub pulls returned status ${response.statusCode}');
        }
      } catch (e) {
        errors.add('GitHub pulls error: $e');
      }

      try {
        // Fetch a page of recent runs (not just the latest): the newest still
        // drives ciStatus, while the rest accumulate into the CI trends history.
        // A wider page reduces the chance that default-branch runs (kept for
        // trends) are all pushed past the window by a burst of PR-branch runs.
        final response = await httpClient
            .get(
              Uri.https('api.github.com', '/repos/$owner/$name/actions/runs', {
                'per_page': '50',
              }),
              headers: headers,
            )
            .timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          ciStatus = ciStatusFromGithubRuns(decoded);
          recentRuns = ciRunSamplesFromGithubRuns(
            decoded,
            repoKey: repoKey,
            repoDisplay: displayName,
          );
          // Trends need a completed (pass/fail) default-branch run. If the
          // all-branch page yielded none — e.g. a PR-heavy repo whose main-
          // branch runs are past the window — and the page was full (so older
          // runs exist), do a branch-scoped follow-up just for trends. ciStatus
          // stays all-branch (from the first page above).
          final runsList = decoded is Map ? decoded['workflow_runs'] : null;
          final pageWasFull = runsList is List && runsList.length >= 50;
          if (pageWasFull && !_hasCompletedTrendRun(recentRuns)) {
            final defaultBranch = defaultBranchFromGithubRuns(decoded);
            if (defaultBranch != null) {
              final scoped = await httpClient
                  .get(
                    Uri.https(
                      'api.github.com',
                      '/repos/$owner/$name/actions/runs',
                      {'branch': defaultBranch, 'per_page': '20'},
                    ),
                    headers: headers,
                  )
                  .timeout(_requestTimeout);
              if (scoped.statusCode == 200) {
                recentRuns = ciRunSamplesFromGithubRuns(
                  jsonDecode(scoped.body),
                  repoKey: repoKey,
                  repoDisplay: displayName,
                  defaultBranch: defaultBranch,
                );
              }
            }
          }
        } else {
          errors.add('GitHub actions returned status ${response.statusCode}');
        }
      } catch (e) {
        errors.add('GitHub actions error: $e');
      }

      final now = DateTime.now();
      final needsReviewCount = needsReviewCountGithub(prs);
      final lastActivity = latestUpdatedAt(prs);
      final oldestAge = oldestOpenPrAgeDays(prs, now);
      return _githubActivity(
        repoKey: repoKey,
        displayName: displayName,
        url: url,
        openPrCount: prs.length,
        needsReviewCount: needsReviewCount,
        oldestOpenPrAgeDays: oldestAge,
        lastActivity: lastActivity,
        ciStatus: ciStatus,
        contributors: extractPrAuthorsGithub(prs),
        activityScore: scoreActivity(
          openPrCount: prs.length,
          needsReviewCount: needsReviewCount,
          lastActivity: lastActivity,
          now: now,
          ciStatus: ciStatus,
          oldestOpenPrAgeDays: oldestAge,
        ),
        recentRuns: recentRuns,
        error: errors.isEmpty ? null : errors.join('; '),
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<RepoActivity> computeForAdo({
    required String organization,
    required String project,
    required String name,
    required String? secret,
    required String repoKey,
    http.Client? client,
  }) async {
    final displayName = '$organization/$project/$name';
    final url = 'https://dev.azure.com/$organization/$project/_git/$name';
    if (secret == null || secret.trim().isEmpty) {
      return _adoActivity(
        repoKey: repoKey,
        displayName: displayName,
        url: url,
        error: 'Token not set',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final errors = <String>[];
      final headers = {
        'Authorization':
            'Basic ${base64Encode(utf8.encode(':${secret.trim()}'))}',
      };
      var prs = <dynamic>[];
      var ciStatus = 'unknown';
      var recentRuns = const <CiRunSample>[];

      try {
        final response = await httpClient
            .get(
              Uri.https(
                'dev.azure.com',
                '/$organization/$project/_apis/git/repositories/$name/pullrequests',
                {'searchCriteria.status': 'active', 'api-version': '6.0'},
              ),
              headers: headers,
            )
            .timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final value = decoded is Map ? decoded['value'] : decoded;
          if (value is List) {
            prs = value;
          } else {
            errors.add('Azure DevOps PRs returned unexpected data');
          }
        } else {
          errors.add('Azure DevOps PRs returned status ${response.statusCode}');
        }
      } catch (e) {
        errors.add('Azure DevOps PRs error: $e');
      }

      try {
        // The ADO builds list is project-wide, so scope CI to THIS repo by
        // resolving its GUID first. If we can't, we leave CI 'unknown' rather
        // than show an unrelated project build.
        String? repositoryId;
        String? defaultBranch;
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
        if (repoResp.statusCode == 200) {
          final decoded = jsonDecode(repoResp.body);
          if (decoded is Map) {
            repositoryId = decoded['id'] as String?;
            defaultBranch = decoded['defaultBranch'] as String?;
          }
        }

        if (repositoryId != null) {
          // Fetch a page of recent builds newest-first: the latest drives
          // ciStatus (all-branch, like GitHub), the rest feed the CI trends
          // history. A wider page reduces the chance default-branch builds are
          // crowded out of the window by a burst of PR-branch builds; the
          // default-branch scoping itself happens in the parser.
          final response = await httpClient
              .get(
                Uri.https(
                  'dev.azure.com',
                  '/$organization/$project/_apis/build/builds',
                  {
                    'repositoryId': repositoryId,
                    'repositoryType': 'TfsGit',
                    'queryOrder': 'finishTimeDescending',
                    r'$top': '50',
                    'api-version': '6.0',
                  },
                ),
                headers: headers,
              )
              .timeout(_requestTimeout);
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            ciStatus = ciStatusFromAdoBuilds(decoded);
            recentRuns = ciRunSamplesFromAdoBuilds(
              decoded,
              repoKey: repoKey,
              repoDisplay: displayName,
              defaultBranch: defaultBranch,
            );
            // As with GitHub: if the all-branch page had no completed default-
            // branch build and was full (older builds exist), do a scoped
            // follow-up just for trends. ciStatus stays all-branch.
            final buildsList = decoded is Map ? decoded['value'] : null;
            final pageWasFull = buildsList is List && buildsList.length >= 50;
            if (pageWasFull &&
                defaultBranch != null &&
                !_hasCompletedTrendRun(recentRuns)) {
              final scoped = await httpClient
                  .get(
                    Uri.https(
                      'dev.azure.com',
                      '/$organization/$project/_apis/build/builds',
                      {
                        'repositoryId': repositoryId,
                        'repositoryType': 'TfsGit',
                        'queryOrder': 'finishTimeDescending',
                        'branchName': defaultBranch,
                        r'$top': '20',
                        'api-version': '6.0',
                      },
                    ),
                    headers: headers,
                  )
                  .timeout(_requestTimeout);
              if (scoped.statusCode == 200) {
                recentRuns = ciRunSamplesFromAdoBuilds(
                  jsonDecode(scoped.body),
                  repoKey: repoKey,
                  repoDisplay: displayName,
                  defaultBranch: defaultBranch,
                );
              }
            }
          } else {
            errors.add(
              'Azure DevOps builds returned status ${response.statusCode}',
            );
          }
        }
      } catch (e) {
        errors.add('Azure DevOps builds error: $e');
      }

      final now = DateTime.now();
      final needsReviewCount = needsReviewCountAdo(prs);
      final lastActivity = latestCreatedAtAdo(prs);
      final oldestAge = oldestOpenPrAgeDaysAdo(prs, now);
      return _adoActivity(
        repoKey: repoKey,
        displayName: displayName,
        url: url,
        openPrCount: prs.length,
        needsReviewCount: needsReviewCount,
        oldestOpenPrAgeDays: oldestAge,
        lastActivity: lastActivity,
        ciStatus: ciStatus,
        contributors: extractPrAuthorsAdo(prs),
        activityScore: scoreActivity(
          openPrCount: prs.length,
          needsReviewCount: needsReviewCount,
          lastActivity: lastActivity,
          now: now,
          ciStatus: ciStatus,
          oldestOpenPrAgeDays: oldestAge,
        ),
        recentRuns: recentRuns,
        error: errors.isEmpty ? null : errors.join('; '),
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<List<RepoActivity>> computeAll({
    http.Client? client,
    int concurrency = 5,
    Set<String>? onlyRepoKeys,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final prefs = await SharedPreferences.getInstance();
      final githubRepos =
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[];
      final adoRepos =
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[];

      // Build one task per repo; each resolves its token then computes.
      final tasks = <Future<RepoActivity> Function()>[];

      for (final raw in githubRepos) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          final owner = _stringValue(decoded, 'owner');
          final name = _stringValue(decoded, 'repoName');
          if (owner == null || name == null) continue;
          final repoKey = RepoDiscoveryService.githubKey(owner, name);
          if (onlyRepoKeys != null && !onlyRepoKeys.contains(repoKey)) continue;
          final tokenId = _stringValue(decoded, 'tokenId');
          tasks.add(() async {
            try {
              final secret = await TokenStore.resolveGithubSecret(
                owner,
                tokenId: tokenId,
              );
              return await computeForGithub(
                owner: owner,
                name: name,
                secret: secret,
                repoKey: repoKey,
                client: httpClient,
              );
            } catch (e) {
              return _githubActivity(
                repoKey: repoKey,
                displayName: '$owner/$name',
                url: 'https://github.com/$owner/$name',
                error: 'Error: $e',
              );
            }
          });
        } catch (_) {
          // Skip malformed entries.
        }
      }

      for (final raw in adoRepos) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          final organization = _stringValue(decoded, 'organization');
          final project = _stringValue(decoded, 'project');
          final name = _stringValue(decoded, 'repoName');
          if (organization == null || project == null || name == null) {
            continue;
          }
          final repoKey = RepoDiscoveryService.adoKey(
            organization,
            project,
            name,
          );
          if (onlyRepoKeys != null && !onlyRepoKeys.contains(repoKey)) continue;
          final tokenId = _stringValue(decoded, 'tokenId');
          tasks.add(() async {
            try {
              final secret = await TokenStore.resolveAdoSecret(
                organization,
                tokenId: tokenId,
              );
              return await computeForAdo(
                organization: organization,
                project: project,
                name: name,
                secret: secret,
                repoKey: repoKey,
                client: httpClient,
              );
            } catch (e) {
              return _adoActivity(
                repoKey: repoKey,
                displayName: '$organization/$project/$name',
                url: 'https://dev.azure.com/$organization/$project/_git/$name',
                error: 'Error: $e',
              );
            }
          });
        } catch (_) {
          // Skip malformed entries.
        }
      }

      final activities = await _runBounded(tasks, concurrency);
      return sortActivities(activities, RadarSort.attention);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Runs [tasks] with at most [concurrency] in flight. Order of results is not
  /// meaningful (the caller sorts).
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

  static RepoActivity _githubActivity({
    required String repoKey,
    required String displayName,
    required String url,
    int openPrCount = 0,
    int needsReviewCount = 0,
    int? oldestOpenPrAgeDays,
    DateTime? lastActivity,
    String ciStatus = 'unknown',
    List<String> contributors = const [],
    num activityScore = 0,
    List<CiRunSample> recentRuns = const [],
    String? error,
  }) {
    return RepoActivity(
      repoKey: repoKey,
      provider: TokenStore.providerGithub,
      displayName: displayName,
      url: url,
      openPrCount: openPrCount,
      needsReviewCount: needsReviewCount,
      oldestOpenPrAgeDays: oldestOpenPrAgeDays,
      lastActivity: lastActivity,
      ciStatus: ciStatus,
      contributors: contributors,
      activityScore: activityScore,
      recentRuns: recentRuns,
      error: error,
    );
  }

  static RepoActivity _adoActivity({
    required String repoKey,
    required String displayName,
    required String url,
    int openPrCount = 0,
    int needsReviewCount = 0,
    int? oldestOpenPrAgeDays,
    DateTime? lastActivity,
    String ciStatus = 'unknown',
    List<String> contributors = const [],
    num activityScore = 0,
    List<CiRunSample> recentRuns = const [],
    String? error,
  }) {
    return RepoActivity(
      repoKey: repoKey,
      provider: TokenStore.providerAdo,
      displayName: displayName,
      url: url,
      openPrCount: openPrCount,
      needsReviewCount: needsReviewCount,
      oldestOpenPrAgeDays: oldestOpenPrAgeDays,
      lastActivity: lastActivity,
      ciStatus: ciStatus,
      contributors: contributors,
      activityScore: activityScore,
      recentRuns: recentRuns,
      error: error,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static int _recencyBonus(DateTime? lastActivity, DateTime now) {
    if (lastActivity == null) return 0;
    final difference = now.difference(lastActivity);
    if (difference.inDays < 1) return 5;
    if (difference.inDays < 7) return 3;
    if (difference.inDays < 30) return 1;
    return 0;
  }

  static Map? _firstMapFrom(dynamic json, String key) {
    final list = json is Map ? json[key] : json;
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    return first is Map ? first : null;
  }

  static String? _lowerString(dynamic value) {
    if (value is! String) return null;
    return value.toLowerCase();
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static String? _stringValue(Map map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}
