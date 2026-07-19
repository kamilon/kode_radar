class MetricSnapshot {
  const MetricSnapshot({
    required this.at,
    required this.openPrs,
    required this.needsReview,
    required this.activityScore,
  });

  final DateTime at;
  final int openPrs;
  final int needsReview;
  final num activityScore;

  Map<String, Object> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'openPrs': openPrs,
    'needsReview': needsReview,
    'activityScore': activityScore,
  };

  static MetricSnapshot? fromJson(Map json) {
    try {
      final rawAt = json['at'];
      final rawOpenPrs = json['openPrs'];
      final rawNeedsReview = json['needsReview'];
      final rawActivityScore = json['activityScore'];

      if (rawAt is! String ||
          rawOpenPrs is! int ||
          rawNeedsReview is! int ||
          rawActivityScore is! num) {
        return null;
      }

      final at = DateTime.tryParse(rawAt);
      if (at == null) {
        return null;
      }

      return MetricSnapshot(
        at: at.toUtc(),
        openPrs: rawOpenPrs,
        needsReview: rawNeedsReview,
        activityScore: rawActivityScore,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Collapses snapshots to the latest one per UTC day.
///
/// Aggregations built on top (daily sums/heatmaps) are then invariant to how
/// often a day was captured — denser-than-daily sync must not inflate daily
/// totals by counting several same-day snapshots of the same repo.
Map<DateTime, MetricSnapshot> latestSnapshotByDay(
  Iterable<MetricSnapshot> snapshots,
) {
  final byDay = <DateTime, MetricSnapshot>{};
  for (final s in snapshots) {
    final day = DateTime.utc(s.at.year, s.at.month, s.at.day);
    final existing = byDay[day];
    if (existing == null || s.at.isAfter(existing.at)) {
      byDay[day] = s;
    }
  }
  return byDay;
}
