import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    this.isMine = false,
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

  /// True when the current user is the PR author or a requested reviewer.
  final bool isMine;
}

/// Computes a ranked, team-wide list of pull requests that need action across
/// all monitored repos: waiting on review, changes requested, or open a long
/// time. Items are optionally tagged as the current user's
/// (`AttentionItem.isMine`) when GitHub logins / ADO names are supplied, and
/// snoozed items are filtered out. CI-failing repos are surfaced on the Radar,
/// not here.
class AttentionService {
  AttentionService._();

  /// A PR open longer than this many days (with no pending review/changes) is
  /// surfaced as an "old open PR".
  static const int oldOpenPrDays = 7;
  static const Duration _requestTimeout = Duration(seconds: 20);

  /// GraphQL query for a repo's open PRs. `reviewDecision` is only populated
  /// when branch protection requires reviews, so `latestOpinionatedReviews`
  /// (each author's latest approve/changes-requested stance) is also queried to
  /// detect changes-requested on unprotected repos. The pending review requests
  /// drive "waiting on review" and self-assignment.
  static const String _openPullsQuery =
      r'query($owner:String!,$name:String!){'
      r'repository(owner:$owner,name:$name){'
      r'pullRequests(states:OPEN,first:100,orderBy:{field:UPDATED_AT,direction:DESC}){'
      r'nodes{number title url isDraft createdAt '
      r'author{login} reviewDecision '
      r'latestOpinionatedReviews(first:100){nodes{state}} '
      r'reviewRequests(first:20){totalCount '
      r'nodes{requestedReviewer{__typename ... on User{login}}}}}'
      r'}}}';

  // Category tiers; severity = tier * 1000 + age, so category always dominates
  // age in ranking while older items still sort first within a category.
  static const int _tierReviewRequested = 3;
  static const int _tierChangesRequested = 2;
  static const int _tierOldOpen = 1;
  static const int _tierError = 0;

  static int _severity(int tier, int? ageDays) =>
      tier * 1000 + (ageDays ?? 0).clamp(0, 999);

  // ---- Pure, testable rule helpers -----------------------------------------

  /// Builds attention items for a GitHub repo from its GraphQL open-PR nodes.
  /// The exact `reviewDecision` lets us surface changes-requested PRs (matching
  /// Azure DevOps), not just review-requested and old-open ones. A PR is
  /// "mine" when the current user authored it or is a requested reviewer.
  static List<AttentionItem> githubItems({
    required String repoDisplay,
    required List<dynamic> prs,
    required DateTime now,
    Set<String> selfGithubLogins = const {},
  }) {
    final self = selfGithubLogins.map((e) => e.trim().toLowerCase()).toSet();
    final items = <AttentionItem>[];
    for (final pr in prs) {
      if (pr is! Map) continue;
      if (pr['isDraft'] == true) continue;
      final number = pr['number'];
      if (number is! int) continue;
      final title = _stringValue(pr, 'title') ?? 'Untitled PR';
      final author = _nestedString(pr['author'], 'login') ?? 'unknown';
      final url = _stringValue(pr, 'url');
      final age = _ageDays(pr['createdAt'], now);
      final decision = _stringValue(pr, 'reviewDecision');
      // reviewDecision is null on repos without required reviews, so also
      // inspect each author's latest opinionated review. Supersession is
      // handled by GitHub: a later approval replaces an earlier change request.
      final changesRequested =
          decision == 'CHANGES_REQUESTED' ||
          _hasChangesRequestedReview(pr['latestOpinionatedReviews']);

      final reviewRequests = pr['reviewRequests'];
      final pendingCount =
          reviewRequests is Map && reviewRequests['totalCount'] is int
          ? reviewRequests['totalCount'] as int
          : 0;
      final reviewerLogins = _requestedReviewerLogins(reviewRequests);
      final mine =
          self.isNotEmpty &&
          (self.contains(author.trim().toLowerCase()) ||
              reviewerLogins.any(self.contains));

      final label = 'PR #$number';
      if (changesRequested) {
        items.add(
          _changesRequested(
            repoDisplay,
            label,
            title,
            author,
            age,
            url,
            isMine: mine,
          ),
        );
      } else if (decision == 'REVIEW_REQUIRED' || pendingCount > 0) {
        // A required review, or any pending review request (individual or
        // team), means the PR is still waiting on review.
        items.add(
          _reviewRequested(
            repoDisplay,
            label,
            title,
            author,
            age,
            url,
            isMine: mine,
          ),
        );
      } else if ((age ?? 0) > oldOpenPrDays) {
        items.add(
          _oldOpen(repoDisplay, label, title, author, age, url, isMine: mine),
        );
      }
    }
    return items;
  }

  /// Collects the lower-cased logins of individually requested reviewers from a
  /// GraphQL `reviewRequests` connection. Team review requests have no login
  /// and are ignored here (they still count toward the pending total).
  static Set<String> _requestedReviewerLogins(dynamic reviewRequests) {
    final logins = <String>{};
    final nodes = reviewRequests is Map ? reviewRequests['nodes'] : null;
    if (nodes is List) {
      for (final n in nodes) {
        if (n is! Map) continue;
        final login = _nestedString(n['requestedReviewer'], 'login');
        if (login != null) logins.add(login.trim().toLowerCase());
      }
    }
    return logins;
  }

  /// True when any author's latest opinionated review is CHANGES_REQUESTED.
  /// GitHub's `latestOpinionatedReviews` already collapses to each author's
  /// most recent approve/changes stance, so a later approval supersedes it.
  static bool _hasChangesRequestedReview(dynamic latestOpinionatedReviews) {
    final nodes = latestOpinionatedReviews is Map
        ? latestOpinionatedReviews['nodes']
        : null;
    if (nodes is! List) return false;
    for (final n in nodes) {
      if (n is Map && n['state'] == 'CHANGES_REQUESTED') return true;
    }
    return false;
  }

  /// Builds attention items for an Azure DevOps repo from its active PR list.
  static List<AttentionItem> adoItems({
    required String repoDisplay,
    required String organization,
    required String project,
    required String name,
    required List<dynamic> prs,
    required DateTime now,
    Set<String> selfAdoNames = const {},
  }) {
    final self = selfAdoNames.map((e) => e.trim().toLowerCase()).toSet();
    final items = <AttentionItem>[];
    for (final pr in prs) {
      if (pr is! Map) continue;
      if (pr['isDraft'] == true) continue;
      final id = pr['pullRequestId'];
      final title = _stringValue(pr, 'title') ?? 'Untitled PR';
      final author = _nestedString(pr['createdBy'], 'displayName') ?? 'unknown';
      final age = _ageDays(pr['creationDate'], now);
      final url = id == null
          ? null
          : 'https://dev.azure.com/$organization/$project/_git/$name/'
                'pullrequest/$id';

      // ADO reviewer votes: 10 approved, 5 approved-with-suggestions,
      // 0 no vote yet, -5 waiting for author, -10 rejected.
      final reviewers = pr['reviewers'];
      final votes = <dynamic>[];
      final reviewerNames = <String>{};
      if (reviewers is List) {
        for (final r in reviewers) {
          if (r is! Map) continue;
          votes.add(r['vote']);
          final dn = _stringValue(r, 'displayName');
          if (dn != null) reviewerNames.add(dn.trim().toLowerCase());
        }
      }
      final changesRequested = votes.any((v) => v is int && v < 0);
      final waitingOnReview = votes.any((v) => v == 0);
      final mine =
          self.isNotEmpty &&
          (self.contains(author.trim().toLowerCase()) ||
              reviewerNames.any(self.contains));

      if (changesRequested) {
        items.add(
          _changesRequested(
            repoDisplay,
            'PR #$id',
            title,
            author,
            age,
            url,
            isMine: mine,
          ),
        );
      } else if (waitingOnReview) {
        items.add(
          _reviewRequested(
            repoDisplay,
            'PR #$id',
            title,
            author,
            age,
            url,
            isMine: mine,
          ),
        );
      } else if ((age ?? 0) > oldOpenPrDays) {
        items.add(
          _oldOpen(
            repoDisplay,
            'PR #$id',
            title,
            author,
            age,
            url,
            isMine: mine,
          ),
        );
      }
    }
    return items;
  }

  static AttentionItem _reviewRequested(
    String repoDisplay,
    String prLabel,
    String title,
    String author,
    int? ageDays,
    String? url, {
    bool isMine = false,
  }) {
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
      isMine: isMine,
    );
  }

  static AttentionItem _changesRequested(
    String repoDisplay,
    String prLabel,
    String title,
    String author,
    int? ageDays,
    String? url, {
    bool isMine = false,
  }) {
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
      isMine: isMine,
    );
  }

  static AttentionItem _oldOpen(
    String repoDisplay,
    String prLabel,
    String title,
    String author,
    int? ageDays,
    String? url, {
    bool isMine = false,
  }) {
    return AttentionItem(
      id: 'oldOpenPr:$repoDisplay:$prLabel',
      category: 'oldOpenPr',
      severity: _severity(_tierOldOpen, ageDays),
      title: '$prLabel open for ${_ageText(ageDays)}',
      subtitle: '$repoDisplay · $title · by $author · no pending review',
      repoDisplay: repoDisplay,
      url: url,
      ageDays: ageDays,
      isMine: isMine,
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
      map is Map && map[key] is String ? map[key] as String : null;

  static String? _stringValue(Map map, String key) {
    final value = map[key];
    return value is String ? value : null;
  }

  /// Extracts `data.repository.pullRequests.nodes` from a GraphQL response, or
  /// null when the shape is invalid (distinguishing "no open PRs" from a failed
  /// or malformed response).
  static List<dynamic>? _graphqlPullNodes(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final repository = data is Map ? data['repository'] : null;
    final pullRequests = repository is Map ? repository['pullRequests'] : null;
    final nodes = pullRequests is Map ? pullRequests['nodes'] : null;
    return nodes is List ? nodes : null;
  }

  // ---- Fetching ------------------------------------------------------------

  static Future<List<AttentionItem>> computeAll({
    http.Client? client,
    int concurrency = 5,
    DateTime? now,
    Set<String> selfGithubLogins = const {},
    Set<String> selfAdoNames = const {},
    Set<String> snoozedIds = const {},
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
        tasks.add(
          () => _githubRepoItems(
            httpClient,
            owner,
            name,
            tokenId,
            effectiveNow,
            selfGithubLogins,
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
          () => _adoRepoItems(
            httpClient,
            organization,
            project,
            name,
            tokenId,
            effectiveNow,
            selfAdoNames,
          ),
        );
      }

      final grouped = await _runBounded(tasks, concurrency);
      final items = grouped
          .expand((e) => e)
          .where((item) => !snoozedIds.contains(item.id))
          .toList();

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

  static Future<List<AttentionItem>> _githubRepoItems(
    http.Client client,
    String owner,
    String name,
    String? tokenId,
    DateTime now,
    Set<String> selfGithubLogins,
  ) async {
    final repoDisplay = '$owner/$name';
    try {
      final secret = (await TokenStore.resolveGithubSecret(
        owner,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) {
        return [_errorItem(repoDisplay, 'No token set')];
      }
      final response = await client
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
      if (response.statusCode != 200) {
        return [
          _errorItem(repoDisplay, 'GitHub returned ${response.statusCode}'),
        ];
      }
      final body = jsonDecode(response.body);
      if (body is Map && body['errors'] != null) {
        return [_errorItem(repoDisplay, 'Could not load pull requests')];
      }
      final nodes = _graphqlPullNodes(body);
      if (nodes == null) {
        return [_errorItem(repoDisplay, 'Could not load pull requests')];
      }
      return githubItems(
        repoDisplay: repoDisplay,
        prs: nodes,
        now: now,
        selfGithubLogins: selfGithubLogins,
      );
    } catch (e) {
      debugPrint('AttentionService GitHub fetch failed for $repoDisplay: $e');
      return [_errorItem(repoDisplay, 'Could not load pull requests')];
    }
  }

  static Future<List<AttentionItem>> _adoRepoItems(
    http.Client client,
    String organization,
    String project,
    String name,
    String? tokenId,
    DateTime now,
    Set<String> selfAdoNames,
  ) async {
    final repoDisplay = '$organization/$project/$name';
    try {
      final secret = (await TokenStore.resolveAdoSecret(
        organization,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) {
        return [_errorItem(repoDisplay, 'No token set')];
      }
      final response = await client
          .get(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/git/repositories/$name/pullrequests',
              {'searchCriteria.status': 'active', 'api-version': '6.0'},
            ),
            headers: {
              'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return [
          _errorItem(
            repoDisplay,
            'Azure DevOps returned ${response.statusCode}',
          ),
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
        selfAdoNames: selfAdoNames,
      );
    } catch (e) {
      debugPrint('AttentionService ADO fetch failed for $repoDisplay: $e');
      return [_errorItem(repoDisplay, 'Could not load pull requests')];
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
