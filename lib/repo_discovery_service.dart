import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_store.dart';

/// A repository discovered via a token's API listing.
class DiscoveredRepo {
  const DiscoveredRepo({
    required this.key,
    required this.display,
    required this.repo,
  });

  /// Stable, case-insensitive uniqueness key (matches the keys built for
  /// already-monitored repos).
  final String key;

  /// Human-readable label shown in the list.
  final String display;

  /// The repo map to persist (without `tokenId`).
  final Map<String, String> repo;
}

/// Result of a discovery fetch.
class RepoFetchResult {
  const RepoFetchResult({required this.repos, required this.truncated});

  final List<DiscoveredRepo> repos;

  /// True when the provider had more results than were fetched (paging cap).
  final bool truncated;
}

/// Fetches and parses the repositories a token can see, for both the manual
/// import UI and the background auto-add pass.
class RepoDiscoveryService {
  RepoDiscoveryService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Safety cap on paged GitHub requests (100 repos/page, so up to ~5000 repos)
  /// so a pathologically large account can't spin forever.
  static const int _maxRepoPages = 50;

  static String githubKey(String owner, String name) =>
      'github:${owner.toLowerCase()}/${name.toLowerCase()}';

  static String adoKey(String organization, String project, String name) =>
      'ado:${organization.toLowerCase()}/${project.toLowerCase()}/'
      '${name.toLowerCase()}';

  /// Parses a GitHub `/repos` list response into discovered repos.
  static List<DiscoveredRepo> parseGithubRepos(List<dynamic> data) {
    final result = <DiscoveredRepo>[];
    for (final item in data) {
      if (item is! Map) continue;
      final ownerMap = item['owner'];
      if (ownerMap is! Map) continue;
      final owner = ownerMap['login'] as String?;
      final name = item['name'] as String?;
      if (owner == null || name == null) continue;
      result.add(
        DiscoveredRepo(
          key: githubKey(owner, name),
          display: '$owner/$name',
          repo: {'owner': owner, 'repoName': name},
        ),
      );
    }
    return result;
  }

  /// Parses an Azure DevOps repositories list response into discovered repos.
  static List<DiscoveredRepo> parseAdoRepos(
    String organization,
    List<dynamic> data,
  ) {
    final result = <DiscoveredRepo>[];
    for (final item in data) {
      if (item is! Map) continue;
      final name = item['name'] as String?;
      final projectMap = item['project'];
      if (projectMap is! Map) continue;
      final project = projectMap['name'] as String?;
      if (name == null || project == null) continue;
      result.add(
        DiscoveredRepo(
          key: adoKey(organization, project, name),
          display: '$project/$name',
          repo: {
            'organization': organization,
            'project': project,
            'repoName': name,
          },
        ),
      );
    }
    return result;
  }

  /// Fetches repositories visible to [secret] for the given [provider].
  ///
  /// For GitHub, a blank [org] lists everything the token can access
  /// (`/user/repos`); a non-blank [org] tries `/orgs/{org}/repos` and, if that
  /// scope is a personal account (404), falls back to `/user/repos` filtered by
  /// owner. For Azure DevOps, [org] is required.
  ///
  /// Provide [client] to reuse a connection (and in tests); when omitted a
  /// client is created and closed internally.
  static Future<RepoFetchResult> fetch({
    required String provider,
    required String secret,
    required String org,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      if (provider == TokenStore.providerGithub) {
        return await _fetchGithub(httpClient, secret, org);
      }
      return await _fetchAdo(httpClient, secret, org);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<RepoFetchResult> _fetchGithub(
    http.Client client,
    String secret,
    String org,
  ) async {
    if (org.isEmpty) {
      return (await _fetchGithubPaged(
        client,
        secret,
        'https://api.github.com/user/repos',
        allow404: false,
      ))!;
    }

    // Scoped: try the org endpoint, then fall back to the user's repos filtered
    // by owner (handles a personal-account scope, where /orgs/{scope} is 404).
    final orgResult = await _fetchGithubPaged(
      client,
      secret,
      'https://api.github.com/orgs/$org/repos',
      allow404: true,
    );
    if (orgResult != null) return orgResult;

    final userResult = (await _fetchGithubPaged(
      client,
      secret,
      'https://api.github.com/user/repos',
      allow404: false,
    ))!;
    final needle = org.toLowerCase();
    final filtered = userResult.repos
        .where((r) => (r.repo['owner'] ?? '').toLowerCase() == needle)
        .toList();
    return RepoFetchResult(repos: filtered, truncated: userResult.truncated);
  }

  /// Fetches a paginated GitHub repos list. Returns null when [allow404] is set
  /// and the first page 404s (so the caller can fall back).
  static Future<RepoFetchResult?> _fetchGithubPaged(
    http.Client client,
    String secret,
    String base, {
    required bool allow404,
  }) async {
    final all = <DiscoveredRepo>[];
    var truncated = false;
    // Page by following GitHub's `Link` header (rel="next"), starting from the
    // first page, with a generous safety cap. This fully pages accounts that
    // have more repos than the old fixed 10-page (1000-repo) limit.
    String? next = '$base?per_page=100';
    final visited = <String>{};
    var pages = 0;
    while (next != null) {
      // Stop (as truncated) at the safety cap or if a link repeats — the latter
      // guards against a server returning a self-referential `next`.
      if (pages >= _maxRepoPages || !visited.add(next)) {
        truncated = true;
        break;
      }
      pages++;
      final uri = Uri.parse(next);
      final response = await client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $secret',
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 404 && allow404 && pages == 1) {
        return null;
      }
      if (response.statusCode != 200) {
        throw Exception('GitHub returned status ${response.statusCode}');
      }
      final body = jsonDecode(response.body);
      if (body is! List || body.isEmpty) break;
      all.addAll(parseGithubRepos(body));
      // Follow the server's rel="next" link; its absence means the last page.
      // A present-but-rejected next (untrusted host / unparseable) marks the
      // result truncated so the UI warns that repos were omitted.
      final link = _nextLink(response.headers['link']);
      if (link.rejected) truncated = true;
      next = link.url;
    }
    return RepoFetchResult(repos: all, truncated: truncated);
  }

  /// Extracts the `rel="next"` URL from a GitHub `Link` response header. Returns
  /// `url == null` when there is no next page (or no/blank header). The header
  /// looks like `<https://api.github.com/...&page=2>; rel="next", <...>`.
  ///
  /// Only same-origin `https://api.github.com` URLs are followed; a next link to
  /// any other host/scheme (or one that won't parse) is rejected — `url` is null
  /// and `rejected` is true — so a hostile or proxying response can't redirect
  /// the token-bearing request to another host, and the caller can surface that
  /// pages were omitted.
  static ({String? url, bool rejected}) _nextLink(String? linkHeader) {
    if (linkHeader == null || linkHeader.isEmpty) {
      return (url: null, rejected: false);
    }
    for (final part in linkHeader.split(',')) {
      final segments = part.split(';');
      if (segments.length < 2) continue;
      final urlMatch = RegExp(r'<([^>]+)>').firstMatch(segments[0]);
      if (urlMatch == null) continue;
      final isNext = segments.skip(1).any((s) => s.contains('rel="next"'));
      if (!isNext) continue;
      final url = urlMatch.group(1)!;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'api.github.com') {
        return (url: null, rejected: true);
      }
      return (url: url, rejected: false);
    }
    return (url: null, rejected: false);
  }

  static Future<RepoFetchResult> _fetchAdo(
    http.Client client,
    String secret,
    String org,
  ) async {
    final uri = Uri.parse(
      'https://dev.azure.com/$org/_apis/git/repositories?api-version=6.0',
    );
    final response = await client
        .get(
          uri,
          headers: {
            'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
          },
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Azure DevOps returned status ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    final value = body is Map ? body['value'] : body;
    if (value is! List) {
      return const RepoFetchResult(repos: [], truncated: false);
    }
    return RepoFetchResult(repos: parseAdoRepos(org, value), truncated: false);
  }
}
