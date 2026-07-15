import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/activity_service.dart';
import 'package:kode_radar/team.dart';
import 'package:kode_radar/team_service.dart';

void main() {
  test('rollup sums and aggregates only member repositories', () {
    final older = DateTime.utc(2026, 1, 1);
    final newer = DateTime.utc(2026, 1, 3);
    const team = Team(
      id: 'team-1',
      name: 'Platform',
      repoKeys: {'github:owner/repo', 'ado:org/project/repo'},
    );

    final rollup = TeamService.rollup(team, [
      _activity(
        repoKey: 'github:owner/repo',
        openPrCount: 2,
        needsReviewCount: 1,
        oldestOpenPrAgeDays: 3,
        lastActivity: older,
        contributors: ['ada', 'grace'],
        activityScore: 10,
      ),
      _activity(
        repoKey: 'ado:org/project/repo',
        openPrCount: 4,
        needsReviewCount: 2,
        oldestOpenPrAgeDays: 7,
        lastActivity: newer,
        contributors: ['grace', 'linus'],
        activityScore: 2.5,
      ),
      _activity(
        repoKey: 'github:other/repo',
        openPrCount: 100,
        needsReviewCount: 100,
        oldestOpenPrAgeDays: 30,
        lastActivity: DateTime.utc(2026, 1, 10),
        contributors: ['ignored'],
        activityScore: 100,
      ),
    ]);

    expect(rollup.repoCount, 2);
    expect(rollup.openPrs, 6);
    expect(rollup.needsReview, 3);
    expect(rollup.oldestOpenPrAgeDays, 7);
    expect(rollup.lastActivity, newer);
    expect(rollup.contributors, {'ada', 'grace', 'linus'});
    expect(rollup.activityScore, 12.5);
  });

  test('rollupAll is keyed by team id', () {
    const teams = [
      Team(id: 'one', name: 'One', repoKeys: {'github:owner/repo'}),
      Team(id: 'two', name: 'Two', repoKeys: {'github:unknown/repo'}),
    ];

    final rollups = TeamService.rollupAll(teams, [
      _activity(repoKey: 'github:owner/repo', openPrCount: 1),
    ]);

    expect(rollups.keys, {'one', 'two'});
    expect(rollups['one']?.repoCount, 1);
    expect(rollups['two']?.repoCount, 0);
    expect(rollups['two']?.openPrs, 0);
  });
}

RepoActivity _activity({
  required String repoKey,
  int openPrCount = 0,
  int needsReviewCount = 0,
  int? oldestOpenPrAgeDays,
  DateTime? lastActivity,
  List<String> contributors = const [],
  num activityScore = 0,
}) {
  return RepoActivity(
    repoKey: repoKey,
    provider: repoKey.startsWith('ado:') ? 'ado' : 'github',
    displayName: repoKey,
    url: '',
    openPrCount: openPrCount,
    needsReviewCount: needsReviewCount,
    oldestOpenPrAgeDays: oldestOpenPrAgeDays,
    lastActivity: lastActivity,
    ciStatus: '',
    contributors: contributors,
    activityScore: activityScore,
  );
}
