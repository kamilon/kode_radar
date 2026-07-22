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
    this.url,
  });

  final String provider;
  final String repoKey;
  final String repoDisplay;

  /// The workflow / pipeline / build-definition name this run belongs to.
  final String workflow;

  /// Stable de-duplication key, e.g. `github:<repoKey>:<runId>:<attempt>`.
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
  final String? url;

  /// The key runs are grouped by for trends: the stable id when known, else the
  /// display name.
  String get groupKey => workflowId ?? workflow;
}

/// A per-workflow rollup over a recency window: how often it fails and how
/// much it flip-flops (flakiness), plus a newest-first strip of recent
/// outcomes for a sparkline.
class CiWorkflowTrend {
  const CiWorkflowTrend({
    required this.repoKey,
    required this.repoDisplay,
    required this.workflow,
    required this.successes,
    required this.failures,
    required this.flips,
    required this.lastOutcome,
    required this.lastCompletedOutcome,
    required this.recentOutcomes,
    required this.lastRunAt,
    required this.url,
  });

  final String repoKey;
  final String repoDisplay;
  final String workflow;

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

  bool get hasProblem => isFlaky || isChronicallyFailing;

  /// Shrinks a small sample's weight so a 1-fail / 1-pass workflow can't rank
  /// alongside a 20-run one with the same rate.
  double get _confidence => total == 0 ? 0 : total / (total + 3);

  /// Worst-first ranking weight: failing dominates, flakiness adds to it, both
  /// damped by sample confidence.
  double get severity => _confidence * (failureRate + 0.5 * flakeRate);

  /// Minimum flip rate for a mixed workflow to read as flaky (~1 in 3).
  static const double flakyThreshold = 0.34;

  /// Minimum completed runs before a workflow can be labeled flaky / failing.
  static const int minRunsForFlaky = 4;
  static const int minRunsForChronic = 3;

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
      for (final s in group) {
        if (recent.length < recentCap) recent.add(s.outcome);
        if (s.outcome == CiOutcome.success) {
          successes++;
          completed.add(CiOutcome.success);
        } else if (s.outcome == CiOutcome.failure) {
          failures++;
          completed.add(CiOutcome.failure);
        }
      }
      var flips = 0;
      for (var i = 1; i < completed.length; i++) {
        if (completed[i] != completed[i - 1]) flips++;
      }
      final newest = group.first;
      trends.add(
        CiWorkflowTrend(
          repoKey: newest.repoKey,
          repoDisplay: newest.repoDisplay,
          workflow: newest.workflow,
          successes: successes,
          failures: failures,
          flips: flips,
          lastOutcome: newest.outcome,
          lastCompletedOutcome: completed.isEmpty ? '' : completed.first,
          recentOutcomes: recent,
          lastRunAt: newest.finishedAt,
          url: newest.url,
        ),
      );
    }

    trends.sort((a, b) {
      final bySeverity = b.severity.compareTo(a.severity);
      if (bySeverity != 0) return bySeverity;
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
}
