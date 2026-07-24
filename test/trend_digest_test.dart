import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/ci_run_history.dart';
import 'package:kode_radar/cycle_time.dart';
import 'package:kode_radar/team.dart';
import 'package:kode_radar/trend_digest.dart';

MergedPrSample _pr({
  required int number,
  required String repoKey,
  required DateTime createdAt,
  required DateTime mergedAt,
  DateTime? firstReviewAt,
}) => MergedPrSample(
  provider: 'github',
  repoKey: repoKey,
  repoDisplay: repoKey,
  prKey: '$repoKey:$number',
  createdAt: createdAt,
  mergedAt: mergedAt,
  firstReviewAt: firstReviewAt,
);

CiRunSample _run({
  required String repoKey,
  required String runKey,
  required String outcome,
  required DateTime finishedAt,
}) => CiRunSample(
  provider: 'github',
  repoKey: repoKey,
  repoDisplay: repoKey,
  workflow: 'CI',
  runKey: runKey,
  outcome: outcome,
  conclusion: outcome,
  finishedAt: finishedAt,
);

void main() {
  final now = DateTime.utc(2026, 3, 15, 12);
  const window = Duration(days: 7);
  final team = const Team(id: 't1', name: 'Platform', repoKeys: {'github:o/a'});

  group('periodKeyFor', () {
    test('same bucket for two instants in the same window', () {
      final a = DateTime.utc(2026, 3, 15, 1);
      final b = DateTime.utc(2026, 3, 15, 23);
      expect(
        TrendDigest.periodKeyFor(a, window),
        TrendDigest.periodKeyFor(b, window),
      );
    });
    test('different bucket a window later', () {
      final a = DateTime.utc(2026, 3, 15);
      final b = DateTime.utc(2026, 3, 25);
      expect(
        TrendDigest.periodKeyFor(a, window),
        isNot(TrendDigest.periodKeyFor(b, window)),
      );
    });
  });

  group('compare — windows', () {
    test('splits merges into current vs previous window', () {
      final samples = [
        // current window (last 7d): merged 2 days ago
        _pr(
          number: 1,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 3)),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
        // previous window (7-14d ago): merged 10 days ago
        _pr(
          number: 2,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 11)),
          mergedAt: now.subtract(const Duration(days: 10)),
        ),
        // outside both windows (merged 20 days ago)
        _pr(
          number: 3,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 21)),
          mergedAt: now.subtract(const Duration(days: 20)),
        ),
      ];
      final trends = TrendDigest.compare(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(trends, hasLength(1));
      expect(trends.single.current.mergedCount, 1);
      expect(trends.single.previous.mergedCount, 1);
    });

    test('drops teams with no data in either window', () {
      final trends = TrendDigest.compare(
        teams: [team],
        cycleSamples: const [],
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(trends, isEmpty);
    });

    test('ignores repos not in the team', () {
      final samples = [
        _pr(
          number: 1,
          repoKey: 'github:o/other',
          createdAt: now.subtract(const Duration(days: 3)),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
      ];
      final trends = TrendDigest.compare(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(trends, isEmpty);
    });
  });

  group('regressions — merge/review time', () {
    test('flags merge time up past ratio + absolute floor', () {
      final samples = [
        // previous window: two PRs merged in ~1h each
        _pr(
          number: 1,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 10, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 10)),
        ),
        _pr(
          number: 2,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 9, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 9)),
        ),
        // current window: two PRs merged in ~2 days each (way up)
        _pr(
          number: 3,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 4)),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
        _pr(
          number: 4,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 5)),
          mergedAt: now.subtract(const Duration(days: 3)),
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(regs.map((r) => r.kind), contains(RegressionKind.mergeTimeUp));
      expect(regs.first.key, startsWith(TrendDigest.periodKeyFor(now, window)));
    });

    test('does not flag a small merge-time increase (below floor)', () {
      final samples = [
        _pr(
          number: 1,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 10, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 10)),
        ),
        _pr(
          number: 2,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 9, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 9)),
        ),
        // current: ~1h -> ~1h5m — ratio < 1.3 and delta < 4h
        _pr(
          number: 3,
          repoKey: 'github:o/a',
          createdAt: now.subtract(
            const Duration(days: 2, hours: 1, minutes: 5),
          ),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
        _pr(
          number: 4,
          repoKey: 'github:o/a',
          createdAt: now.subtract(
            const Duration(days: 3, hours: 1, minutes: 5),
          ),
          mergedAt: now.subtract(const Duration(days: 3)),
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(regs, isEmpty);
    });

    test('does not flag a duration jump backed by a single PR per window', () {
      // One PR each window with a huge jump: real ratio/floor breach, but the
      // min-sample guard suppresses it (outlier protection).
      final samples = [
        _pr(
          number: 1,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 10, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 10)),
        ),
        _pr(
          number: 2,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 4)),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(regs, isEmpty);
    });

    test('flags review latency up', () {
      final samples = [
        _pr(
          number: 1,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 10, hours: 2)),
          firstReviewAt: now.subtract(const Duration(days: 10, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 10)),
        ),
        _pr(
          number: 2,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 9, hours: 2)),
          firstReviewAt: now.subtract(const Duration(days: 9, hours: 1)),
          mergedAt: now.subtract(const Duration(days: 9)),
        ),
        _pr(
          number: 3,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 3)),
          firstReviewAt: now.subtract(const Duration(days: 2)),
          mergedAt: now.subtract(const Duration(days: 1)),
        ),
        _pr(
          number: 4,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 4)),
          firstReviewAt: now.subtract(const Duration(days: 3)),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(regs.map((r) => r.kind), contains(RegressionKind.reviewLatencyUp));
    });

    test('no regression without a previous-window baseline', () {
      final samples = [
        _pr(
          number: 3,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 4)),
          mergedAt: now.subtract(const Duration(days: 2)),
        ),
        _pr(
          number: 4,
          repoKey: 'github:o/a',
          createdAt: now.subtract(const Duration(days: 5)),
          mergedAt: now.subtract(const Duration(days: 3)),
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: samples,
        ciSamples: const [],
        now: now,
        window: window,
      );
      expect(regs, isEmpty);
    });
  });

  group('regressions — CI failure rate', () {
    List<CiRunSample> runs({
      required DateTime base,
      required int total,
      required int failures,
    }) => [
      for (var i = 0; i < total; i++)
        _run(
          repoKey: 'github:o/a',
          runKey: 'github:o/a:${base.millisecondsSinceEpoch}:$i',
          outcome: i < failures ? CiOutcome.failure : CiOutcome.success,
          finishedAt: base.add(Duration(minutes: i)),
        ),
    ];

    test('flags a large jump in failure rate with enough runs', () {
      final ci = [
        // previous: 1/10 failed (10%)
        ...runs(
          base: now.subtract(const Duration(days: 10)),
          total: 10,
          failures: 1,
        ),
        // current: 5/10 failed (50%) — up 40 pts, above floor, >=5 runs
        ...runs(
          base: now.subtract(const Duration(days: 2)),
          total: 10,
          failures: 5,
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: const [],
        ciSamples: ci,
        now: now,
        window: window,
      );
      expect(regs.map((r) => r.kind), contains(RegressionKind.ciFailureRateUp));
    });

    test('does not flag when too few current runs', () {
      final ci = [
        ...runs(
          base: now.subtract(const Duration(days: 10)),
          total: 10,
          failures: 1,
        ),
        // current: 2/3 failed but only 3 completed (< min 5)
        ...runs(
          base: now.subtract(const Duration(days: 2)),
          total: 3,
          failures: 2,
        ),
      ];
      final regs = TrendDigest.regressions(
        teams: [team],
        cycleSamples: const [],
        ciSamples: ci,
        now: now,
        window: window,
      );
      expect(regs, isEmpty);
    });

    test('ignores still-running runs in the rate', () {
      final ci = [
        ...runs(
          base: now.subtract(const Duration(days: 10)),
          total: 6,
          failures: 0,
        ),
        // current: 6 completed all-fail + a running one that must not count
        ...runs(
          base: now.subtract(const Duration(days: 2)),
          total: 6,
          failures: 6,
        ),
        _run(
          repoKey: 'github:o/a',
          runKey: 'github:o/a:running',
          outcome: CiOutcome.running,
          finishedAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      final trends = TrendDigest.compare(
        teams: [team],
        cycleSamples: const [],
        ciSamples: ci,
        now: now,
        window: window,
      );
      expect(trends.single.current.ciCompleted, 6);
      expect(trends.single.current.ciFailureRate, 1.0);
    });
  });

  test('regressed teams sort before steady ones', () {
    final steady = const Team(
      id: 't2',
      name: 'AAA-Steady',
      repoKeys: {'github:o/b'},
    );
    final samples = [
      // team t1 regresses on merge time (2 PRs per window)
      _pr(
        number: 1,
        repoKey: 'github:o/a',
        createdAt: now.subtract(const Duration(days: 10, hours: 1)),
        mergedAt: now.subtract(const Duration(days: 10)),
      ),
      _pr(
        number: 2,
        repoKey: 'github:o/a',
        createdAt: now.subtract(const Duration(days: 9, hours: 1)),
        mergedAt: now.subtract(const Duration(days: 9)),
      ),
      _pr(
        number: 3,
        repoKey: 'github:o/a',
        createdAt: now.subtract(const Duration(days: 4)),
        mergedAt: now.subtract(const Duration(days: 2)),
      ),
      _pr(
        number: 4,
        repoKey: 'github:o/a',
        createdAt: now.subtract(const Duration(days: 5)),
        mergedAt: now.subtract(const Duration(days: 3)),
      ),
      // team t2 steady
      _pr(
        number: 5,
        repoKey: 'github:o/b',
        createdAt: now.subtract(const Duration(days: 3)),
        mergedAt: now.subtract(const Duration(days: 2, hours: 23)),
      ),
    ];
    final trends = TrendDigest.compare(
      teams: [steady, team],
      cycleSamples: samples,
      ciSamples: const [],
      now: now,
      window: window,
    );
    expect(trends.first.teamId, 't1', reason: 'regressed team sorts first');
  });
}
