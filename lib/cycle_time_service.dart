import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cycle_time.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// Fetches recently-merged pull requests for the monitored repos and normalizes
/// them into [MergedPrSample]s, so the review-time / cycle-time trends can
/// accumulate how long PRs take to get a first review and to merge.
///
/// This is a separate pass from the activity fetch (which only sees open PRs).
/// The parsers are pure static methods for unit-testing; [computeAll] wires the
/// network fetch + monitored-repo iteration, mirroring [ActivityService].
class CycleTimeService {
  CycleTimeService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// How many recently-merged PRs to request per repo per sync. Merged PRs are
  /// accumulated across syncs (deduped by `prKey`), so history fills in over
  /// time: this is a per-sync sample, not the complete merge log.
  ///
  /// KNOWN LIMITATION: a single page ordered by `UPDATED_AT` can undersample a
  /// repo that merges more than [_pageSize] PRs between syncs (or whose old PRs
  /// get freshly commented). The medians are then computed over an incomplete
  /// (but not incorrect) sample. A merged-date-ranged, high-water-mark backfill
  /// that paginates to completion is a planned follow-up; for now the
  /// accumulate-across-syncs model keeps each sync cheap while coverage grows.
  static const int _pageSize = 50;

  /// The GraphQL query for a repo's most-recently-updated merged PRs, with each
  /// PR's reviews (submission time + state + author) so we can derive the time
  /// of the first *submitted* review.
  static const String mergedPullsQuery =
      r'query($owner:String!,$name:String!,$first:Int!){'
      r'repository(owner:$owner,name:$name){'
      r'pullRequests(states:MERGED,first:$first,orderBy:{field:UPDATED_AT,direction:DESC}){'
      r'nodes{number title url createdAt mergedAt author{login} '
      r'reviews(first:50){nodes{submittedAt state author{login}}}}'
      r'}}}';

  // ---- Pure parsers --------------------------------------------------------

  /// Normalizes a GitHub GraphQL merged-PR response into [MergedPrSample]s.
  /// `firstReviewAt` is the earliest *submitted* review (excluding pending
  /// drafts, the PR author's own reviews, and any review submitted after the
  /// merge) so a PR author's own comment-review or a post-merge review doesn't
  /// count as the first review. PRs missing a number or either timestamp are
  /// skipped.
  static List<MergedPrSample> parseGithubGraphqlMergedPulls(
    dynamic body, {
    required String repoKey,
    required String repoDisplay,
  }) {
    final nodes = _graphqlPullNodes(body);
    if (nodes == null) return const [];
    final result = <MergedPrSample>[];
    for (final pr in nodes) {
      if (pr is! Map) continue;
      final number = pr['number'];
      if (number is! int) continue;
      final createdAt = _parseDate(pr['createdAt']);
      final mergedAt = _parseDate(pr['mergedAt']);
      if (createdAt == null || mergedAt == null) continue;
      final prAuthor = _nested(pr['author'], 'login');
      result.add(
        MergedPrSample(
          provider: TokenStore.providerGithub,
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          prKey: '$repoKey:$number',
          createdAt: createdAt,
          mergedAt: mergedAt,
          firstReviewAt: _firstReviewAt(
            pr['reviews'],
            excludeLogin: prAuthor,
            notAfter: mergedAt,
          ),
          title: _str(pr, 'title'),
          author: prAuthor,
          url: _str(pr, 'url'),
        ),
      );
    }
    return result;
  }

  /// Normalizes an Azure DevOps completed-PR list into [MergedPrSample]s. ADO's
  /// PR API doesn't cheaply expose a first-review timestamp, so `firstReviewAt`
  /// is left null (time-to-merge only) for the MVP. Only PRs whose merge status
  /// is `completed` with both a creation and close date are kept.
  static List<MergedPrSample> parseAdoMergedPulls(
    dynamic body, {
    required String repoKey,
    required String repoDisplay,
    required String organization,
    required String project,
    required String name,
  }) {
    final value = body is Map ? body['value'] : body;
    if (value is! List) return const [];
    final result = <MergedPrSample>[];
    for (final pr in value) {
      if (pr is! Map) continue;
      final status = pr['status'];
      if (status is! String || status.toLowerCase() != 'completed') continue;
      final id = pr['pullRequestId'];
      if (id == null) continue;
      final createdAt = _parseDate(pr['creationDate']);
      final mergedAt = _parseDate(pr['closedDate']);
      if (createdAt == null || mergedAt == null) continue;
      final author = _nested(pr['createdBy'], 'displayName');
      result.add(
        MergedPrSample(
          provider: TokenStore.providerAdo,
          repoKey: repoKey,
          repoDisplay: repoDisplay,
          prKey: '$repoKey:$id',
          createdAt: createdAt,
          mergedAt: mergedAt,
          title: _str(pr, 'title'),
          author: author,
          url:
              'https://dev.azure.com/$organization/$project/_git/$name/'
              'pullrequest/$id',
        ),
      );
    }
    return result;
  }

  /// The earliest *submitted* review time in a GraphQL `reviews` connection,
  /// ignoring pending drafts (null `submittedAt` / `state == PENDING`), reviews
  /// authored by [excludeLogin] (typically the PR author), and — when
  /// [notAfter] is given — reviews submitted after that instant (e.g. after the
  /// merge). Null when there are no qualifying reviews.
  static DateTime? _firstReviewAt(
    dynamic reviews, {
    String? excludeLogin,
    DateTime? notAfter,
  }) {
    final nodes = reviews is Map ? reviews['nodes'] : null;
    if (nodes is! List) return null;
    // GitHub logins are case-insensitive; normalize both sides so the PR
    // author's own review is excluded regardless of casing/whitespace.
    final exclude = excludeLogin?.trim().toLowerCase();
    DateTime? earliest;
    for (final review in nodes) {
      if (review is! Map) continue;
      final state = review['state'];
      if (state is String && state.toUpperCase() == 'PENDING') continue;
      final login = _nested(review['author'], 'login')?.trim().toLowerCase();
      if (exclude != null && login == exclude) continue;
      final at = _parseDate(review['submittedAt']);
      if (at == null) continue;
      if (notAfter != null && at.isAfter(notAfter)) continue;
      if (earliest == null || at.isBefore(earliest)) earliest = at;
    }
    return earliest;
  }

  static List<dynamic>? _graphqlPullNodes(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final repository = data is Map ? data['repository'] : null;
    final pullRequests = repository is Map ? repository['pullRequests'] : null;
    final nodes = pullRequests is Map ? pullRequests['nodes'] : null;
    return nodes is List ? nodes : null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String? _str(Map map, String key) {
    final v = map[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? _nested(dynamic map, String key) {
    if (map is! Map) return null;
    final v = map[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  // ---- Network -------------------------------------------------------------

  /// Fetches recently-merged PRs for every monitored repo, returning all
  /// samples. Never throws — a failed repo contributes no samples. Bounded to
  /// [concurrency] in-flight requests.
  static Future<List<MergedPrSample>> computeAll({
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

      final tasks = <Future<List<MergedPrSample>> Function()>[];

      for (final raw in githubRepos) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          final owner = _str(decoded, 'owner');
          final name = _str(decoded, 'repoName');
          if (owner == null || name == null) continue;
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
            ),
          );
        } catch (_) {
          // Skip malformed entries.
        }
      }

      for (final raw in adoRepos) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          final organization = _str(decoded, 'organization');
          final project = _str(decoded, 'project');
          final name = _str(decoded, 'repoName');
          if (organization == null || project == null || name == null) {
            continue;
          }
          final repoKey = RepoDiscoveryService.adoKey(
            organization,
            project,
            name,
          );
          if (onlyRepoKeys != null && !onlyRepoKeys.contains(repoKey)) continue;
          final tokenId = _str(decoded, 'tokenId');
          tasks.add(
            () => _fetchAdo(
              httpClient,
              organization: organization,
              project: project,
              name: name,
              repoKey: repoKey,
              tokenId: tokenId,
            ),
          );
        } catch (_) {
          // Skip malformed entries.
        }
      }

      final batches = await _runBounded(tasks, concurrency);
      return batches.expand((b) => b).toList();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<List<MergedPrSample>> _fetchGithub(
    http.Client httpClient, {
    required String owner,
    required String name,
    required String repoKey,
    String? tokenId,
  }) async {
    try {
      final secret = (await TokenStore.resolveGithubSecret(
        owner,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) return const [];
      final response = await httpClient
          .post(
            Uri.https('api.github.com', '/graphql'),
            headers: {
              'Authorization': 'Bearer $secret',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'query': mergedPullsQuery,
              'variables': {'owner': owner, 'name': name, 'first': _pageSize},
            }),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body);
      if (body is Map && body['errors'] != null) return const [];
      return parseGithubGraphqlMergedPulls(
        body,
        repoKey: repoKey,
        repoDisplay: '$owner/$name',
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<List<MergedPrSample>> _fetchAdo(
    http.Client httpClient, {
    required String organization,
    required String project,
    required String name,
    required String repoKey,
    String? tokenId,
  }) async {
    try {
      final secret = (await TokenStore.resolveAdoSecret(
        organization,
        tokenId: tokenId,
      ))?.trim();
      if (secret == null || secret.isEmpty) return const [];
      final response = await httpClient
          .get(
            Uri.https(
              'dev.azure.com',
              '/$organization/$project/_apis/git/repositories/$name/pullrequests',
              {
                'searchCriteria.status': 'completed',
                r'$top': '$_pageSize',
                'api-version': '6.0',
              },
            ),
            headers: {
              'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return const [];
      return parseAdoMergedPulls(
        jsonDecode(response.body),
        repoKey: repoKey,
        repoDisplay: '$organization/$project/$name',
        organization: organization,
        project: project,
        name: name,
      );
    } catch (_) {
      return const [];
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
