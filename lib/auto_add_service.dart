import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ignore_store.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// Adds newly-appearing repositories for tokens that have auto-add enabled.
class AutoAddService {
  AutoAddService._();

  /// Runs one auto-add pass. Returns the number of repositories added.
  ///
  /// Provide [client] to reuse a connection (and in tests).
  static Future<int> run({http.Client? client}) async {
    final autoTokens = (await TokenStore.getTokens())
        .where((t) => t.autoAdd)
        .toList();
    if (autoTokens.isEmpty) return 0;

    // Process scoped tokens before default (unscoped) ones so a scoped token
    // claims its repositories rather than a broad default token.
    autoTokens.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? 1 : -1;
    });

    // Fetch candidates OUTSIDE the storage lock (network I/O can be slow).
    final candidates = <({String provider, String key, String encoded})>[];
    final httpClient = client ?? http.Client();
    try {
      for (final token in autoTokens) {
        final secret = await TokenStore.getSecret(token.id);
        if (secret == null || secret.isEmpty) continue;

        final org = token.scope.trim();
        // Azure DevOps listing requires an organization scope.
        if (token.provider == TokenStore.providerAdo && org.isEmpty) continue;

        try {
          final result = await RepoDiscoveryService.fetch(
            provider: token.provider,
            secret: secret,
            org: org,
            client: httpClient,
          );
          for (final repo in result.repos) {
            final map = Map<String, String>.of(repo.repo);
            map['tokenId'] = token.id;
            candidates.add((
              provider: token.provider,
              key: repo.key,
              encoded: jsonEncode(map),
            ));
          }
        } catch (_) {
          // Skip this token for this pass; try again next cycle.
        }
      }
    } finally {
      if (client == null) httpClient.close();
    }

    if (candidates.isEmpty) return 0;

    // Persist under the shared lock, re-deriving existing keys AND the ignore
    // set from current storage inside the critical section, so a concurrent
    // "remove & ignore" (which uses the same lock) is respected — an ignored
    // repo is never re-added and no UI change is clobbered.
    return RepoStore.runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final github = List<String>.of(
        prefs.getStringList(RepoStore.githubKey) ?? const [],
      );
      final ado = List<String>.of(
        prefs.getStringList(RepoStore.adoKey) ?? const [],
      );
      final ignored = IgnoreStore.readFrom(prefs);
      final existing = _existingKeys(github, ado);
      var added = 0;
      for (final candidate in candidates) {
        if (ignored.contains(candidate.key)) continue;
        if (existing.contains(candidate.key)) continue;
        existing.add(candidate.key);
        if (candidate.provider == TokenStore.providerGithub) {
          github.add(candidate.encoded);
        } else {
          ado.add(candidate.encoded);
        }
        added++;
      }
      if (added > 0) {
        await prefs.setStringList(RepoStore.githubKey, github);
        await prefs.setStringList(RepoStore.adoKey, ado);
      }
      return added;
    });
  }

  static Set<String> _existingKeys(
    List<String> githubRepos,
    List<String> adoRepos,
  ) {
    final keys = <String>{};
    for (final raw in githubRepos) {
      try {
        final map = Map<String, String>.from(jsonDecode(raw) as Map);
        keys.add(
          RepoDiscoveryService.githubKey(
            map['owner'] ?? '',
            map['repoName'] ?? '',
          ),
        );
      } catch (_) {}
    }
    for (final raw in adoRepos) {
      try {
        final map = Map<String, String>.from(jsonDecode(raw) as Map);
        keys.add(
          RepoDiscoveryService.adoKey(
            map['organization'] ?? '',
            map['project'] ?? '',
            map['repoName'] ?? '',
          ),
        );
      } catch (_) {}
    }
    return keys;
  }
}
