import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/ci_run_history.dart';

CiRunSample _s(
  String workflow,
  String outcome,
  DateTime finishedAt, {
  String repoKey = 'github:owner/name',
  String repoDisplay = 'owner/name',
}) => CiRunSample(
  provider: 'github',
  repoKey: repoKey,
  repoDisplay: repoDisplay,
  workflow: workflow,
  runKey: '$repoKey:$workflow:${finishedAt.millisecondsSinceEpoch}',
  outcome: outcome,
  conclusion: outcome,
  finishedAt: finishedAt,
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
  });
}
