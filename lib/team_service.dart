import 'activity_service.dart';
import 'team.dart';

class TeamRollup {
  const TeamRollup({
    required this.repoCount,
    required this.openPrs,
    required this.needsReview,
    required this.oldestOpenPrAgeDays,
    required this.contributors,
    required this.activityScore,
    required this.lastActivity,
  });

  final int repoCount;
  final int openPrs;
  final int needsReview;
  final int? oldestOpenPrAgeDays;
  final Set<String> contributors;
  final num activityScore;
  final DateTime? lastActivity;
}

class TeamService {
  TeamService._();

  static TeamRollup rollup(Team team, List<RepoActivity> activities) {
    final matchedRepoKeys = <String>{};
    final contributors = <String>{};
    var openPrs = 0;
    var needsReview = 0;
    int? oldestOpenPrAgeDays;
    num activityScore = 0;
    DateTime? lastActivity;

    for (final activity in activities) {
      if (!team.repoKeys.contains(activity.repoKey)) continue;
      // Skip repos whose fetch errored so stale zeros don't read as healthy.
      if (activity.error != null) continue;

      matchedRepoKeys.add(activity.repoKey);
      openPrs += activity.openPrCount;
      needsReview += activity.needsReviewCount;
      activityScore += activity.activityScore;
      contributors.addAll(activity.contributors);

      final age = activity.oldestOpenPrAgeDays;
      if (age != null &&
          (oldestOpenPrAgeDays == null || age > oldestOpenPrAgeDays)) {
        oldestOpenPrAgeDays = age;
      }

      final activityTime = activity.lastActivity;
      if (activityTime != null &&
          (lastActivity == null || activityTime.isAfter(lastActivity))) {
        lastActivity = activityTime;
      }
    }

    return TeamRollup(
      repoCount: matchedRepoKeys.length,
      openPrs: openPrs,
      needsReview: needsReview,
      oldestOpenPrAgeDays: oldestOpenPrAgeDays,
      contributors: contributors,
      activityScore: activityScore,
      lastActivity: lastActivity,
    );
  }

  static Map<String, TeamRollup> rollupAll(
    List<Team> teams,
    List<RepoActivity> activities,
  ) {
    return {for (final team in teams) team.id: rollup(team, activities)};
  }
}
