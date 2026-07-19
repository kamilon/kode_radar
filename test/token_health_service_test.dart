import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/token_health_service.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  group('githubResult', () {
    test('200 -> valid with the resolved login', () {
      final check = TokenHealthService.githubResult(200, {'login': 'Octocat'});
      expect(check.health, TokenHealth.valid);
      expect(check.isValid, isTrue);
      expect(check.account, 'octocat');
    });

    test('200 without a parseable account -> error (e.g. a redirect page)', () {
      final check = TokenHealthService.githubResult(200, 'not-a-map');
      expect(check.health, TokenHealth.error);
      expect(check.account, isNull);
    });

    test('401 -> invalid; 403 -> inconclusive error (not "invalid")', () {
      expect(
        TokenHealthService.githubResult(401, null).health,
        TokenHealth.invalid,
      );
      final forbidden = TokenHealthService.githubResult(403, null);
      expect(forbidden.health, TokenHealth.error);
      expect(forbidden.message, contains('rate-limited'));
    });

    test('other statuses -> error carrying the code', () {
      final check = TokenHealthService.githubResult(500, null);
      expect(check.health, TokenHealth.error);
      expect(check.message, contains('500'));
    });
  });

  group('adoResult', () {
    test('200 -> valid with the resolved display name', () {
      final check = TokenHealthService.adoResult(200, {
        'displayName': 'Jane Doe',
      });
      expect(check.health, TokenHealth.valid);
      expect(check.account, 'Jane Doe');
    });

    test('203/302/401 -> invalid (a bad PAT often 203s to a sign-in page)', () {
      for (final status in [203, 302, 401]) {
        expect(
          TokenHealthService.adoResult(status, null).health,
          TokenHealth.invalid,
          reason: 'status $status',
        );
      }
    });

    test('200 without a parseable name -> error (e.g. a sign-in page)', () {
      final check = TokenHealthService.adoResult(200, '<html>sign in</html>');
      expect(check.health, TokenHealth.error);
    });

    test('other statuses -> error carrying the code', () {
      final check = TokenHealthService.adoResult(500, null);
      expect(check.health, TokenHealth.error);
      expect(check.message, contains('500'));
    });
  });

  group('check', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'GitHub token: hits /user with a Bearer scheme, no redirects',
      () async {
        final token = await TokenStore.addToken(
          provider: TokenStore.providerGithub,
          label: 'GH',
          scope: 'acme',
          secret: 'ghp_secret',
        );
        Uri? requested;
        String? authScheme;
        bool? followRedirects;
        final client = MockClient((request) async {
          requested = request.url;
          final auth = request.headers['authorization'] ?? '';
          authScheme = auth.split(' ').first;
          followRedirects = request.followRedirects;
          return http.Response(jsonEncode({'login': 'alice'}), 200);
        });

        final check = await TokenHealthService.check(token, client: client);
        expect(check.isValid, isTrue);
        expect(check.account, 'alice');
        expect(requested?.host, 'api.github.com');
        expect(requested?.path, '/user');
        expect(authScheme, 'Bearer');
        expect(followRedirects, isFalse);
      },
    );

    test('Azure DevOps token: hits the profile endpoint with Basic', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerAdo,
        label: 'ADO',
        scope: 'org',
        secret: 'pat_secret',
      );
      Uri? requested;
      String? authScheme;
      final client = MockClient((request) async {
        requested = request.url;
        authScheme = (request.headers['authorization'] ?? '').split(' ').first;
        return http.Response(jsonEncode({'displayName': 'Jane'}), 200);
      });

      final check = await TokenHealthService.check(token, client: client);
      expect(check.isValid, isTrue);
      expect(check.account, 'Jane');
      expect(requested?.host, 'app.vssps.visualstudio.com');
      expect(authScheme, 'Basic');
    });

    test('a rejected token surfaces invalid', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'GH',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final client = MockClient((_) async => http.Response('', 401));
      final check = await TokenHealthService.check(token, client: client);
      expect(check.health, TokenHealth.invalid);
    });

    test(
      'an ADO sign-in redirect (302) is reported invalid, not followed',
      () async {
        final token = await TokenStore.addToken(
          provider: TokenStore.providerAdo,
          label: 'ADO',
          scope: 'org',
          secret: 'pat_secret',
        );
        final client = MockClient(
          (_) async => http.Response('<html>sign in</html>', 302),
        );
        final check = await TokenHealthService.check(token, client: client);
        expect(check.health, TokenHealth.invalid);
      },
    );

    test('a network failure resolves to error, never throws', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'GH',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final client = MockClient((_) async => throw Exception('offline'));
      final check = await TokenHealthService.check(token, client: client);
      expect(check.health, TokenHealth.error);
    });

    test('captures the rate-limit budget from response headers', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'GH',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final reset = DateTime.utc(2026, 7, 15, 12, 41);
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'login': 'alice'}),
          200,
          headers: {
            'x-ratelimit-remaining': '4823',
            'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
          },
        ),
      );

      final check = await TokenHealthService.check(token, client: client);
      expect(check.rateLimit?.remaining, 4823);
      expect(check.rateLimit?.resetAt, reset);
    });

    test('a response without rate-limit headers leaves it null', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'GH',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'login': 'alice'}), 200),
      );
      final check = await TokenHealthService.check(token, client: client);
      expect(check.rateLimit, isNull);
    });

    test(
      'a reset without a remaining count is not treated as a budget',
      () async {
        final token = await TokenStore.addToken(
          provider: TokenStore.providerGithub,
          label: 'GH',
          scope: 'acme',
          secret: 'ghp_secret',
        );
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'login': 'alice'}),
            200,
            headers: {'x-ratelimit-reset': '1800000000'},
          ),
        );
        final check = await TokenHealthService.check(token, client: client);
        expect(check.rateLimit, isNull);
      },
    );

    test(
      'a malformed rate-limit reset does not corrupt an otherwise valid check',
      () async {
        final token = await TokenStore.addToken(
          provider: TokenStore.providerGithub,
          label: 'GH',
          scope: 'acme',
          secret: 'ghp_secret',
        );
        // A reset epoch far past DateTime's supported range makes
        // parseRateLimit throw; the check must still report the successful
        // auth, sans budget. (9999999999999 s * 1000 ≈ 1e16 ms, beyond
        // DateTime's ~8.64e15 ms limit, but within int64 so it doesn't wrap.)
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'login': 'alice'}),
            200,
            headers: {
              'x-ratelimit-remaining': '10',
              'x-ratelimit-reset': '9999999999999',
            },
          ),
        );

        final check = await TokenHealthService.check(token, client: client);
        expect(check.health, TokenHealth.valid);
        expect(check.account, 'alice');
        expect(check.rateLimit, isNull);
      },
    );
  });
}
