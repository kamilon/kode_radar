import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/identity_service.dart';
import 'package:kode_radar/identity_store.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('parseGithubLogin and parseAdoName are null-tolerant', () {
    expect(IdentityService.parseGithubLogin({'login': ' octocat '}), 'octocat');
    expect(IdentityService.parseGithubLogin({'login': 42}), isNull);
    expect(IdentityService.parseGithubLogin('nope'), isNull);
    expect(
      IdentityService.parseAdoName({'displayName': 'Jane Doe'}),
      'Jane Doe',
    );
    expect(IdentityService.parseAdoName({'displayName': ''}), isNull);
    expect(IdentityService.parseAdoName({}), isNull);
  });

  test(
    'detectSelf collects identities from tokens and merges into storage',
    () async {
      await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Personal',
        scope: 'acme',
        secret: 'ghp_x',
      );
      await TokenStore.addToken(
        provider: TokenStore.providerAdo,
        label: 'Org',
        scope: 'org',
        secret: 'ado_x',
      );
      await IdentityStore.setSelfGithubLogins({'existing'});

      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com' &&
            request.url.path == '/user') {
          return http.Response(jsonEncode({'login': 'octocat'}), 200);
        }
        if (request.url.host == 'app.vssps.visualstudio.com' &&
            request.url.path == '/_apis/profile/profiles/me') {
          return http.Response(jsonEncode({'displayName': 'Jane Doe'}), 200);
        }
        return http.Response('{}', 404);
      });

      final result = await IdentityService.detectSelf(client: client);
      expect(result.githubLogins, {'octocat'});
      expect(result.adoNames, {'Jane Doe'});
      expect(await IdentityStore.selfGithubLogins(), {'existing', 'octocat'});
      expect(await IdentityStore.selfAdoNames(), {'Jane Doe'});
    },
  );

  test('detectSelf with persist:false does not write to storage', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Personal',
      scope: 'acme',
      secret: 'ghp_x',
    );
    final client = MockClient(
      (request) async => http.Response(jsonEncode({'login': 'octocat'}), 200),
    );

    final result = await IdentityService.detectSelf(
      client: client,
      persist: false,
    );
    expect(result.githubLogins, {'octocat'});
    expect(await IdentityStore.selfGithubLogins(), isEmpty);
  });

  test('detectSelf isolates per-token failures without throwing', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Personal',
      scope: 'acme',
      secret: 'ghp_x',
    );
    final client = MockClient((request) async => http.Response('nope', 401));
    final result = await IdentityService.detectSelf(client: client);
    expect(result.isEmpty, isTrue);
  });
}
