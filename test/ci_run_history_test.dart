import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/ci_run_history.dart';

CiRunSample _s(
  String workflow,
  String outcome,
  DateTime finishedAt, {
  String repoKey = 'github:owner/name',
  String repoDisplay = 'owner/name',
  int? durationMs,
}) => CiRunSample(
  provider: 'github',
  repoKey: repoKey,
  repoDisplay: repoDisplay,
  workflow: workflow,
  runKey: '$repoKey:$workflow:${finishedAt.millisecondsSinceEpoch}',
  outcome: outcome,
  conclusion: outcome,
  finishedAt: finishedAt,
  durationMs: durationMs,
);

void main() {
  final base = DateTime.utc(2026, 3, 1, 12);
  DateTime ago(int hours) => base.subtract(Duration(hours: hours));

  group('CiWorkflowTrend.aggregate', () {
    test('groups by workflow and counts completed outcomes', () {
      final trends = CiWorkflowTrend.aggregate([
        _s('build', CiOutcome.success, ago(1)),
        _s('build', CiOutcome.failure, ago(2)),
        _s('build', CiOutcome.running, ago(0)), // excluded from totals
        _s('deploy', CiOutcome.success, ago(3)),
      ], now: base);

      final build = trends.firstWhere((t) => t.workflow == 'build');
      expect(build.total, 2);
      expect(build.successes, 1);
      expect(build.failures, 1);
      // Newest run (running) leads the outcome strip and lastOutcome.
      expect(build.lastOutcome, CiOutcome.running);
      expect(build.recentOutcomes.first, CiOutcome.running);

      final deploy = trends.firstWhere((t) => t.workflow == 'deploy');
      expect(deploy.total, 1);
      expect(deploy.failureRate, 0);
    });

    test(
      'does not label a recovered workflow (latest run passed) as failing',
      () {
        // Newest-first: latest completed run is a success despite older failures.
        final trends = CiWorkflowTrend.aggregate([
          _s('recovered', CiOutcome.success, ago(1)),
          _s('recovered', CiOutcome.failure, ago(2)),
          _s('recovered', CiOutcome.failure, ago(3)),
          _s('recovered', CiOutcome.failure, ago(4)),
        ], now: base);
        final t = trends.single;
        expect(t.failureRate, closeTo(0.75, 1e-9));
        expect(t.lastCompletedOutcome, CiOutcome.success);
        expect(t.isChronicallyFailing, isFalse);
      },
    );

    test('flags a chronically-failing workflow, not a flaky one', () {
      final trends = CiWorkflowTrend.aggregate([
        _s('nightly', CiOutcome.failure, ago(1)),
        _s('nightly', CiOutcome.failure, ago(2)),
        _s('nightly', CiOutcome.failure, ago(3)),
        _s('nightly', CiOutcome.failure, ago(4)),
      ], now: base);
      final t = trends.single;
      expect(t.failureRate, 1.0);
      expect(t.flips, 0);
      expect(t.isChronicallyFailing, isTrue);
      expect(t.isFlaky, isFalse);
    });

    test('flags a flaky workflow that alternates pass/fail', () {
      final trends = CiWorkflowTrend.aggregate([
        _s('flappy', CiOutcome.success, ago(1)),
        _s('flappy', CiOutcome.failure, ago(2)),
        _s('flappy', CiOutcome.success, ago(3)),
        _s('flappy', CiOutcome.failure, ago(4)),
      ], now: base);
      final t = trends.single;
      expect(t.flips, 3);
      expect(t.flakeRate, closeTo(1.0, 1e-9));
      expect(t.isFlaky, isTrue);
      // Flaky and chronic are mutually exclusive (flip-rate split).
      expect(t.isChronicallyFailing, isFalse);
    });

    test('a lone pass/fail pair is not yet flaky (min sample)', () {
      final trends = CiWorkflowTrend.aggregate([
        _s('young', CiOutcome.success, ago(1)),
        _s('young', CiOutcome.failure, ago(2)),
      ], now: base);
      final t = trends.single;
      expect(t.isFlaky, isFalse);
      expect(t.isChronicallyFailing, isFalse);
    });

    test('groups by workflow id, not name (rename-safe, dup-name-safe)', () {
      CiRunSample s(String name, String id, String outcome, DateTime at) =>
          CiRunSample(
            provider: 'github',
            repoKey: 'github:o/r',
            repoDisplay: 'o/r',
            workflow: name,
            workflowId: id,
            runKey: 'github:o/r:$id:${at.millisecondsSinceEpoch}',
            outcome: outcome,
            conclusion: outcome,
            finishedAt: at,
          );
      final trends = CiWorkflowTrend.aggregate([
        // Same id, different display name (a rename) -> one group.
        s('CI', '1', CiOutcome.success, ago(1)),
        s('Build', '1', CiOutcome.failure, ago(2)),
        // Same name as the first, different id -> a separate group.
        s('CI', '2', CiOutcome.success, ago(1)),
      ], now: base);
      expect(trends, hasLength(2));
      // id 1 collapses two differently-named runs into one trend.
      final merged = trends.firstWhere((t) => t.total == 2);
      expect(merged.successes, 1);
      expect(merged.failures, 1);
      // id 2 stays its own single-run trend despite sharing the name "CI".
      expect(trends.firstWhere((t) => t.total == 1).successes, 1);
    });

    test('a workflow id does not collide with an id-less same-string name', () {
      final trends = CiWorkflowTrend.aggregate([
        // workflowId "5" ...
        CiRunSample(
          provider: 'github',
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
          workflow: 'Deploy',
          workflowId: '5',
          runKey: 'github:o/r:a',
          outcome: CiOutcome.success,
          conclusion: 'success',
          finishedAt: ago(1),
        ),
        // ... vs an id-less workflow literally named "5".
        CiRunSample(
          provider: 'github',
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
          workflow: '5',
          runKey: 'github:o/r:b',
          outcome: CiOutcome.failure,
          conclusion: 'failure',
          finishedAt: ago(2),
        ),
      ], now: base);
      // Namespaced group keys keep them separate.
      expect(trends, hasLength(2));
    });

    test('small samples rank below a confident chronic failure', () {
      final trends = CiWorkflowTrend.aggregate([
        // 2-run 100% fail: high rate but low confidence.
        _s(
          'tiny',
          CiOutcome.failure,
          ago(1),
          repoKey: 'github:o/tiny',
          repoDisplay: 'o/tiny',
        ),
        _s(
          'tiny',
          CiOutcome.failure,
          ago(2),
          repoKey: 'github:o/tiny',
          repoDisplay: 'o/tiny',
        ),
        // 4-run 100% fail: chronic, more confident.
        _s('chronic', CiOutcome.failure, ago(1)),
        _s('chronic', CiOutcome.failure, ago(2)),
        _s('chronic', CiOutcome.failure, ago(3)),
        _s('chronic', CiOutcome.failure, ago(4)),
      ], now: base);
      expect(trends.first.workflow, 'chronic');
      expect(trends.first.isChronicallyFailing, isTrue);
      final tiny = trends.firstWhere((t) => t.workflow == 'tiny');
      expect(tiny.isChronicallyFailing, isFalse);
      expect(trends.first.severity, greaterThan(tiny.severity));
    });

    test('excludes runs finished before the window', () {
      final trends = CiWorkflowTrend.aggregate(
        [
          _s(
            'build',
            CiOutcome.failure,
            base.subtract(const Duration(days: 40)),
          ),
          _s('build', CiOutcome.success, ago(1)),
        ],
        now: base,
        window: const Duration(days: 30),
      );
      expect(trends.single.total, 1);
      expect(trends.single.failures, 0);
    });

    test('sorts worst-first (highest severity leads)', () {
      final trends = CiWorkflowTrend.aggregate([
        // healthy: all green
        _s('green', CiOutcome.success, ago(1)),
        _s('green', CiOutcome.success, ago(2)),
        _s('green', CiOutcome.success, ago(3)),
        // failing: all red
        _s(
          'red',
          CiOutcome.failure,
          ago(1),
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
        ),
        _s(
          'red',
          CiOutcome.failure,
          ago(2),
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
        ),
        _s(
          'red',
          CiOutcome.failure,
          ago(3),
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
        ),
      ], now: base);
      expect(trends.first.workflow, 'red');
      expect(trends.last.workflow, 'green');
    });

    test('computes median duration over successful runs', () {
      final trends = CiWorkflowTrend.aggregate([
        _s('build', CiOutcome.success, ago(1), durationMs: 100),
        _s('build', CiOutcome.success, ago(2), durationMs: 300),
        _s('build', CiOutcome.success, ago(3), durationMs: 200),
        // A failure's duration is ignored for the typical-duration signal.
        _s('build', CiOutcome.failure, ago(4), durationMs: 9999),
      ], now: base);
      expect(trends.single.medianDurationMs, 200);
    });

    test('flags a slowing workflow (recent runs slower than older)', () {
      // 8 timed successes, newest-first: recent half 500s, older half 200s —
      // a 2.5x, +300s increase (clears both the ratio and absolute floors).
      final trends = CiWorkflowTrend.aggregate([
        for (var i = 0; i < 4; i++)
          _s('build', CiOutcome.success, ago(i + 1), durationMs: 500000),
        for (var i = 4; i < 8; i++)
          _s('build', CiOutcome.success, ago(i + 1), durationMs: 200000),
      ], now: base);
      final t = trends.single;
      expect(t.slowdownRatio, closeTo(2.5, 1e-9));
      expect(t.isSlowing, isTrue);
    });

    test('a large relative but tiny absolute change is not slowing', () {
      // 2s -> 3s is 1.5x but only +1s: below the absolute delta floor.
      final trends = CiWorkflowTrend.aggregate([
        for (var i = 0; i < 4; i++)
          _s('build', CiOutcome.success, ago(i + 1), durationMs: 3000),
        for (var i = 4; i < 8; i++)
          _s('build', CiOutcome.success, ago(i + 1), durationMs: 2000),
      ], now: base);
      expect(trends.single.slowdownRatio, closeTo(1.5, 1e-9));
      expect(trends.single.isSlowing, isFalse);
    });

    test('a steady workflow is not slowing', () {
      final trends = CiWorkflowTrend.aggregate([
        for (var i = 0; i < 8; i++)
          _s('build', CiOutcome.success, ago(i + 1), durationMs: 300000),
      ], now: base);
      expect(trends.single.isSlowing, isFalse);
      expect(trends.single.slowdownRatio, closeTo(1.0, 1e-9));
    });

    test('slowdown needs a minimum sample; typical needs 3 timed runs', () {
      final trends = CiWorkflowTrend.aggregate([
        _s('build', CiOutcome.success, ago(1), durationMs: 900000),
        _s('build', CiOutcome.success, ago(2), durationMs: 100000),
      ], now: base);
      expect(trends.single.slowdownRatio, isNull);
      expect(trends.single.isSlowing, isFalse);
      // Only 2 timed runs -> no "typical" duration shown.
      expect(trends.single.medianDurationMs, isNull);
    });

    test('slowing ranks above healthy but below flaky/failing', () {
      CiRunSample s(
        String wf,
        String outcome,
        int i, {
        int? durationMs,
        String repoKey = 'github:o/r',
        String repoDisplay = 'o/r',
      }) => _s(
        wf,
        outcome,
        ago(i),
        durationMs: durationMs,
        repoKey: repoKey,
        repoDisplay: repoDisplay,
      );
      final trends = CiWorkflowTrend.aggregate([
        // healthy green (no duration)
        for (var i = 1; i <= 3; i++) s('green', CiOutcome.success, i),
        // slowing but green
        for (var i = 1; i <= 4; i++)
          s(
            'slow',
            CiOutcome.success,
            i,
            durationMs: 600000,
            repoKey: 'github:o/s',
            repoDisplay: 'o/s',
          ),
        for (var i = 5; i <= 8; i++)
          s(
            'slow',
            CiOutcome.success,
            i,
            durationMs: 200000,
            repoKey: 'github:o/s',
            repoDisplay: 'o/s',
          ),
        // flaky (alternating), repo o/f
        for (var i = 1; i <= 4; i++)
          s(
            'flaky',
            i.isEven ? CiOutcome.success : CiOutcome.failure,
            i,
            repoKey: 'github:o/f',
            repoDisplay: 'o/f',
          ),
      ], now: base);
      final order = trends.map((t) => t.workflow).toList();
      expect(order.indexOf('flaky'), lessThan(order.indexOf('slow')));
      expect(order.indexOf('slow'), lessThan(order.indexOf('green')));
    });
  });
}
