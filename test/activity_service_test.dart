import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/activity_service.dart';
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
        expect(request.url.queryParameters['per_page'], '1');
        return http.Response(
          jsonEncode({
            'workflow_runs': [
              {'status': 'completed', 'conclusion': 'success'},
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
    expect(activity.error, isNull);
  });

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
}
