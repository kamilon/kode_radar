import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/activity_event.dart';
import 'package:kode_radar/activity_feed_service.dart';
import 'package:kode_radar/token_store.dart';

void main() {
  const repoDisplay = 'acme/api';
  const repoKey = 'github:acme/api';

  group('githubEventsToActivity', () {
    test('normalizes push, PR lifecycle, review, and release events', () {
      final events = ActivityFeedService.githubEventsToActivity(
        repoDisplay: repoDisplay,
        repoKey: repoKey,
        selfGithubLogins: {'octocat'},
        events: [
          {
            'id': '1',
            'type': 'PushEvent',
            'actor': {'login': 'octocat'},
            'created_at': '2026-07-14T10:00:00Z',
            'payload': {
              'ref': 'refs/heads/main',
              'size': 3,
              'before': 'aaa',
              'head': 'bbb',
            },
          },
          {
            'id': '2',
            'type': 'PullRequestEvent',
            'actor': {'login': 'alice'},
            'created_at': '2026-07-14T11:00:00Z',
            'payload': {
              'action': 'opened',
              'pull_request': {
                'number': 7,
                'title': 'Add feature',
                'html_url': 'https://github.com/acme/api/pull/7',
              },
            },
          },
          {
            'id': '3',
            'type': 'PullRequestEvent',
            'actor': {'login': 'bob'},
            'created_at': '2026-07-14T12:00:00Z',
            'payload': {
              'action': 'closed',
              'pull_request': {
                'number': 6,
                'title': 'Old work',
                'merged': true,
                'html_url': 'https://github.com/acme/api/pull/6',
              },
            },
          },
          {
            'id': '4',
            'type': 'PullRequestReviewEvent',
            'actor': {'login': 'carol'},
            'created_at': '2026-07-14T13:00:00Z',
            'payload': {
              'action': 'submitted',
              'review': {
                'state': 'changes_requested',
                'html_url': 'https://github.com/acme/api/pull/7#r1',
              },
              'pull_request': {'number': 7, 'title': 'Add feature'},
            },
          },
          {
            'id': '5',
            'type': 'ReleaseEvent',
            'actor': {'login': 'octocat'},
            'created_at': '2026-07-14T14:00:00Z',
            'payload': {
              'action': 'published',
              'release': {
                'tag_name': 'v1.2.0',
                'name': 'Big release',
                'html_url': 'https://github.com/acme/api/releases/v1.2.0',
              },
            },
          },
          // Ignored: non-lifecycle PR action.
          {
            'id': '6',
            'type': 'PullRequestEvent',
            'actor': {'login': 'alice'},
            'created_at': '2026-07-14T15:00:00Z',
            'payload': {
              'action': 'labeled',
              'pull_request': {'number': 7, 'title': 'Add feature'},
            },
          },
        ],
      );

      final byType = {for (final e in events) e.type: e};
      expect(events, hasLength(5));
      expect(
        byType[ActivityType.push]!.title,
        'octocat pushed 3 commits to main',
      );
      expect(byType[ActivityType.push]!.isMine, isTrue);
      expect(
        byType[ActivityType.push]!.url,
        'https://github.com/acme/api/compare/aaa...bbb',
      );
      expect(byType[ActivityType.prOpened]!.title, 'alice opened PR #7');
      expect(byType[ActivityType.prOpened]!.isMine, isFalse);
      expect(byType[ActivityType.prMerged]!.title, 'bob merged PR #6');
      expect(
        byType[ActivityType.reviewSubmitted]!.title,
        'carol requested changes on PR #7',
      );
      expect(byType[ActivityType.release]!.title, 'octocat released v1.2.0');
      expect(byType[ActivityType.release]!.isMine, isTrue);
    });

    test('closed-but-unmerged PR is prClosed, not prMerged', () {
      final events = ActivityFeedService.githubEventsToActivity(
        repoDisplay: repoDisplay,
        repoKey: repoKey,
        events: [
          {
            'id': '9',
            'type': 'PullRequestEvent',
            'actor': {'login': 'alice'},
            'created_at': '2026-07-14T12:00:00Z',
            'payload': {
              'action': 'closed',
              'pull_request': {
                'number': 8,
                'title': 'Rejected',
                'merged': false,
              },
            },
          },
        ],
      );
      expect(events.single.type, ActivityType.prClosed);
      expect(events.single.title, 'alice closed PR #8');
    });
  });

  group('githubRunsToActivity', () {
    test('emits ciFailed only for completed failing runs', () {
      final events = ActivityFeedService.githubRunsToActivity(
        repoDisplay: repoDisplay,
        repoKey: repoKey,
        selfGithubLogins: {'octocat'},
        body: {
          'workflow_runs': [
            {
              'id': 101,
              'name': 'CI',
              'status': 'completed',
              'conclusion': 'failure',
              'head_branch': 'main',
              'updated_at': '2026-07-14T09:00:00Z',
              'html_url': 'https://github.com/acme/api/actions/runs/101',
              'actor': {'login': 'octocat'},
            },
            {
              'id': 102,
              'status': 'completed',
              'conclusion': 'success',
              'updated_at': '2026-07-14T09:30:00Z',
            },
            {
              'id': 103,
              'status': 'in_progress',
              'conclusion': null,
              'updated_at': '2026-07-14T09:45:00Z',
            },
          ],
        },
      );
      expect(events, hasLength(1));
      expect(events.single.type, ActivityType.ciFailed);
      expect(events.single.title, 'CI failed: CI on main');
      expect(events.single.isMine, isTrue);
    });
  });

  group('adoPrsToActivity', () {
    test('produces opened + merged/abandoned events with deep links', () {
      final events = ActivityFeedService.adoPrsToActivity(
        repoDisplay: 'contoso/web/site',
        repoKey: 'ado:contoso/web/site',
        organization: 'contoso',
        project: 'web',
        name: 'site',
        selfAdoNames: {'jane doe'},
        prs: [
          {
            'pullRequestId': 12,
            'title': 'Feature',
            'status': 'completed',
            'creationDate': '2026-07-13T08:00:00Z',
            'closedDate': '2026-07-14T08:00:00Z',
            'createdBy': {'displayName': 'Jane Doe'},
            'closedBy': {'displayName': 'Jane Doe'},
          },
          {
            'pullRequestId': 13,
            'title': 'Dropped',
            'status': 'abandoned',
            'creationDate': '2026-07-13T09:00:00Z',
            'closedDate': '2026-07-14T09:00:00Z',
            'createdBy': {'displayName': 'Sam'},
          },
        ],
      );

      final types = events.map((e) => e.type).toList();
      expect(types, contains(ActivityType.prOpened));
      expect(types, contains(ActivityType.prMerged));
      expect(types, contains(ActivityType.prClosed));
      final merged = events.firstWhere((e) => e.type == ActivityType.prMerged);
      expect(
        merged.url,
        'https://dev.azure.com/contoso/web/_git/site/pullrequest/12',
      );
      expect(merged.isMine, isTrue);
    });
  });

  group('adoPushesToActivity and adoBuildsToActivity', () {
    test('push events carry the branch', () {
      final events = ActivityFeedService.adoPushesToActivity(
        repoDisplay: 'contoso/web/site',
        repoKey: 'ado:contoso/web/site',
        organization: 'contoso',
        project: 'web',
        name: 'site',
        body: {
          'value': [
            {
              'pushId': 5,
              'date': '2026-07-14T07:00:00Z',
              'pushedBy': {'displayName': 'Jane Doe'},
              'refUpdates': [
                {'name': 'refs/heads/main'},
              ],
            },
          ],
        },
      );
      expect(events.single.type, ActivityType.push);
      expect(events.single.title, 'Jane Doe pushed to main');
    });

    test('only failed builds become ciFailed', () {
      final events = ActivityFeedService.adoBuildsToActivity(
        repoDisplay: 'contoso/web/site',
        repoKey: 'ado:contoso/web/site',
        body: {
          'value': [
            {
              'id': 1,
              'result': 'failed',
              'finishTime': '2026-07-14T06:00:00Z',
              'definition': {'name': 'Nightly'},
              'sourceBranch': 'refs/heads/main',
              'requestedFor': {'displayName': 'Jane Doe'},
              '_links': {
                'web': {'href': 'https://dev.azure.com/contoso/web/_build/1'},
              },
            },
            {
              'id': 2,
              'result': 'succeeded',
              'finishTime': '2026-07-14T06:30:00Z',
            },
          ],
        },
      );
      expect(events, hasLength(1));
      expect(events.single.type, ActivityType.ciFailed);
      expect(events.single.title, 'CI failed: Nightly on main');
      expect(events.single.url, 'https://dev.azure.com/contoso/web/_build/1');
    });
  });

  group('mergeAndWindow', () {
    test('drops old events, dedupes by id, and sorts newest-first', () {
      final since = DateTime.parse('2026-07-01T00:00:00Z');
      ActivityEvent make(String id, String iso) => ActivityEvent(
        id: id,
        type: ActivityType.push,
        provider: 'github',
        repoKey: repoKey,
        repoDisplay: repoDisplay,
        actor: 'octocat',
        title: 't',
        subtitle: 's',
        occurredAt: DateTime.parse(iso),
      );

      final merged = ActivityFeedService.mergeAndWindow([
        make('a', '2026-07-10T00:00:00Z'),
        make('b', '2026-07-12T00:00:00Z'),
        make('a', '2026-07-10T00:00:00Z'), // duplicate id
        make('old', '2026-06-01T00:00:00Z'), // before window
      ], since);

      expect(merged.map((e) => e.id).toList(), ['b', 'a']);
    });
  });

  group('computeAll', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('merges GitHub + ADO sources and windows to the lookback', () async {
      final gh = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Acme',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final ado = await TokenStore.addToken(
        provider: TokenStore.providerAdo,
        label: 'Contoso',
        scope: 'contoso',
        secret: 'ado_secret',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({'owner': 'acme', 'repoName': 'api', 'tokenId': gh.id}),
      ]);
      await prefs.setStringList('ado_repos', [
        jsonEncode({
          'organization': 'contoso',
          'project': 'web',
          'repoName': 'site',
          'tokenId': ado.id,
        }),
      ]);

      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/repos/acme/api/events') {
          return http.Response(
            jsonEncode([
              {
                'id': '1',
                'type': 'PullRequestEvent',
                'actor': {'login': 'alice'},
                'created_at': '2026-07-14T11:00:00Z',
                'payload': {
                  'action': 'opened',
                  'pull_request': {'number': 7, 'title': 'Feat'},
                },
              },
              // Outside the 14-day window relative to the injected clock.
              {
                'id': '2',
                'type': 'PushEvent',
                'actor': {'login': 'alice'},
                'created_at': '2026-06-01T00:00:00Z',
                'payload': {'ref': 'refs/heads/main', 'size': 1},
              },
            ]),
            200,
          );
        }
        if (path == '/repos/acme/api/actions/runs') {
          return http.Response(jsonEncode({'workflow_runs': []}), 200);
        }
        if (path == '/contoso/web/_apis/git/repositories/site/pullrequests') {
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'pullRequestId': 12,
                  'title': 'Ship',
                  'status': 'completed',
                  'creationDate': '2026-07-13T08:00:00Z',
                  'closedDate': '2026-07-14T08:00:00Z',
                  'createdBy': {'displayName': 'Jane Doe'},
                },
              ],
            }),
            200,
          );
        }
        if (path == '/contoso/web/_apis/git/repositories/site/pushes') {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        if (path == '/contoso/web/_apis/git/repositories/site') {
          return http.Response(jsonEncode({'id': 'guid-1'}), 200);
        }
        if (path == '/contoso/web/_apis/build/builds') {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        return http.Response('{}', 404);
      });

      final result = await ActivityFeedService.computeAll(
        client: client,
        now: DateTime.parse('2026-07-15T12:00:00Z'),
      );
      final events = result.events;

      // The June push is windowed out; GitHub PR-opened + ADO PR opened/merged
      // remain (3 events), newest-first.
      expect(result.failedSources, 0);
      expect(events, hasLength(3));
      expect(events.any((e) => e.provider == 'github'), isTrue);
      expect(events.any((e) => e.provider == 'ado'), isTrue);
      expect(events.every((e) => e.occurredAt.year == 2026), isTrue);
      expect(events.any((e) => e.type == ActivityType.push), isFalse);
      // Sorted strictly newest-first.
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i - 1].occurredAt.isBefore(events[i].occurredAt),
          isFalse,
        );
      }
    });

    test('reports failedSources when a source errors', () async {
      final gh = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Acme',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({'owner': 'acme', 'repoName': 'api', 'tokenId': gh.id}),
      ]);

      final client = MockClient((request) async {
        if (request.url.path == '/repos/acme/api/events') {
          return http.Response('forbidden', 403);
        }
        // Actions runs succeed but are empty.
        return http.Response(jsonEncode({'workflow_runs': []}), 200);
      });

      final result = await ActivityFeedService.computeAll(
        client: client,
        now: DateTime.parse('2026-07-15T12:00:00Z'),
      );

      expect(result.events, isEmpty);
      expect(result.failedSources, greaterThanOrEqualTo(1));
    });
  });
}
