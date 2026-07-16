import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'identity_service.dart';
import 'token_store.dart';

/// The outcome of a token health check.
enum TokenHealth {
  /// The provider accepted the token and returned an account.
  valid,

  /// The provider rejected the token (invalid, expired, or missing scopes).
  invalid,

  /// The check could not be completed (network error, unexpected status).
  error,
}

/// The result of verifying a single token against its provider.
class TokenCheck {
  const TokenCheck(this.health, {this.account, this.message});

  final TokenHealth health;

  /// The signed-in account (GitHub login / Azure DevOps display name) when the
  /// token is [TokenHealth.valid]; otherwise null.
  final String? account;

  /// A human-readable explanation when the token is not valid.
  final String? message;

  bool get isValid => health == TokenHealth.valid;
}

/// Actively verifies whether a stored token still authenticates, reusing the
/// same endpoints as identity detection (GitHub `/user`, Azure DevOps profile).
/// The mapping from HTTP status to [TokenCheck] is pure and testable.
class TokenHealthService {
  TokenHealthService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  // ---- Pure, testable status mappers ---------------------------------------

  /// Maps a GitHub `/user` response to a [TokenCheck]. Verifying against
  /// `/user` proves the token authenticates and reveals the account, but not
  /// that it holds the repo/PR scopes the app uses — so success is framed as
  /// "authenticated", not a full capability check.
  static TokenCheck githubResult(int status, dynamic body) {
    switch (status) {
      case 200:
        final login = IdentityService.parseGithubLogin(body);
        if (login == null || login.isEmpty) {
          // A 200 without a parseable account is not a real /user response
          // (e.g. a redirect landing page), so don't claim success.
          return const TokenCheck(
            TokenHealth.error,
            message: 'Unexpected response from GitHub.',
          );
        }
        return TokenCheck(TokenHealth.valid, account: login);
      case 401:
        return const TokenCheck(
          TokenHealth.invalid,
          message: 'Authentication failed — the token is invalid or expired.',
        );
      case 403:
        // 403 is ambiguous (rate limiting, SSO/policy) and doesn't prove the
        // token itself is bad, so treat it as inconclusive rather than invalid.
        return const TokenCheck(
          TokenHealth.error,
          message:
              'GitHub denied the request — it may be rate-limited or '
              'restricted by org policy.',
        );
      default:
        return TokenCheck(
          TokenHealth.error,
          message: 'GitHub returned HTTP $status.',
        );
    }
  }

  /// Maps an Azure DevOps profile response to a [TokenCheck]. A bad or expired
  /// PAT typically yields a 203/302 (a sign-in page) rather than a clean 401.
  /// Success proves authentication and the Profile scope, not the app's
  /// operational scopes.
  static TokenCheck adoResult(int status, dynamic body) {
    switch (status) {
      case 200:
        final name = IdentityService.parseAdoName(body);
        if (name == null || name.isEmpty) {
          return const TokenCheck(
            TokenHealth.error,
            message: 'Unexpected response from Azure DevOps.',
          );
        }
        return TokenCheck(TokenHealth.valid, account: name);
      case 203:
      case 302:
      case 401:
        return const TokenCheck(
          TokenHealth.invalid,
          message:
              'Authentication was not accepted — the token may be invalid, '
              'expired, or missing the Profile scope.',
        );
      default:
        return TokenCheck(
          TokenHealth.error,
          message: 'Azure DevOps returned HTTP $status.',
        );
    }
  }

  // ---- Checking ------------------------------------------------------------

  /// Verifies [token] by asking its provider who it belongs to. Never throws —
  /// network failures resolve to [TokenHealth.error].
  static Future<TokenCheck> check(
    TokenInfo token, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final secret = (await TokenStore.getSecret(token.id))?.trim();
      if (secret == null || secret.isEmpty) {
        return const TokenCheck(
          TokenHealth.error,
          message: 'No token secret stored.',
        );
      }
      if (token.provider == TokenStore.providerAdo) {
        final response = await _send(
          httpClient,
          Uri.https(
            'app.vssps.visualstudio.com',
            '/_apis/profile/profiles/me',
            {'api-version': '6.0'},
          ),
          {'Authorization': 'Basic ${base64Encode(utf8.encode(':$secret'))}'},
        );
        return adoResult(response.statusCode, _tryDecode(response.body));
      }
      final response = await _send(
        httpClient,
        Uri.https('api.github.com', '/user'),
        {
          'Authorization': 'Bearer $secret',
          'Accept': 'application/vnd.github+json',
        },
      );
      return githubResult(response.statusCode, _tryDecode(response.body));
    } on TimeoutException {
      return const TokenCheck(
        TokenHealth.error,
        message: 'The request timed out.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TokenHealthService: check failed: $e');
      }
      return const TokenCheck(
        TokenHealth.error,
        message: 'Could not reach the provider.',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Sends a GET without following redirects, so an auth failure that redirects
  /// to a sign-in page is seen as its real 302/203 status rather than being
  /// followed to a misleading 200 HTML page.
  static Future<http.Response> _send(
    http.Client client,
    Uri url,
    Map<String, String> headers,
  ) async {
    final request = http.Request('GET', url)
      ..followRedirects = false
      ..headers.addAll(headers);
    // Bound the whole exchange, not just the send, so a stalled response body
    // can't hang the check indefinitely.
    Future<http.Response> exchange() async {
      final streamed = await client.send(request);
      return http.Response.fromStream(streamed);
    }

    return exchange().timeout(_requestTimeout);
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
