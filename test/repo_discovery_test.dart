import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kode_radar/repo_discovery_service.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  test('parses GitHub repos and builds stable keys', () {
    final repos = RepoDiscoveryService.parseGithubRepos([
      {
        'name': 'flutter',
        'owner': {'login': 'Flutter'},
      },
      {
        'name': 'engine',
        'owner': {'login': 'flutter'},
      },
      {'name': 'no-owner'}, // skipped: missing owner
      {'name': 'bad-owner', 'owner': 'not-a-map'}, // skipped: owner not a map
    ]);

    expect(repos.length, 2);
    expect(repos.first.display, 'Flutter/flutter');
    expect(repos.first.repo, {'owner': 'Flutter', 'repoName': 'flutter'});
    // Key is case-insensitive.
    expect(
      repos.first.key,
      RepoDiscoveryService.githubKey('flutter', 'FLUTTER'),
    );
  });

  test('parses Azure DevOps repos with project info', () {
    final repos = RepoDiscoveryService.parseAdoRepos('acme', [
      {
        'name': 'api',
        'project': {'name': 'Platform'},
      },
      {'name': 'orphan'}, // skipped: missing project
      {'name': 'bad', 'project': 'not-a-map'}, // skipped: project not a map
    ]);

    expect(repos.length, 1);
    expect(repos.single.display, 'Platform/api');
    expect(repos.single.repo, {
      'organization': 'acme',
      'project': 'Platform',
      'repoName': 'api',
    });
    expect(
      repos.single.key,
      RepoDiscoveryService.adoKey('ACME', 'platform', 'API'),
    );
  });

  test(
    'falls back to /user/repos filtered by owner for a personal scope',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/orgs/octocat/repos') {
          return http.Response('{"message": "Not Found"}', 404);
        }
        if (request.url.path == '/user/repos') {
          return http.Response(
            jsonEncode([
              {
                'name': 'hello',
                'owner': {'login': 'octocat'},
              },
              {
                'name': 'other',
                'owner': {'login': 'someoneelse'},
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final result = await RepoDiscoveryService.fetch(
        provider: TokenStore.providerGithub,
        secret: 'ghp_secret',
        org: 'octocat',
        client: client,
      );

      // Only the owner's repo survives the filter.
      expect(result.repos.length, 1);
      expect(result.repos.single.display, 'octocat/hello');
    },
  );

  test(
    'follows the Link header to page GitHub repos beyond one page',
    () async {
      List<Map<String, dynamic>> reposPage(String prefix, int count) => [
        for (var i = 0; i < count; i++)
          {
            'name': '$prefix$i',
            'owner': {'login': 'acme'},
          },
      ];
      final client = MockClient((request) async {
        if (request.url.path != '/user/repos') {
          return http.Response('[]', 200);
        }
        final page = request.url.queryParameters['page'];
        if (page == null) {
          // First page: a full page plus a Link header pointing to page 2.
          return http.Response(
            jsonEncode(reposPage('p1_', 100)),
            200,
            headers: {
              'link':
                  '<https://api.github.com/user/repos?per_page=100&page=2>; '
                  'rel="next", '
                  '<https://api.github.com/user/repos?per_page=100&page=2>; '
                  'rel="last"',
            },
          );
        }
        if (page == '2') {
          // Last page: no Link header, so paging stops here.
          return http.Response(jsonEncode(reposPage('p2_', 5)), 200);
        }
        return http.Response('[]', 200);
      });

      final result = await RepoDiscoveryService.fetch(
        provider: TokenStore.providerGithub,
        secret: 'ghp_secret',
        org: '',
        client: client,
      );

      // Both pages collected (100 + 5), and not marked truncated.
      expect(result.repos.length, 105);
      expect(result.truncated, isFalse);
    },
  );

  test('stops after one page when there is no Link header', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode([
          {
            'name': 'solo',
            'owner': {'login': 'acme'},
          },
        ]),
        200,
      );
    });

    final result = await RepoDiscoveryService.fetch(
      provider: TokenStore.providerGithub,
      secret: 'ghp_secret',
      org: '',
      client: client,
    );

    expect(result.repos.length, 1);
    expect(requests, 1);
  });

  test('does not follow a cross-host Link (no token leak)', () async {
    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      return http.Response(
        jsonEncode([
          {
            'name': 'solo',
            'owner': {'login': 'acme'},
          },
        ]),
        200,
        headers: {
          // A hostile/proxying response pointing the next page at another host.
          'link': '<https://evil.example.com/user/repos?page=2>; rel="next"',
        },
      );
    });

    final result = await RepoDiscoveryService.fetch(
      provider: TokenStore.providerGithub,
      secret: 'ghp_secret',
      org: '',
      client: client,
    );

    // The cross-host next link is rejected, so only api.github.com is hit.
    expect(hosts, ['api.github.com']);
    expect(result.repos.length, 1);
  });
}
