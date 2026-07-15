import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'identity_store.dart';
import 'token_store.dart';

/// What identity auto-detection found. These identities are persisted to
/// [IdentityStore] only when `detectSelf` is called with `persist: true`.
class IdentityDetectionResult {
  const IdentityDetectionResult({
    required this.githubLogins,
    required this.adoNames,
  });

  final Set<String> githubLogins;
  final Set<String> adoNames;

  bool get isEmpty => githubLogins.isEmpty && adoNames.isEmpty;
}

/// Detects the current user's identity by asking each stored token who it
/// belongs to (GitHub `/user`, Azure DevOps profile), then populates
/// [IdentityStore] so the "You" badge and the inbox "Mine" filter work without
/// the user typing their usernames.
class IdentityService {
  IdentityService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  // ---- Pure, testable parsers ----------------------------------------------

  static String? parseGithubLogin(dynamic body) {
    if (body is! Map) return null;
    final login = body['login'];
    return login is String && login.trim().isNotEmpty ? login.trim() : null;
  }

  static String? parseAdoName(dynamic body) {
    if (body is! Map) return null;
    final name = body['displayName'];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  // ---- Detection -----------------------------------------------------------

  /// Queries every stored token for its owning identity.
  ///
  /// When [persist] is true (default) the result is written to [IdentityStore]
  /// ([merge] unions with existing values; otherwise it replaces them). When
  /// [persist] is false the identities are only returned (e.g. to preview in a
  /// form). Per-token failures are isolated and never throw.
  static Future<IdentityDetectionResult> detectSelf({
    http.Client? client,
    bool merge = true,
    bool persist = true,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final githubTokens = await TokenStore.getTokensForProvider(
        TokenStore.providerGithub,
      );
      final adoTokens = await TokenStore.getTokensForProvider(
        TokenStore.providerAdo,
      );

      // Query every token concurrently so one slow or unreachable token can't
      // stall the others (each lookup carries its own timeout).
      final githubFuture = Future.wait(
        githubTokens.map((token) => _detectGithub(httpClient, token.id)),
      );
      final adoFuture = Future.wait(
        adoTokens.map((token) => _detectAdo(httpClient, token.id)),
      );
      final githubResults = await githubFuture;
      final adoResults = await adoFuture;

      final githubLogins = <String>{for (final login in githubResults) ?login};
      final adoNames = <String>{for (final name in adoResults) ?name};

      if (persist) {
        if (merge) {
          final existingGithub = await IdentityStore.selfGithubLogins();
          final existingAdo = await IdentityStore.selfAdoNames();
          await IdentityStore.setSelfGithubLogins({
            ...existingGithub,
            ...githubLogins,
          });
          await IdentityStore.setSelfAdoNames({...existingAdo, ...adoNames});
        } else {
          await IdentityStore.setSelfGithubLogins(githubLogins);
          await IdentityStore.setSelfAdoNames(adoNames);
        }
      }

      return IdentityDetectionResult(
        githubLogins: githubLogins,
        adoNames: adoNames,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<String?> _detectGithub(
    http.Client client,
    String tokenId,
  ) async {
    try {
      final secret = (await TokenStore.getSecret(tokenId))?.trim();
      if (secret == null || secret.isEmpty) return null;
      final response = await client
          .get(
            Uri.https('api.github.com', '/user'),
            headers: {
              'Authorization': 'Bearer $secret',
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      return parseGithubLogin(jsonDecode(response.body));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IdentityService: GitHub token detection failed: $e');
      }
      return null;
    }
  }

  static Future<String?> _detectAdo(http.Client client, String tokenId) async {
    try {
      final secret = (await TokenStore.getSecret(tokenId))?.trim();
      if (secret == null || secret.isEmpty) return null;
      final response = await client
          .get(
            Uri.https(
              'app.vssps.visualstudio.com',
              '/_apis/profile/profiles/me',
              {'api-version': '6.0'},
            ),
            headers: {
              'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      return parseAdoName(jsonDecode(response.body));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IdentityService: ADO token detection failed: $e');
      }
      return null;
    }
  }
}
