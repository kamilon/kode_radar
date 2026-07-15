import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/activity_service.dart';
import 'package:kode_radar/digest_service.dart';
import 'package:kode_radar/metric_snapshot.dart';
import 'package:kode_radar/team.dart';

void main() {
  test('totals are summed across all activities', () {
    final digest = DigestService.buildDigest(
      teams: const [],
      activities: [
        _activity(repoKey: 'github:acme/app', openPrs: 2, needsReview: 1),
        _activity(repoKey: 'github:acme/api', openPrs: 3, needsReview: 2),
      ],
      history: const {},
      now: DateTime.parse('2026-07-14T12:00:00Z'),
    );

    expect(digest.totalOpenPrs, 5);
    expect(digest.totalNeedsReview, 3);
  });

  test('per-team lines sum activity for member repos', () {
    final digest = DigestService.buildDigest(
      teams: const [
        Team(
          id: 'platform',
          name: 'Platform',
          repoKeys: {'github:acme/app', 'github:acme/api'},
        ),
        Team(id: 'tools', name: 'Tools', repoKeys: {'github:acme/tools'}),
      ],
      activities: [
        _activity(
          repoKey: 'github:acme/app',
          openPrs: 2,
          needsReview: 1,
          activityScore: 4,
        ),
        _activity(
          repoKey: 'github:acme/api',
          openPrs: 3,
          needsReview: 2,
          activityScore: 6,
        ),
        _activity(
          repoKey: 'github:acme/tools',
          openPrs: 1,
          needsReview: 0,
          activityScore: 2,
        ),
      ],
      history: const {},
      now: DateTime.parse('2026-07-14T12:00:00Z'),
    );

    final platform = digest.teamLines.singleWhere(
      (line) => line.label == 'Platform',
    );
    expect(platform.openPrs, 5);
    expect(platform.needsReview, 3);
    expect(platform.activityScore, 10);
  });

  test(
    'activityDelta compares current score to oldest in-window snapshots',
    () {
      final now = DateTime.parse('2026-07-14T12:00:00Z');
      final digest = DigestService.buildDigest(
        teams: const [
          Team(
            id: 'platform',
            name: 'Platform',
            repoKeys: {'github:acme/app', 'github:acme/api'},
          ),
        ],
        activities: [
          _activity(repoKey: 'github:acme/app', activityScore: 10),
          _activity(repoKey: 'github:acme/api', activityScore: 8),
        ],
        history: {
          'github:acme/app': [
            MetricSnapshot(
              at: now.subtract(const Duration(days: 8)),
              openPrs: 0,
              needsReview: 0,
              activityScore: 100,
            ),
            MetricSnapshot(
              at: now.subtract(const Duration(days: 6)),
              openPrs: 0,
              needsReview: 0,
              activityScore: 3,
            ),
            MetricSnapshot(
              at: now.subtract(const Duration(days: 2)),
              openPrs: 0,
              needsReview: 0,
              activityScore: 7,
            ),
          ],
          'github:acme/api': [
            MetricSnapshot(
              at: now.subtract(const Duration(days: 1)),
              openPrs: 0,
              needsReview: 0,
              activityScore: 4,
            ),
          ],
        },
        now: now,
      );

      expect(digest.teamLines.single.activityDelta, 11);
    },
  );

  test('movers sort by magnitude (rises and drops) and limit to five', () {
    final now = DateTime.parse('2026-07-14T12:00:00Z');
    // Each team's repo has a baseline of 10 five days ago; current score is
    // 10 + delta, so the resulting deltas are [1,2,3,4,5,-20,0].
    final deltas = [1, 2, 3, 4, 5, -20, 0];
    final teams = List.generate(
      7,
      (index) => Team(
        id: 'team-$index',
        name: 'Team $index',
        repoKeys: {'repo-$index'},
      ),
    );
    final activities = List.generate(
      7,
      (index) =>
          _activity(repoKey: 'repo-$index', activityScore: 10 + deltas[index]),
    );
    final history = {
      for (var index = 0; index < 7; index++)
        'repo-$index': [
          MetricSnapshot(
            at: now.subtract(const Duration(days: 5)),
            openPrs: 0,
            needsReview: 0,
            activityScore: 10,
          ),
        ],
    };

    final digest = DigestService.buildDigest(
      teams: teams,
      activities: activities,
      history: history,
      now: now,
    );

    // Team 6 (delta 0) is excluded; the top 5 by magnitude include the big drop.
    expect(digest.movers, hasLength(5));
    expect(digest.movers.map((line) => line.label), [
      'Team 5',
      'Team 4',
      'Team 3',
      'Team 2',
      'Team 1',
    ]);
    expect(digest.movers.first.activityDelta, -20);
  });

  test('no in-window history means no movers (no fabricated trend)', () {
    final now = DateTime.parse('2026-07-14T12:00:00Z');
    final teams = List.generate(
      3,
      (index) => Team(
        id: 'team-$index',
        name: 'Team $index',
        repoKeys: {'repo-$index'},
      ),
    );
    final activities = List.generate(
      3,
      (index) =>
          _activity(repoKey: 'repo-$index', activityScore: (index + 1) * 5),
    );

    final digest = DigestService.buildDigest(
      teams: teams,
      activities: activities,
      history: const {},
      now: now,
    );

    expect(digest.movers, isEmpty);
    expect(digest.teamLines.every((line) => line.activityDelta == 0), isTrue);
  });

  test('errored repos are excluded from totals and team sums', () {
    final now = DateTime.parse('2026-07-14T12:00:00Z');
    final digest = DigestService.buildDigest(
      teams: const [
        Team(id: 'platform', name: 'Platform', repoKeys: {'ok', 'broken'}),
      ],
      activities: [
        _activity(repoKey: 'ok', openPrs: 4, needsReview: 2, activityScore: 9),
        _activity(
          repoKey: 'broken',
          openPrs: 0,
          needsReview: 0,
          activityScore: 0,
          error: 'GitHub returned 500',
        ),
      ],
      history: const {},
      now: now,
    );

    // The errored repo contributes nothing (no false healthy zeros).
    expect(digest.totalOpenPrs, 4);
    expect(digest.totalNeedsReview, 2);
    final platform = digest.teamLines.single;
    expect(platform.openPrs, 4);
    expect(platform.activityScore, 9);
  });

  test('empty inputs return a zeroed digest without throwing', () {
    final now = DateTime.parse('2026-07-14T12:00:00Z');

    final digest = DigestService.buildDigest(
      teams: const [],
      activities: const [],
      history: const {},
      now: now,
    );

    expect(digest.generatedAt, now);
    expect(digest.window, const Duration(days: 7));
    expect(digest.totalOpenPrs, 0);
    expect(digest.totalNeedsReview, 0);
    expect(digest.teamLines, isEmpty);
    expect(digest.movers, isEmpty);
  });
}

RepoActivity _activity({
  required String repoKey,
  int openPrs = 0,
  int needsReview = 0,
  num activityScore = 0,
  String? error,
}) {
  return RepoActivity(
    repoKey: repoKey,
    provider: 'github',
    displayName: repoKey,
    url: 'https://example.com/$repoKey',
    openPrCount: openPrs,
    needsReviewCount: needsReview,
    oldestOpenPrAgeDays: null,
    lastActivity: null,
    ciStatus: 'unknown',
    contributors: const [],
    activityScore: activityScore,
    error: error,
  );
}
