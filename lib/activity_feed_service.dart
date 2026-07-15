import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_event.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// Outcome of fetching the whole feed: the merged events plus health signals
/// so the UI can distinguish "genuinely quiet" from "some sources failed" or
/// "there may be more than we fetched".
class ActivityFeedResult {
  const ActivityFeedResult({
    required this.events,
    this.failedSources = 0,
    this.truncated = false,
  });

  final List<ActivityEvent> events;

  /// Number of source fetches that errored or returned a non-200 status.
  final int failedSources;

  /// True when at least one history source returned a full page, so older
  /// in-window events may have been omitted.
  final bool truncated;
}

/// Builds a reverse-chronological, provider-agnostic activity feed across all
/// monitored repositories.
///
/// GitHub is sourced from the repo events timeline (`/events`) plus Actions run
/// history (for CI failures); Azure DevOps is derived from pull requests,
/// pushes, and failed builds. Every source is normalized to [ActivityEvent] and
/// merged into one time-ordered stream. Per-source failures are isolated so one
/// slow or forbidden endpoint never blanks the whole feed.
class ActivityFeedService {
  ActivityFeedService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Events older than this (relative to `now`) are dropped from the feed.
  static const Duration defaultLookback = Duration(days: 14);

  /// Safety cap on the merged feed length.
  static const int maxEvents = 500;

  // ---- Pure, testable normalizers ------------------------------------------

  /// Normalizes a GitHub `/events` timeline into activity events.
  static List<ActivityEvent> githubEventsToActivity({
    required String repoDisplay,
    required String repoKey,
    required List<dynamic> events,
    Set<String> selfGithubLogins = const {},
  }) {
    final self = selfGithubLogins.map((e) => e.trim().toLowerCase()).toSet();
    final result = <ActivityEvent>[];
    for (final event in events) {
      if (event is! Map) continue;
      final occurredAt = _parseDate(event['created_at']);
      if (occurredAt == null) continue;
      final actor = _nested(event['actor'], 'login') ?? '';
      final mine = self.isNotEmpty && self.contains(actor.trim().toLowerCase());
      final eventId = _stringy(event['id']);
      final payload = event['payload'];
      final ghType = _str(event, 'type');
      if (payload is! Map || ghType == null) continue;

      switch (ghType) {
        case 'PushEvent':
          final branch = _branchFromRef(_str(payload, 'ref'));
          final size = _int(payload['size']) ?? _int(payload['distinct_size']);
          final commits = payload['commits'];
          final count = size ?? (commits is List ? commits.length : null) ?? 0;
          final noun = count == 1 ? 'commit' : 'commits';
          final before = _str(payload, 'before');
          final head = _str(payload, 'head');
          final String url;
          if (before != null && head != null) {
            url = 'https://github.com/$repoDisplay/compare/$before...$head';
          } else if (branch.isEmpty) {
            url = 'https://github.com/$repoDisplay/commits';
          } else {
            url = 'https://github.com/$repoDisplay/commits/$branch';
          }
          result.add(
            ActivityEvent(
              id: 'gh-event:${eventId ?? '$repoKey:${occurredAt.toIso8601String()}'}',
              type: ActivityType.push,
              provider: 'github',
              repoKey: repoKey,
              repoDisplay: repoDisplay,
              actor: actor,
              title:
                  '${actor.isEmpty ? 'Someone' : actor} pushed $count $noun'
                  '${branch.isEmpty ? '' : ' to $branch'}',
              subtitle: repoDisplay,
              occurredAt: occurredAt,
              url: url,
              isMine: mine,
            ),
          );
          break;
        case 'PullRequestEvent':
          final action = _str(payload, 'action');
          final pr = payload['pull_request'];
          if (pr is! Map) break;
          final number = _stringy(pr['number']);
          final prTitle = _str(pr, 'title') ?? 'Untitled PR';
          final url = _str(pr, 'html_url');
          final String type;
          final String verb;
          if (action == 'opened' || action == 'reopened') {
            type = ActivityType.prOpened;
            verb = 'opened';
          } else if (action == 'closed') {
            final merged = pr['merged'] == true || pr['merged_at'] != null;
            type = merged ? ActivityType.prMerged : ActivityType.prClosed;
            verb = merged ? 'merged' : 'closed';
          } else {
            break; // ignore edited/labeled/synchronize/etc.
          }
          result.add(
            ActivityEvent(
              id: 'gh-event:${eventId ?? '$repoKey:pr$number:$verb'}',
              type: type,
              provider: 'github',
              repoKey: repoKey,
              repoDisplay: repoDisplay,
              actor: actor,
              title: '${actor.isEmpty ? 'Someone' : actor} $verb PR #$number',
              subtitle: '$repoDisplay · $prTitle',
              occurredAt: occurredAt,
              url: url,
              isMine: mine,
            ),
          );
          break;
        case 'PullRequestReviewEvent':
          if (_str(payload, 'action') != 'submitted') break;
          final pr = payload['pull_request'];
          final review = payload['review'];
          if (pr is! Map) break;
          final number = _stringy(pr['number']);
          final prTitle = _str(pr, 'title') ?? 'Untitled PR';
          final state = review is Map ? _str(review, 'state') : null;
          final verb = _reviewVerb(state);
          final url =
              (review is Map ? _str(review, 'html_url') : null) ??
              _str(pr, 'html_url');
          result.add(
            ActivityEvent(
              id: 'gh-event:${eventId ?? '$repoKey:review:pr$number'}',
              type: ActivityType.reviewSubmitted,
              provider: 'github',
              repoKey: repoKey,
              repoDisplay: repoDisplay,
              actor: actor,
              title: '${actor.isEmpty ? 'Someone' : actor} $verb PR #$number',
              subtitle: '$repoDisplay · $prTitle',
              occurredAt: occurredAt,
              url: url,
              isMine: mine,
            ),
          );
          break;
        case 'ReleaseEvent':
          if (_str(payload, 'action') != 'published') break;
          final release = payload['release'];
          if (release is! Map) break;
          final tag = _str(release, 'tag_name') ?? '';
          final relName = _str(release, 'name');
          final url = _str(release, 'html_url');
          result.add(
            ActivityEvent(
              id: 'gh-event:${eventId ?? '$repoKey:release:$tag'}',
              type: ActivityType.release,
              provider: 'github',
              repoKey: repoKey,
              repoDisplay: repoDisplay,
              actor: actor,
              title:
                  '${actor.isEmpty ? 'Someone' : actor} released ${tag.isEmpty ? (relName ?? 'a new version') : tag}',
              subtitle: relName == null || relName.isEmpty
                  ? repoDisplay
                  : '$repoDisplay · $relName',
              occurredAt: occurredAt,
              url: url,
              isMine: mine,
            ),
          );
          break;
        default:
          break;
      }
    }
    return result;
  }

  /// Normalizes a GitHub Actions `/actions/runs` response into CI-failure
  /// events (completed runs whose conclusion indicates failure).
  static List<ActivityEvent> githubRunsToActivity({
    required String repoDisplay,
    required String repoKey,
    required dynamic body,
    Set<String> selfGithubLogins = const {},
  }) {
    final self = selfGithubLogins.map((e) => e.trim().toLowerCase()).toSet();
    final runs = body is Map ? body['workflow_runs'] : null;
    if (runs is! List) return const [];
    const failing = {'failure', 'timed_out', 'startup_failure'};
    final result = <ActivityEvent>[];
    for (final run in runs) {
      if (run is! Map) continue;
      if (_str(run, 'status') != 'completed') continue;
      final conclusion = _str(run, 'conclusion');
      if (conclusion == null || !failing.contains(conclusion)) continue;
      final occurredAt =
          _parseDate(run['updated_at']) ?? _parseDate(run['run_started_at']);
      if (occurredAt == null) continue;
      final name =
          _str(run, 'name') ?? _str(run, 'display_title') ?? 'Workflow';
      final branch = _str(run, 'head_branch');
      final branchSuffix = (branch == null || branch.isEmpty)
          ? ''
          : ' on $branch';
      final actor =
          _nested(run['actor'], 'login') ??
          _nested(run['triggering_actor'], 'login') ??
          '';
      final runId = _stringy(run['id']);
      final mine = self.isNotEmpty && self.contains(actor.trim().toLowerCase());
      result.add(
        ActivityEvent(
          id: 'gh-run:${runId ?? '$repoKey:${occurredAt.toIso8601String()}'}',
          type: ActivityType.ciFailed,
          provider: 'github',
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          actor: actor,
          title: 'CI failed: $name$branchSuffix',
          subtitle: repoDisplay,
          occurredAt: occurredAt,
          url: _str(run, 'html_url'),
          isMine: mine,
        ),
      );
    }
    return result;
  }

  /// Normalizes an Azure DevOps pull-request list (`status=all`) into
  /// opened/merged/closed events.
  static List<ActivityEvent> adoPrsToActivity({
    required String repoDisplay,
    required String repoKey,
    required String organization,
    required String project,
    required String name,
    required List<dynamic> prs,
    Set<String> selfAdoNames = const {},
  }) {
    final self = selfAdoNames.map((e) => e.trim().toLowerCase()).toSet();
    final result = <ActivityEvent>[];
    for (final pr in prs) {
      if (pr is! Map) continue;
      final id = _stringy(pr['pullRequestId']);
      if (id == null) continue;
      final title = _str(pr, 'title') ?? 'Untitled PR';
      final opener = _nested(pr['createdBy'], 'displayName') ?? '';
      final url =
          'https://dev.azure.com/$organization/$project/_git/$name/'
          'pullrequest/$id';

      final opened = _parseDate(pr['creationDate']);
      if (opened != null) {
        result.add(
          _adoPrEvent(
            id: 'ado-pr:$repoKey:$id:opened',
            type: ActivityType.prOpened,
            repoKey: repoKey,
            repoDisplay: repoDisplay,
            actor: opener,
            title: '${opener.isEmpty ? 'Someone' : opener} opened PR #$id',
            subtitle: '$repoDisplay · $title',
            occurredAt: opened,
            url: url,
            self: self,
          ),
        );
      }

      final status = _str(pr, 'status');
      final closed = _parseDate(pr['closedDate']);
      if (closed != null && (status == 'completed' || status == 'abandoned')) {
        final merged = status == 'completed';
        final actor = _nested(pr['closedBy'], 'displayName') ?? '';
        result.add(
          _adoPrEvent(
            id: 'ado-pr:$repoKey:$id:${merged ? 'merged' : 'closed'}',
            type: merged ? ActivityType.prMerged : ActivityType.prClosed,
            repoKey: repoKey,
            repoDisplay: repoDisplay,
            actor: actor,
            title:
                '${actor.isEmpty ? 'Someone' : actor} '
                '${merged ? 'merged' : 'closed'} PR #$id',
            subtitle: '$repoDisplay · $title',
            occurredAt: closed,
            url: url,
            self: self,
          ),
        );
      }
    }
    return result;
  }

  /// Normalizes an Azure DevOps pushes response into push events.
  static List<ActivityEvent> adoPushesToActivity({
    required String repoDisplay,
    required String repoKey,
    required String organization,
    required String project,
    required String name,
    required dynamic body,
    Set<String> selfAdoNames = const {},
  }) {
    final self = selfAdoNames.map((e) => e.trim().toLowerCase()).toSet();
    final pushes = body is Map ? body['value'] : body;
    if (pushes is! List) return const [];
    final result = <ActivityEvent>[];
    for (final push in pushes) {
      if (push is! Map) continue;
      final pushId = _stringy(push['pushId']);
      final occurredAt = _parseDate(push['date']);
      if (occurredAt == null) continue;
      final actor = _nested(push['pushedBy'], 'displayName') ?? '';
      final refUpdates = push['refUpdates'];
      String branch = '';
      if (refUpdates is List && refUpdates.isNotEmpty) {
        branch = _branchFromRef(_nested(refUpdates.first, 'name'));
      }
      final mine = self.isNotEmpty && self.contains(actor.trim().toLowerCase());
      result.add(
        ActivityEvent(
          id: 'ado-push:$repoKey:${pushId ?? occurredAt.toIso8601String()}',
          type: ActivityType.push,
          provider: 'ado',
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          actor: actor,
          title:
              '${actor.isEmpty ? 'Someone' : actor} pushed${branch.isEmpty ? '' : ' to $branch'}',
          subtitle: repoDisplay,
          occurredAt: occurredAt,
          url: pushId == null
              ? null
              : 'https://dev.azure.com/$organization/$project/_git/$name/'
                    'pushes/$pushId',
          isMine: mine,
        ),
      );
    }
    return result;
  }

  /// Normalizes an Azure DevOps builds response into CI-failure events.
  static List<ActivityEvent> adoBuildsToActivity({
    required String repoDisplay,
    required String repoKey,
    required dynamic body,
    Set<String> selfAdoNames = const {},
  }) {
    final self = selfAdoNames.map((e) => e.trim().toLowerCase()).toSet();
    final builds = body is Map ? body['value'] : body;
    if (builds is! List) return const [];
    final result = <ActivityEvent>[];
    for (final build in builds) {
      if (build is! Map) continue;
      if (_str(build, 'result') != 'failed') continue;
      final occurredAt = _parseDate(build['finishTime']);
      if (occurredAt == null) continue;
      final buildId = _stringy(build['id']);
      final defName = _nested(build['definition'], 'name') ?? 'Build';
      final branch = _branchFromRef(_str(build, 'sourceBranch'));
      final actor = _nested(build['requestedFor'], 'displayName') ?? '';
      final url = _nested(_nested2(build['_links'], 'web'), 'href');
      final mine = self.isNotEmpty && self.contains(actor.trim().toLowerCase());
      result.add(
        ActivityEvent(
          id: 'ado-build:$repoKey:${buildId ?? occurredAt.toIso8601String()}',
          type: ActivityType.ciFailed,
          provider: 'ado',
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          actor: actor,
          title: 'CI failed: $defName${branch.isEmpty ? '' : ' on $branch'}',
          subtitle: repoDisplay,
          occurredAt: occurredAt,
          url: url,
          isMine: mine,
        ),
      );
    }
    return result;
  }

  /// Filters [events] to those authored by a person with the given provider
  /// identities (GitHub logins matched case-insensitively; ADO display names
  /// matched case-insensitively/trimmed).
  static List<ActivityEvent> eventsForActor(
    List<ActivityEvent> events, {
    Set<String> githubLogins = const {},
    Set<String> adoNames = const {},
  }) {
    final gh = githubLogins.map((e) => e.trim().toLowerCase()).toSet();
    final ado = adoNames.map((e) => e.trim().toLowerCase()).toSet();
    return events.where((event) {
      final actor = event.actor.trim().toLowerCase();
      if (actor.isEmpty) return false;
      if (event.provider == 'github') return gh.contains(actor);
      if (event.provider == 'ado') return ado.contains(actor);
      return false;
    }).toList();
  }

  /// Filters [events] to those in any of the given repository [repoKeys].
  static List<ActivityEvent> eventsForRepoKeys(
    List<ActivityEvent> events,
    Set<String> repoKeys,
  ) {
    if (repoKeys.isEmpty) return const [];
    return events.where((event) => repoKeys.contains(event.repoKey)).toList();
  }

  /// Sorts newest-first, de-duplicates by id, and keeps only events at or after
  /// [since] (capped at [maxEvents]).
  static List<ActivityEvent> mergeAndWindow(
    Iterable<ActivityEvent> events,
    DateTime since,
  ) {
    final seen = <String>{};
    final windowed = <ActivityEvent>[];
    for (final event in events) {
      if (event.occurredAt.isBefore(since)) continue;
      if (!seen.add(event.id)) continue;
      windowed.add(event);
    }
    windowed.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (windowed.length > maxEvents) {
      return windowed.sublist(0, maxEvents);
    }
    return windowed;
  }

  // ---- Fetching ------------------------------------------------------------

  /// Fetches, normalizes, and merges the activity feed across all monitored
  /// repositories.
  static Future<ActivityFeedResult> computeAll({
    http.Client? client,
    int concurrency = 5,
    DateTime? now,
    Duration lookback = defaultLookback,
    Set<String> selfGithubLogins = const {},
    Set<String> selfAdoNames = const {},
    Set<String>? onlyRepoKeys,
    Set<String> actorGithubLogins = const {},
    Set<String> actorAdoNames = const {},
  }) async {
    final httpClient = client ?? http.Client();
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final since = effectiveNow.subtract(lookback);
    try {
      final prefs = await SharedPreferences.getInstance();
      final githubRepos =
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[];
      final adoRepos =
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[];

      final tasks = <Future<_FetchOutcome> Function()>[];

      for (final raw in githubRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final owner = _str(map, 'owner');
        final name = _str(map, 'repoName');
        if (owner == null || name == null) continue;
        if (onlyRepoKeys != null &&
            !onlyRepoKeys.contains(
              RepoDiscoveryService.githubKey(owner, name),
            )) {
          continue;
        }
        final tokenId = _str(map, 'tokenId');
        tasks.add(
          () => _githubRepoEvents(
            httpClient,
            owner,
            name,
            tokenId,
            selfGithubLogins,
            since,
          ),
        );
      }

      for (final raw in adoRepos) {
        final map = _decode(raw);
        if (map == null) continue;
        final organization = _str(map, 'organization');
        final project = _str(map, 'project');
        final name = _str(map, 'repoName');
        if (organization == null || project == null || name == null) continue;
        if (onlyRepoKeys != null &&
            !onlyRepoKeys.contains(
              RepoDiscoveryService.adoKey(organization, project, name),
            )) {
          continue;
        }
        final tokenId = _str(map, 'tokenId');
        tasks.add(
          () => _adoRepoEvents(
            httpClient,
            organization,
            project,
            name,
            tokenId,
            selfAdoNames,
            since,
          ),
        );
      }

      final outcomes = await _runBounded(tasks, concurrency);
      final combined = _FetchOutcome.merge(outcomes);
      // Apply person/repo scoping BEFORE the maxEvents cap so a quiet person or
      // team can't be evicted by unrelated high-volume repositories.
      var events = combined.events;
      if (actorGithubLogins.isNotEmpty || actorAdoNames.isNotEmpty) {
        events = eventsForActor(
          events,
          githubLogins: actorGithubLogins,
          adoNames: actorAdoNames,
        );
      }
      if (onlyRepoKeys != null) {
        events = eventsForRepoKeys(events, onlyRepoKeys);
      }
      return ActivityFeedResult(
        events: mergeAndWindow(events, since),
        failedSources: combined.failedCount,
        truncated: combined.truncated,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<_FetchOutcome> _githubRepoEvents(
    http.Client client,
    String owner,
    String name,
    String? tokenId,
    Set<String> selfGithubLogins,
    DateTime since,
  ) async {
    final repoDisplay = '$owner/$name';
    final repoKey = RepoDiscoveryService.githubKey(owner, name);
    final secret = (await TokenStore.resolveGithubSecret(
      owner,
      tokenId: tokenId,
    ))?.trim();
    if (secret == null || secret.isEmpty) {
      // A configured repo with no resolvable token can't be loaded — surface it
      // as a failed source rather than silent emptiness.
      return _FetchOutcome.failure;
    }
    final headers = {
      'Authorization': 'Bearer $secret',
      'Accept': 'application/vnd.github+json',
    };

    final events = await _guard('GitHub events', repoDisplay, () async {
      final response = await client
          .get(
            Uri.https('api.github.com', '/repos/$owner/$name/events', {
              'per_page': '100',
            }),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return _FetchOutcome.failure;
      final body = jsonDecode(response.body);
      if (body is! List) return const _FetchOutcome(<ActivityEvent>[]);
      return _FetchOutcome(
        githubEventsToActivity(
          repoDisplay: repoDisplay,
          repoKey: repoKey,
          events: body,
          selfGithubLogins: selfGithubLogins,
        ),
        truncated: _truncatedByWindow(
          body,
          100,
          since,
          (e) => e is Map ? _parseDate(e['created_at']) : null,
        ),
      );
    });

    final runs = await _guard('GitHub runs', repoDisplay, () async {
      final response = await client
          .get(
            Uri.https('api.github.com', '/repos/$owner/$name/actions/runs', {
              'per_page': '30',
            }),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return _FetchOutcome.failure;
      final body = jsonDecode(response.body);
      final runs = body is Map ? body['workflow_runs'] : null;
      return _FetchOutcome(
        githubRunsToActivity(
          repoDisplay: repoDisplay,
          repoKey: repoKey,
          body: body,
          selfGithubLogins: selfGithubLogins,
        ),
        truncated: _truncatedByWindow(
          runs,
          30,
          since,
          (r) => r is Map
              ? (_parseDate(r['updated_at']) ?? _parseDate(r['run_started_at']))
              : null,
        ),
      );
    });

    return _FetchOutcome.merge([events, runs]);
  }

  static Future<_FetchOutcome> _adoRepoEvents(
    http.Client client,
    String organization,
    String project,
    String name,
    String? tokenId,
    Set<String> selfAdoNames,
    DateTime since,
  ) async {
    final repoDisplay = '$organization/$project/$name';
    final repoKey = RepoDiscoveryService.adoKey(organization, project, name);
    final secret = (await TokenStore.resolveAdoSecret(
      organization,
      tokenId: tokenId,
    ))?.trim();
    if (secret == null || secret.isEmpty) {
      // A configured repo with no resolvable token can't be loaded — surface it
      // as a failed source rather than silent emptiness.
      return _FetchOutcome.failure;
    }
    final headers = {
      'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
    };

    final prs = await _guard('ADO PRs', repoDisplay, () async {
      final response = await client
          .get(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/git/repositories/$name/pullrequests',
              {
                'searchCriteria.status': 'all',
                r'$top': '50',
                'api-version': '6.0',
              },
            ),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return _FetchOutcome.failure;
      final body = jsonDecode(response.body);
      final value = body is Map ? body['value'] : body;
      if (value is! List) return const _FetchOutcome(<ActivityEvent>[]);
      return _FetchOutcome(
        adoPrsToActivity(
          repoDisplay: repoDisplay,
          repoKey: repoKey,
          organization: organization,
          project: project,
          name: name,
          prs: value,
          selfAdoNames: selfAdoNames,
        ),
        truncated: _truncatedByWindow(
          value,
          50,
          since,
          (p) => p is Map ? _parseDate(p['creationDate']) : null,
        ),
      );
    });

    final pushes = await _guard('ADO pushes', repoDisplay, () async {
      final response = await client
          .get(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/git/repositories/$name/pushes',
              {r'$top': '30', 'api-version': '6.0'},
            ),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return _FetchOutcome.failure;
      final body = jsonDecode(response.body);
      final value = body is Map ? body['value'] : null;
      return _FetchOutcome(
        adoPushesToActivity(
          repoDisplay: repoDisplay,
          repoKey: repoKey,
          organization: organization,
          project: project,
          name: name,
          body: body,
          selfAdoNames: selfAdoNames,
        ),
        truncated: _truncatedByWindow(
          value,
          30,
          since,
          (p) => p is Map ? _parseDate(p['date']) : null,
        ),
      );
    });

    final builds = await _guard('ADO builds', repoDisplay, () async {
      // Builds are project-wide; scope CI failures to THIS repo by resolving
      // its GUID first, otherwise we'd surface unrelated builds.
      final repoResp = await client
          .get(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/git/repositories/$name',
              {'api-version': '6.0'},
            ),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (repoResp.statusCode != 200) return _FetchOutcome.failure;
      final decoded = jsonDecode(repoResp.body);
      final repositoryId = decoded is Map ? _str(decoded, 'id') : null;
      if (repositoryId == null) return const _FetchOutcome(<ActivityEvent>[]);
      final response = await client
          .get(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/build/builds',
              {
                'repositoryId': repositoryId,
                'repositoryType': 'TfsGit',
                'resultFilter': 'failed',
                'statusFilter': 'completed',
                r'$top': '30',
                'api-version': '6.0',
              },
            ),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return _FetchOutcome.failure;
      final body = jsonDecode(response.body);
      final value = body is Map ? body['value'] : null;
      return _FetchOutcome(
        adoBuildsToActivity(
          repoDisplay: repoDisplay,
          repoKey: repoKey,
          body: body,
          selfAdoNames: selfAdoNames,
        ),
        truncated: _truncatedByWindow(
          value,
          30,
          since,
          (b) => b is Map ? _parseDate(b['finishTime']) : null,
        ),
      );
    });

    return _FetchOutcome.merge([prs, pushes, builds]);
  }

  // ---- Helpers -------------------------------------------------------------

  /// True when a fetched [page] is full (>= [cap]) AND its oldest item is still
  /// at/after [since] — i.e. older *in-window* items may lie beyond this page.
  /// If the oldest item is already older than [since], the page already spans
  /// the whole window and nothing in-window was omitted.
  static bool _truncatedByWindow(
    dynamic page,
    int cap,
    DateTime since,
    DateTime? Function(dynamic item) dateOf,
  ) {
    if (page is! List || page.length < cap) return false;
    DateTime? oldest;
    for (final item in page) {
      final date = dateOf(item);
      if (date == null) continue;
      if (oldest == null || date.isBefore(oldest)) oldest = date;
    }
    // Only assert truncation when provable: an unknown oldest date (all items
    // unparseable) is treated as not truncated.
    if (oldest == null) return false;
    return !oldest.isBefore(since);
  }

  static ActivityEvent _adoPrEvent({
    required String id,
    required String type,
    required String repoKey,
    required String repoDisplay,
    required String actor,
    required String title,
    required String subtitle,
    required DateTime occurredAt,
    required String url,
    required Set<String> self,
  }) {
    return ActivityEvent(
      id: id,
      type: type,
      provider: 'ado',
      repoKey: repoKey,
      repoDisplay: repoDisplay,
      actor: actor,
      title: title,
      subtitle: subtitle,
      occurredAt: occurredAt,
      url: url,
      isMine: self.isNotEmpty && self.contains(actor.trim().toLowerCase()),
    );
  }

  static String _reviewVerb(String? state) {
    switch (state) {
      case 'approved':
        return 'approved';
      case 'changes_requested':
        return 'requested changes on';
      case 'commented':
      case 'dismissed':
      default:
        return 'reviewed';
    }
  }

  static Future<_FetchOutcome> _guard(
    String source,
    String repoDisplay,
    Future<_FetchOutcome> Function() action,
  ) async {
    try {
      return await action();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ActivityFeedService: $source failed for $repoDisplay: $e');
      }
      return _FetchOutcome.failure;
    }
  }

  static String _branchFromRef(String? ref) {
    if (ref == null || ref.isEmpty) return '';
    const prefixes = ['refs/heads/', 'refs/tags/'];
    for (final prefix in prefixes) {
      if (ref.startsWith(prefix)) return ref.substring(prefix.length);
    }
    return ref;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }

  static String? _str(Map map, String key) {
    final value = map[key];
    return value is String ? value : null;
  }

  static String? _nested(dynamic map, String key) =>
      map is Map && map[key] is String ? map[key] as String : null;

  static dynamic _nested2(dynamic map, String key) =>
      map is Map ? map[key] : null;

  static String? _stringy(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
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

/// Internal per-source fetch result: parsed events plus how many sources failed
/// and whether any hit its page cap. Aggregated into [ActivityFeedResult].
class _FetchOutcome {
  const _FetchOutcome(
    this.events, {
    this.failedCount = 0,
    this.truncated = false,
  });

  /// A single failed source (non-200 or thrown).
  static const _FetchOutcome failure = _FetchOutcome(
    <ActivityEvent>[],
    failedCount: 1,
  );

  final List<ActivityEvent> events;
  final int failedCount;
  final bool truncated;

  static _FetchOutcome merge(Iterable<_FetchOutcome> parts) {
    final events = <ActivityEvent>[];
    var failed = 0;
    var truncated = false;
    for (final part in parts) {
      events.addAll(part.events);
      failed += part.failedCount;
      truncated = truncated || part.truncated;
    }
    return _FetchOutcome(events, failedCount: failed, truncated: truncated);
  }
}
