import 'activity_service.dart';
import 'metric_snapshot.dart';
import 'team.dart';

class DigestLine {
  const DigestLine({
    required this.label,
    required this.openPrs,
    required this.needsReview,
    required this.activityScore,
    required this.activityDelta,
  });

  final String label;
  final int openPrs;
  final int needsReview;
  final num activityScore;
  final num activityDelta;
}

class Digest {
  const Digest({
    required this.generatedAt,
    required this.window,
    required this.totalOpenPrs,
    required this.totalNeedsReview,
    required this.teamLines,
    required this.movers,
  });

  final DateTime generatedAt;
  final Duration window;
  final int totalOpenPrs;
  final int totalNeedsReview;
  final List<DigestLine> teamLines;
  final List<DigestLine> movers;
}

class DigestService {
  DigestService._();

  static Digest buildDigest({
    required List<Team> teams,
    required List<RepoActivity> activities,
    required Map<String, List<MetricSnapshot>> history,
    DateTime? now,
    Duration window = const Duration(days: 7),
  }) {
    final generatedAt = now ?? DateTime.now();
    final cutoff = generatedAt.subtract(window);

    // Only repos we currently have valid (non-errored) data for; an errored
    // fetch must not read as a healthy zero.
    final byKey = <String, RepoActivity>{
      for (final activity in activities)
        if (activity.error == null) activity.repoKey: activity,
    };

    final totalOpenPrs = byKey.values.fold<int>(
      0,
      (total, activity) => total + activity.openPrCount,
    );
    final totalNeedsReview = byKey.values.fold<int>(
      0,
      (total, activity) => total + activity.needsReviewCount,
    );

    final teamLines = <DigestLine>[];
    for (final team in teams) {
      var openPrs = 0;
      var needsReview = 0;
      num activityScore = 0;
      // Delta is computed only over member repos that have a baseline snapshot
      // within the window, comparing their current score to that baseline. A
      // team with no such baseline has no meaningful trend yet (delta 0), so it
      // is not treated as a mover.
      num deltaCurrent = 0;
      num deltaBaseline = 0;
      var hasBaseline = false;

      for (final repoKey in team.repoKeys) {
        final activity = byKey[repoKey];
        if (activity != null) {
          openPrs += activity.openPrCount;
          needsReview += activity.needsReviewCount;
          activityScore += _safeScore(activity.activityScore);
        }
        final baseline = _oldestSnapshotInWindow(history[repoKey], cutoff);
        if (baseline != null && activity != null) {
          hasBaseline = true;
          deltaBaseline += _safeScore(baseline.activityScore);
          deltaCurrent += _safeScore(activity.activityScore);
        }
      }

      teamLines.add(
        DigestLine(
          label: team.name,
          openPrs: openPrs,
          needsReview: needsReview,
          activityScore: activityScore,
          activityDelta: hasBaseline ? deltaCurrent - deltaBaseline : 0,
        ),
      );
    }

    // Sort by magnitude so large drops surface alongside large rises.
    final movers = teamLines.where((line) => line.activityDelta != 0).toList()
      ..sort((a, b) => b.activityDelta.abs().compareTo(a.activityDelta.abs()));

    return Digest(
      generatedAt: generatedAt,
      window: window,
      totalOpenPrs: totalOpenPrs,
      totalNeedsReview: totalNeedsReview,
      teamLines: teamLines,
      movers: movers.take(5).toList(),
    );
  }

  static MetricSnapshot? _oldestSnapshotInWindow(
    List<MetricSnapshot>? snapshots,
    DateTime cutoff,
  ) {
    if (snapshots == null || snapshots.isEmpty) return null;

    MetricSnapshot? oldest;
    for (final snapshot in snapshots) {
      if (snapshot.at.isBefore(cutoff)) continue;
      if (oldest == null || snapshot.at.isBefore(oldest.at)) {
        oldest = snapshot;
      }
    }
    return oldest;
  }

  static num _safeScore(num value) => value.isFinite ? value : 0;
}
