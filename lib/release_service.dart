import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'repo_detail_service.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// A published release, tagged with its repo, for the cross-repo "what shipped"
/// digest.
class ReleaseItem {
  const ReleaseItem({
    required this.repoKey,
    required this.repoDisplay,
    required this.tag,
    this.name,
    this.author,
    this.publishedAt,
    this.url,
  });

  final String repoKey;
  final String repoDisplay;
  final String tag;
  final String? name;
  final String? author;
  final DateTime? publishedAt;
  final String? url;
}

/// Open-vulnerability (Dependabot alert) counts for a repo, by severity.
class RepoSecurity {
  const RepoSecurity({
    required this.repoKey,
    required this.repoDisplay,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
    this.capped = false,
  });

  final String repoKey;
  final String repoDisplay;
  final int critical;
  final int high;
  final int medium;
  final int low;

  /// True when the alerts page was full, so counts are a floor (there may be
  /// more open alerts than shown).
  final bool capped;

  int get total => critical + high + medium + low;

  bool get isEmpty => total == 0;
}

/// The cross-repo release + security snapshot, with source-health signals so
/// the UI can tell "nothing shipped / all clear" apart from failed fetches.
class ReleaseSecurityResult {
  const ReleaseSecurityResult({
    this.releases = const [],
    this.security = const [],
    this.releasesFailedRepos = 0,
    this.securityUnavailableRepos = 0,
  });

  final List<ReleaseItem> releases;
  final List<RepoSecurity> security;

  /// GitHub repos whose releases fetch failed (auth/network/malformed).
  final int releasesFailedRepos;

  /// GitHub repos whose Dependabot alerts weren't readable (commonly 403 for
  /// repos the user doesn't administer — expected for watched OSS, not an
  /// error). Surfaced so the security section can explain partial coverage.
  final int securityUnavailableRepos;
}

/// Pure roll-ups for the security section.
class SecurityStats {
  const SecurityStats._();

  /// Repos with open alerts, worst-severity first (a single critical outranks
  /// any number of highs, etc.), then by display name.
  static List<RepoSecurity> rankRepos(Iterable<RepoSecurity> repos) {
    final result = repos.where((r) => !r.isEmpty).toList();
    result.sort((a, b) {
      // Compare severities in order so a strictly-worse severity always wins.
      if (a.critical != b.critical) return b.critical.compareTo(a.critical);
      if (a.high != b.high) return b.high.compareTo(a.high);
      if (a.medium != b.medium) return b.medium.compareTo(a.medium);
      if (a.low != b.low) return b.low.compareTo(a.low);
      return a.repoDisplay.toLowerCase().compareTo(b.repoDisplay.toLowerCase());
    });
    return result;
  }
}

/// Fetches recent releases and open Dependabot alerts across the monitored
/// GitHub repos, so the "Releases & security" insight can answer "what shipped
/// lately" and "what's newly vulnerable".
///
/// GitHub-only: Azure DevOps has no releases-list / Dependabot equivalent here.
/// Releases use the public releases API (works for any watched repo); Dependabot
/// alerts are owner-scoped, so repos the user doesn't administer typically 403
/// — that's counted as "unavailable", not a failure. Parsers are pure static
/// methods for unit-testing; [computeAll] wires the network fetch, mirroring
/// [IssueService].
class ReleaseService {
  ReleaseService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Only releases published within this window are surfaced in the digest.
  static const Duration releaseWindow = Duration(days: 90);

  static const int _releasePageSize = 30;
  static const int _alertPageSize = 100;

  // ---- Pure parsers --------------------------------------------------------

  /// Normalizes a GitHub `/releases` list into [ReleaseItem]s tagged with the
  /// repo, keeping only releases published within [window] of [now]. Reuses the
  /// shared release normalizer, then filters/attaches identity.
  static List<ReleaseItem> releasesFromGithub(
    dynamic body, {
    required String repoKey,
    required String repoDisplay,
    required DateTime now,
    Duration window = releaseWindow,
  }) {
    if (body is! List) return const [];
    final cutoff = now.subtract(window);
    final result = <ReleaseItem>[];
    for (final release in RepoDetailService.parseGithubReleases(body)) {
      final published = release.publishedAt;
      // Drop drafts/undated and anything older than the window.
      if (published == null || published.isBefore(cutoff)) continue;
      result.add(
        ReleaseItem(
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          tag: release.tag,
          name: release.name,
          author: release.author,
          publishedAt: published,
          url: release.url,
        ),
      );
    }
    return result;
  }

  /// Counts open Dependabot alerts by severity from a GitHub
  /// `/dependabot/alerts` list. Only `state == open` alerts are counted; the
  /// severity comes from `security_advisory.severity` (falling back to
  /// `security_vulnerability.severity`). Returns null when the body isn't a
  /// list (e.g. a 403/404 object), so the caller can mark it unavailable.
  static RepoSecurity? securityFromGithubAlerts(
    dynamic body, {
    required String repoKey,
    required String repoDisplay,
  }) {
    if (body is! List) return null;
    var critical = 0, high = 0, medium = 0, low = 0;
    for (final alert in body) {
      if (alert is! Map) continue;
      final state = alert['state'];
      // Require an explicit "open" state (a missing/non-string state isn't
      // assumed open).
      if (state is! String || state.toLowerCase() != 'open') continue;
      switch (_severityOf(alert)) {
        case 'critical':
          critical++;
        case 'high':
          high++;
        case 'medium':
          medium++;
        case 'low':
          low++;
      }
    }
    return RepoSecurity(
      repoKey: repoKey,
      repoDisplay: repoDisplay,
      critical: critical,
      high: high,
      medium: medium,
      low: low,
      capped: body.length >= _alertPageSize,
    );
  }

  static String? _severityOf(Map alert) {
    final advisory = alert['security_advisory'];
    final fromAdvisory = advisory is Map ? advisory['severity'] : null;
    if (fromAdvisory is String) return fromAdvisory.toLowerCase();
    final vuln = alert['security_vulnerability'];
    final fromVuln = vuln is Map ? vuln['severity'] : null;
    if (fromVuln is String) return fromVuln.toLowerCase();
    return null;
  }

  static String? _str(Map map, String key) {
    final v = map[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// All releases sorted newest published first (nulls last), across repos.
  static List<ReleaseItem> sortReleases(List<ReleaseItem> releases) {
    final sorted = [...releases];
    sorted.sort((a, b) {
      final ap = a.publishedAt;
      final bp = b.publishedAt;
      if (ap == null && bp == null) {
        return a.repoDisplay.toLowerCase().compareTo(
          b.repoDisplay.toLowerCase(),
        );
      }
      if (ap == null) return 1;
      if (bp == null) return -1;
      return bp.compareTo(ap);
    });
    return sorted;
  }

  // ---- Network -------------------------------------------------------------

  /// Fetches releases + Dependabot alerts for every monitored GitHub repo.
  /// Never throws — top-level setup failures return an empty result. Bounded to
  /// [concurrency] repos in flight (each repo does its two GETs sequentially).
  static Future<ReleaseSecurityResult> computeAll({
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

      final tasks = <Future<_RepoResult> Function()>[];
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
          setupFailed++;
        }
      }

      final results = await _runBounded(tasks, concurrency);
      final releases = <ReleaseItem>[];
      final security = <RepoSecurity>[];
      var releasesFailed = setupFailed;
      var securityUnavailable = 0;
      for (final r in results) {
        if (r.releases == null) {
          releasesFailed++;
        } else {
          releases.addAll(r.releases!);
        }
        if (r.security == null) {
          securityUnavailable++;
        } else if (!r.security!.isEmpty) {
          security.add(r.security!);
        }
      }
      return ReleaseSecurityResult(
        releases: sortReleases(releases),
        security: SecurityStats.rankRepos(security),
        releasesFailedRepos: releasesFailed,
        securityUnavailableRepos: securityUnavailable,
      );
    } catch (_) {
      return const ReleaseSecurityResult();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<_RepoResult> _fetchGithub(
    http.Client httpClient, {
    required String owner,
    required String name,
    required String repoKey,
    String? tokenId,
    required DateTime now,
  }) async {
    String? secret;
    try {
      secret = (await TokenStore.resolveGithubSecret(
        owner,
        tokenId: tokenId,
      ))?.trim();
    } catch (_) {
      // Isolate a token-resolution failure to this repo (both sources counted
      // unavailable) rather than aborting the whole batch.
      return const _RepoResult(releases: null, security: null);
    }
    if (secret == null || secret.isEmpty) {
      return const _RepoResult(releases: null, security: null);
    }
    final headers = {
      'Authorization': 'Bearer $secret',
      'Accept': 'application/vnd.github+json',
    };
    final display = '$owner/$name';

    List<ReleaseItem>? releases;
    try {
      final response = await httpClient
          .get(
            Uri.https('api.github.com', '/repos/$owner/$name/releases', {
              'per_page': '$_releasePageSize',
            }),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // A 200 whose body isn't a list is malformed — treat as a failure
        // (null) rather than a successful empty result.
        if (decoded is List) {
          releases = releasesFromGithub(
            decoded,
            repoKey: repoKey,
            repoDisplay: display,
            now: now,
          );
        }
      }
    } catch (_) {
      releases = null;
    }

    RepoSecurity? security;
    try {
      final response = await httpClient
          .get(
            Uri.https(
              'api.github.com',
              '/repos/$owner/$name/dependabot/alerts',
              {'state': 'open', 'per_page': '$_alertPageSize'},
            ),
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        security = securityFromGithubAlerts(
          jsonDecode(response.body),
          repoKey: repoKey,
          repoDisplay: display,
        );
      }
      // Any non-200 (403 no access / 404 alerts disabled) → unavailable (null).
    } catch (_) {
      security = null;
    }

    return _RepoResult(releases: releases, security: security);
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

/// One repo's fetch outcome. A null field means that source failed / was
/// unavailable for the repo (distinct from a successful empty result).
class _RepoResult {
  const _RepoResult({required this.releases, required this.security});
  final List<ReleaseItem>? releases;
  final RepoSecurity? security;
}
