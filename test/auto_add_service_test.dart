import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kode_radar/token_store.dart';
import 'package:kode_radar/auto_add_service.dart';
import 'package:kode_radar/repo_store.dart';
import 'package:kode_radar/ignore_store.dart';
import 'package:kode_radar/repo_discovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'adds new repos for an auto-add token and skips existing ones',
    () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Acme',
        scope: 'acme',
        secret: 'ghp_secret',
        autoAdd: true,
      );

      final client = MockClient((request) async {
        if (request.url.path == '/orgs/acme/repos' &&
            request.url.queryParameters['page'] == '1') {
          return http.Response(
            jsonEncode([
              {
                'name': 'api',
                'owner': {'login': 'acme'},
              },
              {
                'name': 'web',
                'owner': {'login': 'acme'},
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final added = await AutoAddService.run(client: client);
      expect(added, 2);

      final prefs = await SharedPreferences.getInstance();
      final repos = prefs.getStringList('github_repos') ?? [];
      expect(repos.length, 2);
      final first = Map<String, String>.from(jsonDecode(repos.first));
      expect(first['owner'], 'acme');
      expect(first['tokenId'], token.id);

      // A second pass adds nothing since everything is already monitored.
      expect(await AutoAddService.run(client: client), 0);
    },
  );

  test('does nothing when no token has auto-add enabled', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Manual',
      scope: 'acme',
      secret: 'ghp_secret',
      autoAdd: false,
    );
    final client = MockClient((_) async => http.Response('[]', 200));
    expect(await AutoAddService.run(client: client), 0);
  });

  test('skips ADO auto-add tokens that have no organization scope', () async {
    await TokenStore.addToken(
      provider: TokenStore.providerAdo,
      label: 'ADO default',
      scope: '',
      secret: 'ado_secret',
      autoAdd: true,
    );
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{"value": []}', 200);
    });
    expect(await AutoAddService.run(client: client), 0);
    expect(called, isFalse);
  });

  test('a concurrent delete during a pass is not clobbered', () async {
    // Seed one existing repo and enable auto-add.
    await RepoStore.update(
      RepoStore.githubKey,
      (repos) => repos.add(jsonEncode({'owner': 'acme', 'repoName': 'a'})),
    );
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Acme',
      scope: 'acme',
      secret: 'ghp_secret',
      autoAdd: true,
    );

    // The fetch is slow, giving us a window to delete concurrently.
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response(
        jsonEncode([
          {
            'name': 'c',
            'owner': {'login': 'acme'},
          },
        ]),
        200,
      );
    });

    final pass = AutoAddService.run(client: client);
    // While the pass is fetching, delete the existing repo via the same lock.
    await RepoStore.update(
      RepoStore.githubKey,
      (repos) => repos.removeWhere((r) => r.contains('"repoName":"a"')),
    );
    final added = await pass;

    expect(added, 1); // 'c' was added
    final prefs = await SharedPreferences.getInstance();
    final repos = prefs.getStringList('github_repos') ?? [];
    // 'a' stayed deleted, 'c' present — the delete was not clobbered.
    expect(repos.any((r) => r.contains('"repoName":"a"')), isFalse);
    expect(repos.any((r) => r.contains('"repoName":"c"')), isTrue);
  });

  test('auto-add never adds an ignored repo', () async {
    await IgnoreStore.add(RepoDiscoveryService.githubKey('acme', 'secret'));
    await TokenStore.addToken(
      provider: TokenStore.providerGithub,
      label: 'Acme',
      scope: 'acme',
      secret: 'ghp_secret',
      autoAdd: true,
    );

    final client = MockClient((request) async {
      if (request.url.path == '/orgs/acme/repos' &&
          request.url.queryParameters['page'] == '1') {
        return http.Response(
          jsonEncode([
            {
              'name': 'secret',
              'owner': {'login': 'acme'},
            },
            {
              'name': 'ok',
              'owner': {'login': 'acme'},
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    final added = await AutoAddService.run(client: client);
    expect(added, 1); // only 'ok'; 'secret' is ignored
    final prefs = await SharedPreferences.getInstance();
    final repos = prefs.getStringList('github_repos') ?? [];
    expect(repos.any((r) => r.contains('"repoName":"secret"')), isFalse);
    expect(repos.any((r) => r.contains('"repoName":"ok"')), isTrue);
  });
}
