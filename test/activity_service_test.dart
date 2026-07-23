import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/activity_service.dart';
import 'package:kode_radar/ci_run_history.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  test('extractPrAuthorsGithub dedupes authors', () {
    final authors = ActivityService.extractPrAuthorsGithub([
      {
        'user': {'login': 'alice'},
      },
      {
        'user': {'login': 'bob'},
      },
      {
        'user': {'login': 'alice'},
      },
      {'user': null},
      {},
    ]);

    expect(authors, ['alice', 'bob']);
  });

  test('needsReviewCountGithub counts PRs with requested reviewers', () {
    final count = ActivityService.needsReviewCountGithub([
      {
        'requested_reviewers': [
          {'login': 'reviewer'},
        ],
      },
      {'requested_reviewers': []},
      {'requested_reviewers': 'not-list'},
      {},
    ]);

    expect(count, 1);
  });

  test('latestUpdatedAt returns the newest valid updated_at', () {
    final latest = ActivityService.latestUpdatedAt([
      {'updated_at': '2026-07-10T12:00:00Z'},
      {'updated_at': 'bad-date'},
      {'updated_at': '2026-07-12T01:00:00Z'},
    ]);

    expect(latest, DateTime.parse('2026-07-12T01:00:00Z'));
  });

  test('oldestOpenPrAgeDays returns age from oldest created_at', () {
    final now = DateTime.parse('2026-07-13T00:00:00Z');
    final age = ActivityService.oldestOpenPrAgeDays([
      {'created_at': '2026-07-10T00:00:00Z'},
      {'created_at': '2026-07-01T00:00:00Z'},
      {'created_at': 'bad-date'},
    ], now);

    expect(age, 12);
  });

  test('ciStatusFromGithubRuns maps success failure running and unknown', () {
    expect(
      ActivityService.ciStatusFromGithubRuns({
        'workflow_runs': [
          {'status': 'completed', 'conclusion': 'success'},
        ],
      }),
      'success',
    );
    expect(
      ActivityService.ciStatusFromGithubRuns({
        'workflow_runs': [
          {'status': 'completed', 'conclusion': 'failure'},
        ],
      }),
      'failure',
    );
    expect(
      ActivityService.ciStatusFromGithubRuns({
        'workflow_runs': [
          {'status': 'in_progress', 'conclusion': null},
        ],
      }),
      'running',
    );
    expect(
      ActivityService.ciStatusFromGithubRuns({'workflow_runs': []}),
      'unknown',
    );
  });

  test('ciStatusFromAdoBuilds maps success failure running and unknown', () {
    expect(
      ActivityService.ciStatusFromAdoBuilds({
        'value': [
          {'status': 'completed', 'result': 'succeeded'},
        ],
      }),
      'success',
    );
    expect(
      ActivityService.ciStatusFromAdoBuilds({
        'value': [
          {'status': 'completed', 'result': 'failed'},
        ],
      }),
      'failure',
    );
    expect(
      ActivityService.ciStatusFromAdoBuilds({
        'value': [
          {'status': 'inProgress', 'result': null},
        ],
      }),
      'running',
    );
    expect(ActivityService.ciStatusFromAdoBuilds({'value': []}), 'unknown');
  });

  test(
    'ciRunSamplesFromGithubRuns keys by run id + attempt, groups by workflow id',
    () {
      final samples = ActivityService.ciRunSamplesFromGithubRuns(
        {
          'workflow_runs': [
            {
              'id': 101,
              'workflow_id': 7,
              'run_attempt': 2,
              'name': 'CI',
              'status': 'completed',
              'conclusion': 'success',
              'head_branch': 'main',
              'updated_at': '2026-03-01T10:00:00Z',
              'html_url': 'https://github.com/o/r/actions/runs/101',
            },
            {
              'id': 102,
              'workflow_id': 7,
              'name': 'CI',
              'status': 'completed',
              'conclusion': 'failure',
              'updated_at': '2026-03-01T09:00:00Z',
            },
            {'name': 'no-id', 'status': 'completed', 'conclusion': 'success'},
          ],
        },
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      );
      expect(samples, hasLength(2));
      // run id + attempt in the key; provider prefix comes from repoKey (no
      // double "github:github").
      expect(samples[0].runKey, 'github:o/r:101:2');
      expect(samples[0].workflowId, '7');
      expect(samples[0].workflow, 'CI');
      expect(samples[0].outcome, CiOutcome.success);
      expect(samples[0].branch, 'main');
      // run_attempt defaults to 1 when absent.
      expect(samples[1].runKey, 'github:o/r:102:1');
      expect(samples[1].outcome, CiOutcome.failure);
    },
  );

  test('ciRunSamplesFromGithubRuns keeps only default-branch runs', () {
    final samples = ActivityService.ciRunSamplesFromGithubRuns(
      {
        'workflow_runs': [
          {
            'id': 1,
            'workflow_id': 7,
            'name': 'CI',
            'status': 'completed',
            'conclusion': 'success',
            'head_branch': 'main',
            'updated_at': '2026-03-01T10:00:00Z',
            'repository': {'default_branch': 'main'},
          },
          {
            'id': 2,
            'workflow_id': 7,
            'name': 'CI',
            'status': 'completed',
            'conclusion': 'failure',
            'head_branch': 'feature/x',
            'updated_at': '2026-03-01T09:00:00Z',
            'repository': {'default_branch': 'main'},
          },
        ],
      },
      repoKey: 'github:o/r',
      repoDisplay: 'o/r',
    );
    // The feature-branch run is dropped; only the default-branch run is kept.
    expect(samples, hasLength(1));
    expect(samples.single.runKey, 'github:o/r:1:1');
    expect(samples.single.branch, 'main');
  });

  test(
    'ciRunSamplesFromGithubRuns keeps all branches when default unknown',
    () {
      final samples = ActivityService.ciRunSamplesFromGithubRuns(
        {
          'workflow_runs': [
            {
              'id': 1,
              'name': 'CI',
              'status': 'completed',
              'conclusion': 'success',
              'head_branch': 'main',
              'updated_at': '2026-03-01T10:00:00Z',
            },
            {
              'id': 2,
              'name': 'CI',
              'status': 'completed',
              'conclusion': 'failure',
              'head_branch': 'feature/x',
              'updated_at': '2026-03-01T09:00:00Z',
            },
          ],
        },
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      );
      expect(samples, hasLength(2));
    },
  );

  test('githubRunOutcome buckets conclusions; cancelled is not a failure', () {
    expect(
      ActivityService.githubRunOutcome({'conclusion': 'success'}),
      CiOutcome.success,
    );
    expect(
      ActivityService.githubRunOutcome({'conclusion': 'timed_out'}),
      CiOutcome.failure,
    );
    expect(
      ActivityService.githubRunOutcome({
        'conclusion': null,
        'status': 'in_progress',
      }),
      CiOutcome.running,
    );
    expect(
      ActivityService.githubRunOutcome({
        'conclusion': 'cancelled',
        'status': 'completed',
      }),
      CiOutcome.other,
    );
    expect(
      ActivityService.githubRunOutcome({
        'conclusion': 'skipped',
        'status': 'completed',
      }),
      CiOutcome.other,
    );
  });

  test(
    'adoBuildOutcome: only failed is a failure; canceled/partial are other',
    () {
      expect(
        ActivityService.adoBuildOutcome({
          'status': 'completed',
          'result': 'failed',
        }),
        CiOutcome.failure,
      );
      expect(
        ActivityService.adoBuildOutcome({
          'status': 'completed',
          'result': 'canceled',
        }),
        CiOutcome.other,
      );
      expect(
        ActivityService.adoBuildOutcome({
          'status': 'completed',
          'result': 'partiallySucceeded',
        }),
        CiOutcome.other,
      );
      expect(
        ActivityService.adoBuildOutcome({
          'status': 'inProgress',
          'result': null,
        }),
        CiOutcome.running,
      );
    },
  );

  test('defaultBranchFromGithubRuns reads the default branch from a run', () {
    expect(
      ActivityService.defaultBranchFromGithubRuns({
        'workflow_runs': [
          {
            'id': 1,
            'repository': {'default_branch': 'trunk'},
          },
        ],
      }),
      'trunk',
    );
    expect(
      ActivityService.defaultBranchFromGithubRuns({'workflow_runs': []}),
      isNull,
    );
  });

  test('ciRunSamplesFromAdoBuilds parses builds, skips id-less', () {
    final samples = ActivityService.ciRunSamplesFromAdoBuilds(
      {
        'value': [
          {
            'id': 55,
            'definition': {'id': 3, 'name': 'Pipeline'},
            'status': 'completed',
            'result': 'succeeded',
            'sourceBranch': 'refs/heads/main',
            'finishTime': '2026-03-01T10:00:00Z',
            '_links': {
              'web': {
                'href': 'https://dev.azure.com/o/p/_build/results?buildId=55',
              },
            },
          },
          {'status': 'completed', 'result': 'failed'},
        ],
      },
      repoKey: 'ado:o/p/r',
      repoDisplay: 'o/p/r',
    );
    expect(samples, hasLength(1));
    expect(samples.single.runKey, 'ado:o/p/r:55');
    expect(samples.single.workflow, 'Pipeline');
    expect(samples.single.workflowId, '3');
    expect(samples.single.outcome, CiOutcome.success);
    expect(samples.single.url, contains('buildId=55'));
  });

  test('ciRunSamplesFromAdoBuilds filters to the default branch', () {
    final json = {
      'value': [
        {
          'id': 55,
          'definition': {'id': 3, 'name': 'Pipeline'},
          'status': 'completed',
          'result': 'succeeded',
          'sourceBranch': 'refs/heads/main',
          'finishTime': '2026-03-01T10:00:00Z',
        },
        {
          'id': 56,
          'definition': {'id': 3, 'name': 'Pipeline'},
          'status': 'completed',
          'result': 'failed',
          'sourceBranch': 'refs/heads/topic',
          'finishTime': '2026-03-01T09:00:00Z',
        },
      ],
    };
    final scoped = ActivityService.ciRunSamplesFromAdoBuilds(
      json,
      repoKey: 'ado:o/p/r',
      repoDisplay: 'o/p/r',
      defaultBranch: 'refs/heads/main',
    );
    expect(scoped, hasLength(1));
    expect(scoped.single.runKey, 'ado:o/p/r:55');
    // No default supplied -> keep both branches.
    final all = ActivityService.ciRunSamplesFromAdoBuilds(
      json,
      repoKey: 'ado:o/p/r',
      repoDisplay: 'o/p/r',
    );
    expect(all, hasLength(2));
  });

  test('ADO PR helpers parse authors review needs and age', () {
    final now = DateTime.parse('2026-07-13T00:00:00Z');
    final data = [
      {
        'createdBy': {'displayName': 'Ada'},
        'reviewers': [
          {'vote': 0},
        ],
        'creationDate': '2026-07-11T00:00:00Z',
      },
      {
        'createdBy': {'displayName': 'Ada'},
        'reviewers': [
          {'vote': 10},
        ],
        'creationDate': '2026-07-12T00:00:00Z',
      },
      {
        'createdBy': {'displayName': 'Grace'},
        'reviewers': [],
        'creationDate': '2026-07-01T00:00:00Z',
      },
    ];

    expect(ActivityService.extractPrAuthorsAdo(data), ['Ada', 'Grace']);
    expect(ActivityService.needsReviewCountAdo(data), 1);
    expect(
      ActivityService.latestCreatedAtAdo(data),
      DateTime.parse('2026-07-12T00:00:00Z'),
    );
    expect(ActivityService.oldestOpenPrAgeDaysAdo(data, now), 12);
  });

  test('scoreActivity ranks needs-review and recent activity higher', () {
    final now = DateTime.parse('2026-07-13T00:00:00Z');
    final highAttention = ActivityService.scoreActivity(
      openPrCount: 1,
      needsReviewCount: 2,
      lastActivity: now.subtract(const Duration(hours: 2)),
      now: now,
    );
    final lowerAttention = ActivityService.scoreActivity(
      openPrCount: 3,
      needsReviewCount: 0,
      lastActivity: now.subtract(const Duration(days: 60)),
      now: now,
    );

    expect(highAttention, greaterThan(lowerAttention));
  });

  test('computeForGithub builds activity from HTTP responses', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(request.headers['Accept'], 'application/vnd.github+json');

      if (request.url.path == '/repos/acme/kode/pulls') {
        expect(request.url.queryParameters['state'], 'open');
        expect(request.url.queryParameters['per_page'], '100');
        return http.Response(
          jsonEncode([
            {
              'user': {'login': 'alice'},
              'requested_reviewers': [
                {'login': 'bob'},
              ],
              'created_at': '2026-07-10T00:00:00Z',
              'updated_at': '2026-07-12T00:00:00Z',
            },
            {
              'user': {'login': 'alice'},
              'requested_reviewers': [],
              'created_at': '2026-07-11T00:00:00Z',
              'updated_at': '2026-07-11T00:00:00Z',
            },
          ]),
          200,
        );
      }

      if (request.url.path == '/repos/acme/kode/actions/runs') {
        expect(request.url.queryParameters['per_page'], '50');
        return http.Response(
          jsonEncode({
            'workflow_runs': [
              {
                'id': 1,
                'name': 'CI',
                'status': 'completed',
                'conclusion': 'success',
                'updated_at': '2026-03-01T10:00:00Z',
              },
            ],
          }),
          200,
        );
      }

      return http.Response('not found', 404);
    });

    final activity = await ActivityService.computeForGithub(
      owner: 'acme',
      name: 'kode',
      secret: 'secret',
      repoKey: 'github:acme/kode',
      client: client,
    );

    expect(activity.displayName, 'acme/kode');
    expect(activity.openPrCount, 2);
    expect(activity.needsReviewCount, 1);
    expect(activity.contributors, ['alice']);
    expect(activity.ciStatus, 'success');
    expect(activity.recentRuns.single.outcome, CiOutcome.success);
    expect(activity.recentRuns.single.runKey, 'github:acme/kode:1:1');
    expect(activity.error, isNull);
  });

  test('computeForGithub does a branch-scoped follow-up when the page has no '
      'completed default-branch run', () async {
    var scopedCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/repos/acme/kode/pulls') {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path == '/repos/acme/kode/actions/runs') {
        final branch = request.url.queryParameters['branch'];
        if (branch == null) {
          // A full (50) page: 49 PR-branch failures (dropped from trends) plus
          // one IN-PROGRESS default-branch run. recentRuns is therefore
          // non-empty but has no completed/persistable run, which must still
          // trigger the follow-up (the old `recentRuns.isEmpty` trigger would
          // have wrongly skipped it). Newest run drives ciStatus = failure.
          return http.Response(
            jsonEncode({
              'workflow_runs': [
                for (var i = 0; i < 49; i++)
                  {
                    'id': 100 + i,
                    'name': 'CI',
                    'status': 'completed',
                    'conclusion': 'failure',
                    'head_branch': 'feature/x',
                    'updated_at': '2026-03-01T10:00:00Z',
                    'repository': {'default_branch': 'main'},
                  },
                {
                  'id': 149,
                  'name': 'CI',
                  'status': 'in_progress',
                  'conclusion': null,
                  'head_branch': 'main',
                  'updated_at': '2026-03-01T10:30:00Z',
                  'repository': {'default_branch': 'main'},
                },
              ],
            }),
            200,
          );
        }
        scopedCalls++;
        expect(branch, 'main');
        return http.Response(
          jsonEncode({
            'workflow_runs': [
              {
                'id': 10,
                'name': 'CI',
                'status': 'completed',
                'conclusion': 'success',
                'head_branch': 'main',
                'updated_at': '2026-03-01T09:00:00Z',
                'repository': {'default_branch': 'main'},
              },
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final activity = await ActivityService.computeForGithub(
      owner: 'acme',
      name: 'kode',
      secret: 'secret',
      repoKey: 'github:acme/kode',
      client: client,
    );

    expect(scopedCalls, 1);
    // ciStatus comes only from the first (all-branch) page...
    expect(activity.ciStatus, 'failure');
    // ...while the trend sample comes from the scoped default-branch page.
    expect(activity.recentRuns.single.runKey, 'github:acme/kode:10:1');
    expect(activity.recentRuns.single.branch, 'main');
  });

  test(
    'computeForAdo scopes the trend follow-up to the default branch',
    () async {
      var scopedBuildCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/pullrequests')) {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        if (path.endsWith('/git/repositories/kode')) {
          return http.Response(
            jsonEncode({'id': 'guid-1', 'defaultBranch': 'refs/heads/main'}),
            200,
          );
        }
        if (path.endsWith('/build/builds')) {
          final branchName = request.url.queryParameters['branchName'];
          if (branchName == null) {
            // Full (50) all-branch page, all PR-branch failures.
            return http.Response(
              jsonEncode({
                'value': [
                  for (var i = 0; i < 50; i++)
                    {
                      'id': 200 + i,
                      'definition': {'id': 1, 'name': 'Pipeline'},
                      'status': 'completed',
                      'result': 'failed',
                      'sourceBranch': 'refs/heads/topic',
                      'finishTime': '2026-03-01T10:00:00Z',
                    },
                ],
              }),
              200,
            );
          }
          scopedBuildCalls++;
          expect(branchName, 'refs/heads/main');
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 300,
                  'definition': {'id': 1, 'name': 'Pipeline'},
                  'status': 'completed',
                  'result': 'succeeded',
                  'sourceBranch': 'refs/heads/main',
                  'finishTime': '2026-03-01T09:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final activity = await ActivityService.computeForAdo(
        organization: 'org',
        project: 'proj',
        name: 'kode',
        secret: 'secret',
        repoKey: 'ado:org/proj/kode',
        client: client,
      );

      expect(scopedBuildCalls, 1);
      // ciStatus from the all-branch page (failed); trend sample from the scoped
      // default-branch page (succeeded).
      expect(activity.ciStatus, 'failure');
      expect(activity.recentRuns.single.runKey, 'ado:org/proj/kode:300');
      expect(activity.recentRuns.single.outcome, CiOutcome.success);
    },
  );

  group('computeAll onlyRepoKeys', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('fetches only the requested repositories', () async {
      final gh = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Acme',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({'owner': 'acme', 'repoName': 'api', 'tokenId': gh.id}),
        jsonEncode({'owner': 'acme', 'repoName': 'web', 'tokenId': gh.id}),
      ]);
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/actions/runs')) {
          return http.Response(jsonEncode({'workflow_runs': []}), 200);
        }
        return http.Response('[]', 200);
      });

      final scoped = await ActivityService.computeAll(
        client: client,
        onlyRepoKeys: {'github:acme/api'},
      );
      expect(scoped.map((a) => a.repoKey).toList(), ['github:acme/api']);

      final none = await ActivityService.computeAll(
        client: client,
        onlyRepoKeys: {},
      );
      expect(none, isEmpty);
    });
  });

  group('sortActivities', () {
    RepoActivity repo(
      String name, {
      num score = 0,
      int openPrs = 0,
      int? oldestPr,
      String ci = 'unknown',
      String? error,
    }) => RepoActivity(
      repoKey: 'github:$name',
      provider: 'github',
      displayName: name,
      url: 'https://github.com/$name',
      openPrCount: openPrs,
      needsReviewCount: 0,
      oldestOpenPrAgeDays: oldestPr,
      lastActivity: null,
      ciStatus: ci,
      contributors: const [],
      activityScore: score,
      error: error,
    );

    test('attention: errors first, then score desc, then name', () {
      final sorted = ActivityService.sortActivities([
        repo('bravo', score: 5),
        repo('alpha', score: 5),
        repo('charlie', score: 9),
        repo('delta', score: 1, error: 'boom'),
      ], RadarSort.attention);
      expect(sorted.map((a) => a.displayName).toList(), [
        'delta', // error first
        'charlie', // highest score
        'alpha', // score tie -> name
        'bravo',
      ]);
    });

    test('ciStatus: failing first, then running, unknown, success', () {
      final sorted = ActivityService.sortActivities([
        repo('ok', ci: 'success'),
        repo('broken', ci: 'failure'),
        repo('pending', ci: 'running'),
        repo('mystery', ci: 'unknown'),
      ], RadarSort.ciStatus);
      expect(sorted.map((a) => a.displayName).toList(), [
        'broken',
        'pending',
        'mystery',
        'ok',
      ]);
    });

    test('openPrs: most open PRs first', () {
      final sorted = ActivityService.sortActivities([
        repo('few', openPrs: 1),
        repo('many', openPrs: 9),
        repo('none', openPrs: 0),
      ], RadarSort.openPrs);
      expect(sorted.map((a) => a.displayName).toList(), [
        'many',
        'few',
        'none',
      ]);
    });

    test('oldestPr: oldest first, repos without an open PR last', () {
      final sorted = ActivityService.sortActivities([
        repo('recent', oldestPr: 2),
        repo('none', oldestPr: null),
        repo('ancient', oldestPr: 40),
      ], RadarSort.oldestPr);
      expect(sorted.map((a) => a.displayName).toList(), [
        'ancient',
        'recent',
        'none',
      ]);
    });

    test('name: case-insensitive alphabetical', () {
      final sorted = ActivityService.sortActivities([
        repo('Zeta'),
        repo('alpha'),
        repo('Mango'),
      ], RadarSort.name);
      expect(sorted.map((a) => a.displayName).toList(), [
        'alpha',
        'Mango',
        'Zeta',
      ]);
    });

    test('does not mutate the input list', () {
      final input = [repo('b', score: 1), repo('a', score: 2)];
      final copy = List.of(input);
      ActivityService.sortActivities(input, RadarSort.name);
      expect(
        input.map((a) => a.displayName).toList(),
        copy.map((a) => a.displayName).toList(),
      );
    });

    test('metric sorts surface errored repos first (not buried as zeros)', () {
      final sorted = ActivityService.sortActivities([
        repo('green', ci: 'success', openPrs: 3, oldestPr: 5),
        repo('broken', ci: 'unknown', error: 'no token'),
      ], RadarSort.ciStatus);
      // Despite 'success' outranking 'unknown', the errored repo comes first.
      expect(sorted.first.displayName, 'broken');

      final byPrs = ActivityService.sortActivities([
        repo('green', openPrs: 3),
        repo('broken', openPrs: 0, error: 'no token'),
      ], RadarSort.openPrs);
      expect(byPrs.first.displayName, 'broken');
    });

    test('name sort stays purely alphabetical (errors not hoisted)', () {
      final sorted = ActivityService.sortActivities([
        repo('zeta', error: 'boom'),
        repo('alpha'),
      ], RadarSort.name);
      expect(sorted.map((a) => a.displayName).toList(), ['alpha', 'zeta']);
    });

    test('radarSortLabel gives a label for every option', () {
      for (final sort in RadarSort.values) {
        expect(ActivityService.radarSortLabel(sort), isNotEmpty);
      }
    });
  });
}
