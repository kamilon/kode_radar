// Period-over-period (this week vs last week) per-team trend comparison and
// regression detection for the manager digest: it rolls the accumulated
// merged-PR (cycle-time) and CI-run histories into a current- and previous-
// window summary per team, computes the deltas a manager cares about (merge
// throughput, review latency, merge time, CI failure rate), and flags the ones
// that regressed past a threshold. Pure and provider-agnostic so it's easy to
// unit-test and reuse from both the in-app view and the alert path.

import 'ci_run_history.dart';
import 'cycle_time.dart';
import 'team.dart';

/// The kinds of regression the digest can flag. The string value is stable and
/// used to build de-duplication keys for alerting, so don't rename casually.
enum RegressionKind {
  reviewLatencyUp('reviewLatencyUp'),
  mergeTimeUp('mergeTimeUp'),
  ciFailureRateUp('ciFailureRateUp');

  const RegressionKind(this.id);
  final String id;
}

/// One team's roll-up over a single window.
class TeamPeriodStats {
  const TeamPeriodStats({
    required this.mergedCount,
    required this.reviewedCount,
    required this.medianTimeToFirstReviewMs,
    required this.medianTimeToMergeMs,
    required this.ciCompleted,
    required this.ciFailures,
  });

  final int mergedCount;
  final int reviewedCount;
  final int? medianTimeToFirstReviewMs;
  final int? medianTimeToMergeMs;

  /// Completed (pass/fail) CI runs on tracked repos in the window.
  final int ciCompleted;
  final int ciFailures;

  /// Fraction of completed CI runs that failed, or null when none completed.
  double? get ciFailureRate =>
      ciCompleted == 0 ? null : ciFailures / ciCompleted;

  bool get isEmpty => mergedCount == 0 && ciCompleted == 0;

  static const TeamPeriodStats empty = TeamPeriodStats(
    mergedCount: 0,
    reviewedCount: 0,
    medianTimeToFirstReviewMs: null,
    medianTimeToMergeMs: null,
    ciCompleted: 0,
    ciFailures: 0,
  );
}

/// A flagged regression for one team + metric, with the values behind it and a
/// stable [key] for de-duplicating alerts.
class TrendRegression {
  const TrendRegression({
    required this.teamId,
    required this.teamName,
    required this.kind,
    required this.summary,
    required this.key,
  });

  final String teamId;
  final String teamName;
  final RegressionKind kind;

  /// Short human-readable description, e.g. "merge time 2d → 3d 4h".
  final String summary;

  /// Stable de-dup key: `<periodKey>|<teamId>|<kind>`.
  final String key;
}

/// A team's current- vs previous-window stats plus any regressions.
class TeamTrend {
  const TeamTrend({
    required this.teamId,
    required this.teamName,
    required this.current,
    required this.previous,
    required this.regressions,
  });

  final String teamId;
  final String teamName;
  final TeamPeriodStats current;
  final TeamPeriodStats previous;
  final List<TrendRegression> regressions;

  bool get hasRegression => regressions.isNotEmpty;

  /// True when neither window has any data (nothing meaningful to show yet).
  bool get isEmpty => current.isEmpty && previous.isEmpty;
}

/// Pure roll-ups + regression detection over the accumulated histories.
class TrendDigest {
  const TrendDigest._();

  /// A regression fires only when the metric got meaningfully worse: the newer
  /// value is at least [_ratioThreshold]× the older AND the absolute change
  /// clears a floor, so tiny or noisy swings don't alert.
  static const double _ratioThreshold = 1.3;

  /// Absolute floor for a duration regression (review/merge time): 4 hours.
  static const int _minDurationDeltaMs = 4 * 60 * 60 * 1000;

  /// A duration regression needs at least this many contributing samples in
  /// BOTH windows, so a single-PR outlier in either period can't drive a median
  /// swing into an alert.
  static const int _minSamplesForDurationRegression = 2;

  /// A CI-failure-rate regression needs at least this many completed runs in
  /// the current window (so a 1-of-1 fluke doesn't alert) …
  static const int _minCiRunsForRegression = 5;

  /// … the rate must rise by at least this many points …
  static const double _minCiFailureRateDelta = 0.15;

  /// … and the current rate must be at least this high (a low rate isn't worth
  /// alerting on even if it doubled).
  static const double _minCiFailureRateFloor = 0.2;

  /// Tolerance for the failure-rate comparisons: rates are `failures/completed`
  /// binary fractions, so an exact threshold (e.g. 0.35 − 0.20 == 0.15) can
  /// land a hair low in floating point. A tiny epsilon keeps on-the-nose cases
  /// from being silently dropped.
  static const double _rateEpsilon = 1e-9;

  /// Builds a per-team [TeamTrend] for the current window `[now-window, now)`
  /// versus the immediately-preceding window `[now-2*window, now-window)`
  /// (both half-open, so the shared boundary belongs to the current window).
  ///
  /// [periodKey] (default derived from [now]) is embedded in each regression's
  /// de-dup key so a standing regression alerts at most once per period.
  static List<TeamTrend> compare({
    required List<Team> teams,
    required List<MergedPrSample> cycleSamples,
    required List<CiRunSample> ciSamples,
    DateTime? now,
    Duration window = const Duration(days: 7),
    String? periodKey,
  }) {
    final at = now ?? DateTime.now();
    final period = periodKey ?? periodKeyFor(at, window);
    final currentStart = at.subtract(window);
    final previousStart = at.subtract(window * 2);

    // Index samples by repoKey once so each team unions its repos' rows without
    // rescanning the full lists per team.
    final cycleByRepo = <String, List<MergedPrSample>>{};
    for (final s in cycleSamples) {
      cycleByRepo.putIfAbsent(s.repoKey, () => []).add(s);
    }
    final ciByRepo = <String, List<CiRunSample>>{};
    for (final s in ciSamples) {
      ciByRepo.putIfAbsent(s.repoKey, () => []).add(s);
    }

    final result = <TeamTrend>[];
    for (final team in teams) {
      if (team.repoKeys.isEmpty) continue;
      final teamCycle = [for (final key in team.repoKeys) ...?cycleByRepo[key]];
      final teamCi = [for (final key in team.repoKeys) ...?ciByRepo[key]];

      final current = _period(teamCycle, teamCi, start: currentStart, end: at);
      final previous = _period(
        teamCycle,
        teamCi,
        start: previousStart,
        end: currentStart,
      );
      final trend = TeamTrend(
        teamId: team.id,
        teamName: team.name,
        current: current,
        previous: previous,
        regressions: _regressions(
          team: team,
          current: current,
          previous: previous,
          periodKey: period,
        ),
      );
      if (trend.isEmpty) continue;
      result.add(trend);
    }
    // Regressed teams first, then by name, so what needs attention sorts up.
    result.sort((a, b) {
      if (a.hasRegression != b.hasRegression) return a.hasRegression ? -1 : 1;
      return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
    });
    return result;
  }

  /// All regressions across [teams], flattened — the alert path's input.
  static List<TrendRegression> regressions({
    required List<Team> teams,
    required List<MergedPrSample> cycleSamples,
    required List<CiRunSample> ciSamples,
    DateTime? now,
    Duration window = const Duration(days: 7),
    String? periodKey,
  }) => [
    for (final t in compare(
      teams: teams,
      cycleSamples: cycleSamples,
      ciSamples: ciSamples,
      now: now,
      window: window,
      periodKey: periodKey,
    ))
      ...t.regressions,
  ];

  /// The period bucket key for [now] (the window-aligned start date), used to
  /// scope alert de-duplication to one window. Same for any two instants in the
  /// same window relative to a fixed epoch.
  static String periodKeyFor(DateTime now, Duration window) {
    final days = window.inDays <= 0 ? 1 : window.inDays;
    final epochDay = now.toUtc().millisecondsSinceEpoch ~/ 86400000;
    final bucket = epochDay ~/ days;
    return 'w$days-$bucket';
  }

  static TeamPeriodStats _period(
    List<MergedPrSample> cycle,
    List<CiRunSample> ci, {
    required DateTime start,
    required DateTime end,
  }) {
    final mergeTimes = <int>[];
    final reviewTimes = <int>[];
    var merged = 0;
    for (final s in cycle) {
      if (s.mergedAt.isBefore(start) || !s.mergedAt.isBefore(end)) continue;
      merged++;
      final m = s.timeToMergeMs;
      if (m != null) mergeTimes.add(m);
      final r = s.timeToFirstReviewMs;
      if (r != null) reviewTimes.add(r);
    }
    var completed = 0;
    var failures = 0;
    for (final run in ci) {
      final finished = run.finishedAt;
      if (finished == null) continue;
      if (finished.isBefore(start) || !finished.isBefore(end)) continue;
      if (!CiOutcome.isCompleted(run.outcome)) continue;
      completed++;
      if (run.outcome == CiOutcome.failure) failures++;
    }
    return TeamPeriodStats(
      mergedCount: merged,
      reviewedCount: reviewTimes.length,
      medianTimeToFirstReviewMs: CycleTimeStats.median(reviewTimes),
      medianTimeToMergeMs: CycleTimeStats.median(mergeTimes),
      ciCompleted: completed,
      ciFailures: failures,
    );
  }

  static List<TrendRegression> _regressions({
    required Team team,
    required TeamPeriodStats current,
    required TeamPeriodStats previous,
    required String periodKey,
  }) {
    final out = <TrendRegression>[];
    void addDuration(
      RegressionKind kind,
      int? cur,
      int? prev,
      int curCount,
      int prevCount,
      String label,
    ) {
      if (cur == null || prev == null || prev <= 0) return;
      // Require enough samples in both windows so an outlier can't drive it.
      if (curCount < _minSamplesForDurationRegression ||
          prevCount < _minSamplesForDurationRegression) {
        return;
      }
      if (cur < prev * _ratioThreshold) return;
      if (cur - prev < _minDurationDeltaMs) return;
      out.add(
        TrendRegression(
          teamId: team.id,
          teamName: team.name,
          kind: kind,
          summary: '$label ${_fmtDuration(prev)} → ${_fmtDuration(cur)}',
          key: '$periodKey|${team.id}|${kind.id}',
        ),
      );
    }

    addDuration(
      RegressionKind.reviewLatencyUp,
      current.medianTimeToFirstReviewMs,
      previous.medianTimeToFirstReviewMs,
      current.reviewedCount,
      previous.reviewedCount,
      'review time',
    );
    addDuration(
      RegressionKind.mergeTimeUp,
      current.medianTimeToMergeMs,
      previous.medianTimeToMergeMs,
      current.mergedCount,
      previous.mergedCount,
      'merge time',
    );

    final curRate = current.ciFailureRate;
    final prevRate = previous.ciFailureRate;
    if (curRate != null &&
        prevRate != null &&
        current.ciCompleted >= _minCiRunsForRegression &&
        curRate >= _minCiFailureRateFloor - _rateEpsilon &&
        curRate - prevRate >= _minCiFailureRateDelta - _rateEpsilon) {
      out.add(
        TrendRegression(
          teamId: team.id,
          teamName: team.name,
          kind: RegressionKind.ciFailureRateUp,
          summary: 'CI failures ${_fmtPct(prevRate)} → ${_fmtPct(curRate)}',
          key: '$periodKey|${team.id}|${RegressionKind.ciFailureRateUp.id}',
        ),
      );
    }
    return out;
  }

  static String _fmtPct(double rate) => '${(rate * 100).round()}%';

  /// Compact day/hour/minute duration for summaries (mirrors the view's
  /// long-duration formatting, kept here so the pure layer has no UI dep).
  static String _fmtDuration(int ms) {
    if (ms <= 0) return '<1m';
    final totalMinutes = ms ~/ 60000;
    final d = totalMinutes ~/ 1440;
    final h = (totalMinutes % 1440) ~/ 60;
    final m = totalMinutes % 60;
    if (d > 0) return h > 0 ? '${d}d ${h}h' : '${d}d';
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    if (m > 0) return '${m}m';
    return '<1m';
  }
}
