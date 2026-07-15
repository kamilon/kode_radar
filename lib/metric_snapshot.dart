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
