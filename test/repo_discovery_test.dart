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
}
