// Models for the CI run history that powers the "CI trends" insight: the
// per-run samples accumulated across syncs and the per-workflow trend rolled
// up from them (failure rate + flakiness), all provider-agnostic and pure so
// they're easy to persist and unit-test.

/// Normalized outcomes we bucket every provider run into. Trend stats only
/// consider [success] / [failure] (a completed run); [running] (still going)
/// and [other] (cancelled/skipped/neutral) are shown for context but excluded
/// from rates so a queued run can't skew a workflow's health.
class CiOutcome {
  const CiOutcome._();

  static const String success = 'success';
  static const String failure = 'failure';
  static const String running = 'running';
  static const String other = 'other';

  /// Whether [outcome] is a completed pass/fail that counts toward stats.
  static bool isCompleted(String outcome) =>
      outcome == success || outcome == failure;
}

/// A single observed CI run/build, keyed by [runKey] (a provider-stable id) so
/// repeated syncs that re-see the same run don't double-count it.
class CiRunSample {
  const CiRunSample({
    required this.provider,
    required this.repoKey,
    required this.repoDisplay,
    required this.workflow,
    required this.runKey,
    required this.outcome,
    required this.conclusion,
    this.workflowId,
    this.branch,
    this.finishedAt,
    this.durationMs,
    this.url,
  });

  final String provider;
  final String repoKey;
  final String repoDisplay;

  /// The workflow / pipeline / build-definition name this run belongs to.
  final String workflow;

  /// Stable de-duplication key, e.g. `<repoKey>:<runId>:<attempt>` — repoKey
  /// already carries the provider prefix (`github:owner/name`), so it's not
  /// repeated here.
  final String runKey;

  /// Normalized [CiOutcome].
  final String outcome;

  /// The raw provider conclusion/result (kept for display / future logic).
  final String conclusion;

  /// Stable workflow/definition id (GitHub `workflow_id` / ADO `definition.id`)
  /// used to group runs so a rename doesn't split a workflow's history and two
  /// same-named workflows don't merge. Falls back to [workflow] when absent.
  final String? workflowId;

  final String? branch;
  final DateTime? finishedAt;

  /// The run's execution duration in milliseconds, when known (GitHub
  /// `run_started_at`→`updated_at`, ADO `startTime`→`finishTime`). Powers the
  /// typical-duration and slowdown signals.
  final int? durationMs;
  final String? url;

  /// The key runs are grouped by for trends: the stable id when known, else the
  /// display name. Namespaced (`id:` vs `name:`) so a workflow whose id equals
  /// another workflow's name can't collide.
  String get groupKey =>
      workflowId != null ? 'id:$workflowId' : 'name:$workflow';
}

/// A per-workflow rollup over a recency window: how often it fails and how
/// much it flip-flops (flakiness), plus a newest-first strip of recent
/// outcomes for a sparkline.
class CiWorkflowTrend {
  const CiWorkflowTrend({
    required this.repoKey,
    required this.repoDisplay,
    required this.workflow,
    required this.workflowId,
    required this.successes,
    required this.failures,
    required this.flips,
    required this.lastOutcome,
    required this.lastCompletedOutcome,
    required this.recentOutcomes,
    required this.lastRunAt,
    required this.url,
    this.medianDurationMs,
    this.slowdownRatio,
    this.isSlowing = false,
  });

  final String repoKey;
  final String repoDisplay;
  final String workflow;

  /// Stable workflow/definition id (or null), so a caller can filter the raw
  /// samples back to exactly this workflow via [groupKey].
  final String? workflowId;

  /// Completed (pass/fail) run counts in the window.
  final int successes;
  final int failures;

  /// Adjacent outcome changes across the completed-run sequence (a proxy for
  /// flakiness — a workflow that alternates pass/fail rather than staying one).
  final int flips;

  /// The newest run's outcome (may be [CiOutcome.running] / [CiOutcome.other]).
  final String lastOutcome;

  /// The newest run that was a pass/fail (skips running/other), or '' if none.
  /// Used so a recovered workflow (latest completed run passed) isn't labeled
  /// chronically failing on the strength of its older failures.
  final String lastCompletedOutcome;

  /// Newest-first outcomes (incl. running/other), capped for the sparkline.
  final List<String> recentOutcomes;

  final DateTime? lastRunAt;
  final String? url;

  /// Median duration (ms) of successful runs in the window, or null until there
  /// are at least [minRunsForTypical] timed successes — the "typical" run time.
  final int? medianDurationMs;

  /// Ratio of the recent-half median duration to the older-half median (of
  /// successful runs), or null without enough timed runs. > 1 means slower.
  final double? slowdownRatio;

  /// Whether the workflow's recent successful runs are meaningfully slower than
  /// its earlier ones (both a relative [slowdownThreshold] and an absolute
  /// [minSlowdownDeltaMs] increase), computed over a sufficient sample.
  final bool isSlowing;

  /// The key its runs are grouped by (matches [CiRunSample.groupKey]).
  String get groupKey =>
      workflowId != null ? 'id:$workflowId' : 'name:$workflow';

  /// Completed runs considered for the rates.
  int get total => successes + failures;

  /// Share of completed runs that failed (0 when there are none).
  double get failureRate => total == 0 ? 0 : failures / total;

  /// Share of adjacent completed-run pairs that changed outcome (0 with <2).
  double get flakeRate => total < 2 ? 0 : flips / (total - 1);

  /// A workflow that both passes and fails and alternates enough to be noise —
  /// requires a minimum sample so a lone pass/fail pair can't read as flaky.
  bool get isFlaky =>
      total >= minRunsForFlaky &&
      successes > 0 &&
      failures > 0 &&
      flakeRate >= flakyThreshold;

  /// A workflow that is red at least half the time, *stays* red (low flip
  /// rate), and is currently red (its latest completed run failed) — a
  /// persistent break rather than flapping or an already-recovered one.
  bool get isChronicallyFailing =>
      total >= minRunsForChronic &&
      failureRate >= 0.5 &&
      flakeRate < flakyThreshold &&
      lastCompletedOutcome == CiOutcome.failure;

  /// A workflow whose recent runs are meaningfully slower than its earlier ones
  /// (a regressing pipeline), even if it's still passing.
  bool get hasProblem => isFlaky || isChronicallyFailing || isSlowing;

  /// Shrinks a small sample's weight so a 1-fail / 1-pass workflow can't rank
  /// alongside a 20-run one with the same rate.
  double get _confidence => total == 0 ? 0 : total / (total + 3);

  /// Worst-first ranking weight from failure + flakiness only (a slowdown is a
  /// separate, lower-priority sort tier so it never outranks a real failure or
  /// flake — see [aggregate]'s sort). Damped by sample confidence.
  double get severity => _confidence * (failureRate + 0.5 * flakeRate);

  /// Minimum flip rate for a mixed workflow to read as flaky (~1 in 3).
  static const double flakyThreshold = 0.34;

  /// Recent runs must be at least this much slower than older runs (relative)
  /// AND at least [minSlowdownDeltaMs] slower (absolute) to count as "slowing".
  static const double slowdownThreshold = 1.3;

  /// Absolute floor (ms) on the recent-vs-older median increase, so trivial
  /// jitter on short jobs (e.g. 2s → 3s) isn't flagged as a slowdown.
  static const int minSlowdownDeltaMs = 10000;

  /// Minimum completed runs before a workflow can be labeled flaky / failing.
  static const int minRunsForFlaky = 4;
  static const int minRunsForChronic = 3;

  /// Minimum timed successful runs before a "typical" duration is shown.
  static const int minRunsForTypical = 3;

  /// Minimum timed successful runs before a slowdown is assessed (split into
  /// two halves of at least 4 each).
  static const int minRunsForSlowdown = 8;

  /// Newest-first outcomes kept in [recentOutcomes] / persisted strips.
  static const int recentCap = 16;

  /// Rolls [samples] up into per-workflow trends, newest-run first within each
  /// workflow, sorted worst-first. Only samples finished within [window] of
  /// [now] are considered (a sample with no finish time — typically an
  /// in-progress run — is always included). Pure: no I/O, safe to unit-test.
  static List<CiWorkflowTrend> aggregate(
    Iterable<CiRunSample> samples, {
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    final at = now ?? DateTime.now();
    final cutoff = at.subtract(window);
    final groups = <String, List<CiRunSample>>{};
    for (final s in samples) {
      final finished = s.finishedAt;
      if (finished != null && finished.isBefore(cutoff)) continue;
      groups.putIfAbsent('${s.repoKey}\u0000${s.groupKey}', () => []).add(s);
    }

    final trends = <CiWorkflowTrend>[];
    for (final group in groups.values) {
      // Newest first; runs without a finish time (in-progress) sort ahead of
      // finished ones so the latest state leads the strip.
      group.sort((a, b) {
        final af = a.finishedAt;
        final bf = b.finishedAt;
        if (af == null && bf == null) return 0;
        if (af == null) return -1;
        if (bf == null) return 1;
        return bf.compareTo(af);
      });

      var successes = 0;
      var failures = 0;
      final completed = <String>[]; // newest-first pass/fail sequence
      final recent = <String>[];
      final successDurations = <int>[]; // newest-first success run durations
      for (final s in group) {
        if (recent.length < recentCap) recent.add(s.outcome);
        if (s.outcome == CiOutcome.success) {
          successes++;
          completed.add(CiOutcome.success);
          if (s.durationMs != null && s.durationMs! > 0) {
            successDurations.add(s.durationMs!);
          }
        } else if (s.outcome == CiOutcome.failure) {
          failures++;
          completed.add(CiOutcome.failure);
        }
      }
      var flips = 0;
      for (var i = 1; i < completed.length; i++) {
        if (completed[i] != completed[i - 1]) flips++;
      }
      final medianDuration = successDurations.length >= minRunsForTypical
          ? _median(successDurations)
          : null;
      final (slowdown, slowing) = _slowdown(successDurations);
      final newest = group.first;
      trends.add(
        CiWorkflowTrend(
          repoKey: newest.repoKey,
          repoDisplay: newest.repoDisplay,
          workflow: newest.workflow,
          workflowId: newest.workflowId,
          successes: successes,
          failures: failures,
          flips: flips,
          lastOutcome: newest.outcome,
          lastCompletedOutcome: completed.isEmpty ? '' : completed.first,
          recentOutcomes: recent,
          lastRunAt: newest.finishedAt,
          url: newest.url,
          medianDurationMs: medianDuration,
          slowdownRatio: slowdown,
          isSlowing: slowing,
        ),
      );
    }

    trends.sort((a, b) {
      final bySeverity = b.severity.compareTo(a.severity);
      if (bySeverity != 0) return bySeverity;
      // Slowing is a lower-priority tier: at equal failure/flake severity, a
      // slowing workflow surfaces above a healthy one, but never above a
      // genuinely failing/flaky one.
      if (a.isSlowing != b.isSlowing) return a.isSlowing ? -1 : 1;
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      final byRepo = a.repoDisplay.toLowerCase().compareTo(
        b.repoDisplay.toLowerCase(),
      );
      if (byRepo != 0) return byRepo;
      return a.workflow.toLowerCase().compareTo(b.workflow.toLowerCase());
    });
    return trends;
  }

  /// The median of [values] (average of the two middle elements for an even
  /// count), or null when empty. Does not mutate [values].
  static int? _median(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// The (ratio, isSlowing) of the recent-half vs older-half median durations of
  /// [newestFirstDurations] (newest first). Ratio is null without at least
  /// [minRunsForSlowdown] timed runs; isSlowing additionally requires the
  /// increase to clear both the relative [slowdownThreshold] and the absolute
  /// [minSlowdownDeltaMs] floor.
  static (double?, bool) _slowdown(List<int> newestFirstDurations) {
    if (newestFirstDurations.length < minRunsForSlowdown) return (null, false);
    final half = newestFirstDurations.length ~/ 2;
    final recent = _median(newestFirstDurations.sublist(0, half));
    final older = _median(newestFirstDurations.sublist(half));
    if (recent == null || older == null || older == 0) return (null, false);
    final ratio = recent / older;
    final slowing =
        ratio >= slowdownThreshold && (recent - older) >= minSlowdownDeltaMs;
    return (ratio, slowing);
  }
}
