import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/repo_detail_service.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  final now = DateTime.parse('2026-07-15T12:00:00Z');

  group('parseGithubPulls', () {
    test(
      'maps requested reviewers to waiting, else none; parses age/draft',
      () {
        final pulls = RepoDetailService.parseGithubPulls([
          {
            'number': 7,
            'title': 'Add feature',
            'user': {'login': 'alice'},
            'created_at': '2026-07-13T12:00:00Z',
            'html_url': 'https://github.com/acme/api/pull/7',
            'requested_reviewers': [
              {'login': 'bob'},
            ],
          },
          {
            'number': 8,
            'title': 'WIP',
            'user': {'login': 'carol'},
            'created_at': '2026-07-15T00:00:00Z',
            'draft': true,
            'requested_reviewers': [],
          },
        ], now);

        expect(pulls, hasLength(2));
        expect(pulls[0].label, 'PR #7');
        expect(pulls[0].reviewState, PrReviewState.waiting);
        expect(pulls[0].ageDays, 2);
        expect(pulls[0].draft, isFalse);
        expect(pulls[1].reviewState, PrReviewState.none);
        expect(pulls[1].draft, isTrue);
      },
    );
  });

  group('parseAdoPulls', () {
    test('derives review state from reviewer votes and builds the URL', () {
      List<RepoPr> parse(List<int> votes) => RepoDetailService.parseAdoPulls(
        [
          {
            'pullRequestId': 12,
            'title': 'Ship',
            'createdBy': {'displayName': 'Jane Doe'},
            'creationDate': '2026-07-14T12:00:00Z',
            'reviewers': [
              for (final v in votes) {'vote': v},
            ],
          },
        ],
        now,
        organization: 'contoso',
        project: 'web',
        name: 'site',
      );

      expect(parse([-5]).single.reviewState, PrReviewState.changesRequested);
      expect(parse([10]).single.reviewState, PrReviewState.approved);
      expect(parse([0]).single.reviewState, PrReviewState.waiting);
      // A pending (0) vote outranks an approval: still needs review.
      expect(parse([10, 0]).single.reviewState, PrReviewState.waiting);
      // A rejection outranks everything.
      expect(
        parse([10, -5, 0]).single.reviewState,
        PrReviewState.changesRequested,
      );
      expect(parse(const []).single.reviewState, PrReviewState.none);
      expect(
        parse([10]).single.url,
        'https://dev.azure.com/contoso/web/_git/site/pullrequest/12',
      );
    });
  });

  group('parseGithubRuns / parseAdoBuilds', () {
    test('parseGithubRuns extracts name/status/conclusion/branch', () {
      final runs = RepoDetailService.parseGithubRuns({
        'workflow_runs': [
          {
            'name': 'CI',
            'status': 'completed',
            'conclusion': 'failure',
            'head_branch': 'main',
            'updated_at': '2026-07-14T10:00:00Z',
            'html_url': 'https://github.com/acme/api/actions/runs/1',
          },
        ],
      });
      expect(runs.single.name, 'CI');
      expect(runs.single.status, 'completed');
      expect(runs.single.conclusion, 'failure');
      expect(runs.single.branch, 'main');
    });

    test('parseAdoBuilds strips the ref prefix and reads result', () {
      final runs = RepoDetailService.parseAdoBuilds({
        'value': [
          {
            'definition': {'name': 'Nightly'},
            'status': 'completed',
            'result': 'succeeded',
            'sourceBranch': 'refs/heads/main',
            'finishTime': '2026-07-14T06:00:00Z',
            '_links': {
              'web': {'href': 'https://dev.azure.com/contoso/web/_build/1'},
            },
          },
        ],
      });
      expect(runs.single.name, 'Nightly');
      expect(runs.single.conclusion, 'succeeded');
      expect(runs.single.branch, 'main');
      expect(runs.single.url, 'https://dev.azure.com/contoso/web/_build/1');
    });
  });

  group('parseGithubReleases', () {
    test('parses releases and skips entries without a tag', () {
      final releases = RepoDetailService.parseGithubReleases([
        {
          'tag_name': 'v1.2.0',
          'name': 'Big release',
          'author': {'login': 'octocat'},
          'published_at': '2026-07-10T09:00:00Z',
          'html_url': 'https://github.com/acme/api/releases/v1.2.0',
        },
        {'name': 'no tag'},
      ]);
      expect(releases, hasLength(1));
      expect(releases.single.tag, 'v1.2.0');
      expect(releases.single.name, 'Big release');
      expect(releases.single.author, 'octocat');
    });
  });

  group('load', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('resolves the repo record and honors its explicit tokenId', () async {
      // A same-scope default token and the repo's explicitly assigned token.
      await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Default',
        scope: 'acme',
        secret: 'ghp_default',
      );
      final assigned = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Assigned',
        scope: 'other',
        secret: 'ghp_assigned',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({
          'owner': 'acme',
          'repoName': 'api',
          'tokenId': assigned.id,
        }),
      ]);

      String? capturedAuth;
      final client = MockClient((request) async {
        if (request.url.path == '/repos/acme/api/pulls') {
          capturedAuth =
              request.headers['authorization'] ??
              request.headers['Authorization'];
          return http.Response('[]', 200);
        }
        if (request.url.path == '/repos/acme/api/actions/runs') {
          return http.Response(jsonEncode({'workflow_runs': []}), 200);
        }
        return http.Response('[]', 200);
      });

      final data = await RepoDetailService.load(
        repoKey: 'github:acme/api',
        provider: 'github',
        client: client,
        now: now,
      );

      expect(data.failedSources, 0);
      // The repo's own token (not the scope-default) must be used.
      expect(capturedAuth, contains('ghp_assigned'));
    });

    test('reports failure when the repo record is not found', () async {
      final data = await RepoDetailService.load(
        repoKey: 'github:missing/repo',
        provider: 'github',
        now: now,
      );
      expect(data.failedSources, greaterThan(0));
    });
  });
}
