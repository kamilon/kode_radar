import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/issue_service.dart';
import 'package:kode_radar/repo_store.dart';
import 'package:kode_radar/team.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 3, 1);

  group('issuesFromGithubGraphql', () {
    test('reads exact open + stale counts and the oldest issue age', () {
      final body = jsonDecode('''
      {"data":{
        "repository":{
          "issues":{"totalCount":12},
          "oldest":{"nodes":[{"createdAt":"2025-12-01T00:00:00Z"}]}
        },
        "stale":{"issueCount":4}
      }}
      ''');
      final r = IssueService.issuesFromGithubGraphql(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      )!;
      expect(r.openCount, 12);
      expect(r.staleCount, 4);
      expect(r.oldestAgeDays, now.difference(DateTime.utc(2025, 12, 1)).inDays);
      expect(r.isEmpty, isFalse);
    });

    test('zero open issues → empty snapshot, null oldest', () {
      final body = jsonDecode('''
      {"data":{
        "repository":{"issues":{"totalCount":0},"oldest":{"nodes":[]}},
        "stale":{"issueCount":0}
      }}
      ''');
      final r = IssueService.issuesFromGithubGraphql(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      )!;
      expect(r.openCount, 0);
      expect(r.staleCount, 0);
      expect(r.oldestAgeDays, isNull);
      expect(r.isEmpty, isTrue);
    });

    test('missing repository (malformed) → null (a failed fetch)', () {
      final r = IssueService.issuesFromGithubGraphql(
        jsonDecode('{"data":{"repository":null}}'),
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      );
      expect(r, isNull);
    });

    test('missing totalCount → null', () {
      final r = IssueService.issuesFromGithubGraphql(
        jsonDecode('{"data":{"repository":{"issues":{}}}}'),
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      );
      expect(r, isNull);
    });

    test('absent stale field defaults stale to 0', () {
      final body = jsonDecode('''
      {"data":{"repository":{
        "issues":{"totalCount":3},
        "oldest":{"nodes":[{"createdAt":"2026-02-27T00:00:00Z"}]}
      }}}
      ''');
      final r = IssueService.issuesFromGithubGraphql(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      )!;
      expect(r.openCount, 3);
      expect(r.staleCount, 0);
    });
  });

  group('staleCutoffDate', () {
    test('is 30 days before now, YYYY-MM-DD (UTC)', () {
      expect(
        IssueService.staleCutoffDate(DateTime.utc(2026, 3, 1)),
        '2026-01-30',
      );
      expect(
        IssueService.staleCutoffDate(DateTime.utc(2026, 1, 5)),
        '2025-12-06',
      );
    });
  });

  group('IssueStats', () {
    RepoIssues snap(
      String key, {
      required int open,
      int stale = 0,
      int? oldest,
    }) => RepoIssues(
      repoKey: key,
      repoDisplay: key,
      openCount: open,
      staleCount: stale,
      oldestAgeDays: oldest,
    );

    test('rankRepos drops empty and sorts most-stale then most-open', () {
      final ranked = IssueStats.rankRepos([
        snap('github:o/empty', open: 0),
        snap('github:o/a', open: 10, stale: 1),
        snap('github:o/b', open: 3, stale: 5),
        snap('github:o/c', open: 8, stale: 1),
      ]);
      expect(ranked.map((r) => r.repoKey), [
        'github:o/b', // most stale (5)
        'github:o/a', // stale 1, tie broken by open desc: 10 > 8
        'github:o/c', // stale 1, open 8
      ]);
    });

    test('perTeam sums member repos and drops issue-free teams', () {
      final snapshots = [
        snap('github:o/a', open: 5, stale: 2),
        snap('github:o/b', open: 3, stale: 1),
        snap('github:o/c', open: 0),
      ];
      final teams = [
        const Team(
          id: 't1',
          name: 'Platform',
          repoKeys: {'github:o/a', 'github:o/b'},
        ),
        const Team(id: 't2', name: 'Quiet', repoKeys: {'github:o/c'}),
      ];
      final result = IssueStats.perTeam(snapshots, teams);
      expect(result, hasLength(1));
      expect(result.single.teamId, 't1');
      expect(result.single.openCount, 8);
      expect(result.single.staleCount, 3);
    });
  });

  group('computeAll', () {
    test('malformed monitored entries count toward failedRepos', () async {
      // Malformed entries never create a fetch task, so no network is hit;
      // they must still be reported as unavailable so the partial-coverage
      // signal is honest.
      SharedPreferences.setMockInitialValues({
        RepoStore.githubKey: <String>[
          'not json',
          '{"owner":"o"}', // missing repoName
        ],
      });
      final result = await IssueService.computeAll(now: now);
      expect(result.snapshots, isEmpty);
      expect(result.failedRepos, 2);
    });
  });
}
