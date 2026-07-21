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

  group('parseGithubGraphqlPulls', () {
    test('maps reviewDecision to review state; parses age/draft', () {
      Map<String, dynamic> node(
        int number,
        String? decision,
        int pending, {
        bool draft = false,
        String created = '2026-07-13T12:00:00Z',
      }) => {
        'number': number,
        'title': 'PR $number',
        'url': 'https://github.com/acme/api/pull/$number',
        'isDraft': draft,
        'createdAt': created,
        'author': {'login': 'alice'},
        'reviewDecision': decision,
        'reviewRequests': {'totalCount': pending},
      };

      final pulls = RepoDetailService.parseGithubGraphqlPulls({
        'data': {
          'repository': {
            'pullRequests': {
              'nodes': [
                node(7, 'APPROVED', 0),
                node(8, 'CHANGES_REQUESTED', 1),
                node(9, 'REVIEW_REQUIRED', 2, draft: true),
                node(
                  10,
                  null,
                  1,
                ), // no decision but a pending request => waiting
                node(11, null, 0), // no decision, no request => none
              ],
            },
          },
        },
      }, now);

      expect(pulls, hasLength(5));
      expect(pulls[0].reviewState, PrReviewState.approved);
      expect(pulls[0].ageDays, 2);
      expect(pulls[0].draft, isFalse);
      expect(pulls[1].reviewState, PrReviewState.changesRequested);
      expect(pulls[2].reviewState, PrReviewState.waiting);
      expect(pulls[2].draft, isTrue);
      expect(pulls[3].reviewState, PrReviewState.waiting);
      expect(pulls[4].reviewState, PrReviewState.none);
    });

    test('returns empty on a missing/error response shape', () {
      expect(
        RepoDetailService.parseGithubGraphqlPulls({'errors': []}, now),
        isEmpty,
      );
      expect(RepoDetailService.parseGithubGraphqlPulls('nope', now), isEmpty);
    });

    test('parses mergeable and diff size', () {
      List<RepoPr> parse(String? mergeable) =>
          RepoDetailService.parseGithubGraphqlPulls({
            'data': {
              'repository': {
                'pullRequests': {
                  'nodes': [
                    {
                      'number': 7,
                      'title': 'PR 7',
                      'url': 'https://github.com/acme/api/pull/7',
                      'isDraft': false,
                      'createdAt': '2026-07-13T12:00:00Z',
                      'author': {'login': 'alice'},
                      'reviewDecision': 'APPROVED',
                      'reviewRequests': {'totalCount': 0},
                      'mergeable': mergeable,
                      'additions': 120,
                      'deletions': 30,
                      'changedFiles': 4,
                    },
                  ],
                },
              },
            },
          }, now);

      final conflicting = parse('CONFLICTING').single;
      expect(conflicting.mergeable, PrMergeable.conflicting);
      expect(conflicting.additions, 120);
      expect(conflicting.deletions, 30);
      expect(conflicting.changedFiles, 4);
      expect(parse('MERGEABLE').single.mergeable, PrMergeable.mergeable);
      expect(parse('UNKNOWN').single.mergeable, PrMergeable.unknown);
      expect(parse(null).single.mergeable, PrMergeable.unknown);
    });
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

    test('maps mergeStatus to a mergeable state', () {
      RepoPr parse(String? mergeStatus) => RepoDetailService.parseAdoPulls(
        [
          {
            'pullRequestId': 12,
            'title': 'Ship',
            'createdBy': {'displayName': 'Jane Doe'},
            'creationDate': '2026-07-14T12:00:00Z',
            'reviewers': const [],
            'mergeStatus': mergeStatus,
          },
        ],
        now,
        organization: 'contoso',
        project: 'web',
        name: 'site',
      ).single;

      expect(parse('succeeded').mergeable, PrMergeable.mergeable);
      expect(parse('conflicts').mergeable, PrMergeable.conflicting);
      // Only a real merge conflict is "conflicting"; policy/other blocks aren't.
      expect(parse('rejectedByPolicy').mergeable, PrMergeable.unknown);
      expect(parse('failure').mergeable, PrMergeable.unknown);
      expect(parse('queued').mergeable, PrMergeable.unknown);
      expect(parse(null).mergeable, PrMergeable.unknown);
      // ADO's list API carries no diff size.
      expect(parse('succeeded').additions, isNull);
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
      String? capturedMethod;
      String? capturedContentType;
      Map<String, dynamic>? capturedGraphqlBody;
      final client = MockClient((request) async {
        if (request.url.path == '/graphql') {
          capturedAuth =
              request.headers['authorization'] ??
              request.headers['Authorization'];
          capturedMethod = request.method;
          capturedContentType =
              request.headers['content-type'] ??
              request.headers['Content-Type'];
          capturedGraphqlBody =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'repository': {
                  'pullRequests': {'nodes': []},
                },
              },
            }),
            200,
          );
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
      // The GraphQL contract: a POST of JSON carrying owner/name variables and
      // the reviewDecision-bearing query.
      expect(capturedMethod, 'POST');
      expect(capturedContentType, contains('application/json'));
      expect(capturedGraphqlBody?['variables'], {
        'owner': 'acme',
        'name': 'api',
      });
      expect(capturedGraphqlBody?['query'], contains('reviewDecision'));
    });

    test('reports pulls failure on a malformed GraphQL response', () async {
      await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Default',
        scope: 'acme',
        secret: 'ghp_default',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({'owner': 'acme', 'repoName': 'api'}),
      ]);

      final client = MockClient((request) async {
        if (request.url.path == '/graphql') {
          // 200 but no repository (e.g. an unexpected/partial body) must be a
          // failure, not an empty "no open PRs" list.
          return http.Response(jsonEncode({'data': {}}), 200);
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

      expect(data.pullsFailed, isTrue);
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
