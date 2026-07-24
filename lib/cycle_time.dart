// Models for PR review-time / cycle-time trends: the merged-PR samples
// accumulated across syncs and the per-repo / per-team summaries rolled up from
// them (median time-to-first-review and median time-to-merge). Provider-
// agnostic and pure so they're easy to persist and unit-test.

/// A single merged pull request, keyed by [prKey] (`<repoKey>:<number>`) so
/// repeated syncs that re-see the same PR don't double-count it.
class MergedPrSample {
  const MergedPrSample({
    required this.provider,
    required this.repoKey,
    required this.repoDisplay,
    required this.prKey,
    required this.createdAt,
    required this.mergedAt,
    this.firstReviewAt,
    this.title,
    this.author,
    this.url,
  });

  final String provider;
  final String repoKey;
  final String repoDisplay;

  /// Stable de-duplication key, e.g. `github:owner/name:1234`.
  final String prKey;

  final DateTime createdAt;
  final DateTime mergedAt;

  /// When the PR first received a review, if known (GitHub). Null for providers
  /// or PRs where a first-review time isn't available.
  final DateTime? firstReviewAt;

  final String? title;
  final String? author;
  final String? url;

  /// Milliseconds from open to first review, or null when unknown / negative.
  int? get timeToFirstReviewMs {
    final r = firstReviewAt;
    if (r == null) return null;
    final ms = r.difference(createdAt).inMilliseconds;
    return ms >= 0 ? ms : null;
  }

  /// Milliseconds from open to merge, or null when the timestamps are invalid.
  int? get timeToMergeMs {
    final ms = mergedAt.difference(createdAt).inMilliseconds;
    return ms >= 0 ? ms : null;
  }
}

/// A rolled-up summary of merged-PR timings for a repo or a team.
class CycleSummary {
  const CycleSummary({
    required this.mergedCount,
    required this.medianTimeToFirstReviewMs,
    required this.medianTimeToMergeMs,
    required this.reviewedCount,
  });

  /// Merged PRs considered (within the window).
  final int mergedCount;

  /// Of those, how many had a known first-review time.
  final int reviewedCount;

  /// Median open→first-review, or null when no PR had a first-review time.
  final int? medianTimeToFirstReviewMs;

  /// Median open→merge, or null when there are no merged PRs.
  final int? medianTimeToMergeMs;

  bool get isEmpty => mergedCount == 0;
}

/// A per-repo cycle-time summary with identity, for the trends list.
class RepoCycleStats {
  const RepoCycleStats({
    required this.repoKey,
    required this.repoDisplay,
    required this.summary,
  });

  final String repoKey;
  final String repoDisplay;
  final CycleSummary summary;
}

/// Pure roll-ups over [MergedPrSample]s. No I/O.
class CycleTimeStats {
  const CycleTimeStats._();

  /// Summarizes [samples] merged within [window] of [now] into medians.
  static CycleSummary summarize(
    Iterable<MergedPrSample> samples, {
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    final at = now ?? DateTime.now();
    final cutoff = at.subtract(window);
    final mergeTimes = <int>[];
    final reviewTimes = <int>[];
    var count = 0;
    for (final s in samples) {
      if (s.mergedAt.isBefore(cutoff)) continue;
      count++;
      final merge = s.timeToMergeMs;
      if (merge != null) mergeTimes.add(merge);
      final review = s.timeToFirstReviewMs;
      if (review != null) reviewTimes.add(review);
    }
    return CycleSummary(
      mergedCount: count,
      reviewedCount: reviewTimes.length,
      medianTimeToFirstReviewMs: median(reviewTimes),
      medianTimeToMergeMs: median(mergeTimes),
    );
  }

  /// Per-repo summaries, slowest median merge time first (nulls last).
  static List<RepoCycleStats> perRepo(
    Iterable<MergedPrSample> samples, {
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    final groups = <String, List<MergedPrSample>>{};
    final display = <String, String>{};
    for (final s in samples) {
      groups.putIfAbsent(s.repoKey, () => []).add(s);
      display[s.repoKey] = s.repoDisplay;
    }
    final result = <RepoCycleStats>[];
    for (final entry in groups.entries) {
      final summary = summarize(entry.value, now: now, window: window);
      if (summary.isEmpty) continue;
      result.add(
        RepoCycleStats(
          repoKey: entry.key,
          repoDisplay: display[entry.key] ?? entry.key,
          summary: summary,
        ),
      );
    }
    result.sort((a, b) {
      final am = a.summary.medianTimeToMergeMs;
      final bm = b.summary.medianTimeToMergeMs;
      if (am == null && bm == null) {
        return a.repoDisplay.toLowerCase().compareTo(
          b.repoDisplay.toLowerCase(),
        );
      }
      if (am == null) return 1;
      if (bm == null) return -1;
      final byMerge = bm.compareTo(am);
      if (byMerge != 0) return byMerge;
      return a.repoDisplay.toLowerCase().compareTo(b.repoDisplay.toLowerCase());
    });
    return result;
  }

  /// The median of [values], or null when empty. For an even count this is the
  /// average of the two middle elements, rounded to the nearest int (values are
  /// millisecond durations, so sub-millisecond rounding is immaterial). Does
  /// not mutate [values].
  static int? median(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
