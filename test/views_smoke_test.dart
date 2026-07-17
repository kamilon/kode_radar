import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/activity_service.dart';
import 'package:kode_radar/metric_snapshot.dart';
import 'package:kode_radar/person.dart';
import 'package:kode_radar/team.dart';
import 'package:kode_radar/team_service.dart';
import 'package:kode_radar/views/age_histogram_view.dart';
import 'package:kode_radar/views/bubble_view.dart';
import 'package:kode_radar/views/ci_grid_view.dart';
import 'package:kode_radar/views/contributor_cloud_view.dart';
import 'package:kode_radar/views/donut_view.dart';
import 'package:kode_radar/views/freshness_view.dart';
import 'package:kode_radar/views/health_gauge_view.dart';
import 'package:kode_radar/views/heatmap_view.dart';
import 'package:kode_radar/views/provider_split_view.dart';
import 'package:kode_radar/views/pulse_view.dart';
import 'package:kode_radar/views/quadrant_view.dart';
import 'package:kode_radar/views/repo_table_view.dart';
import 'package:kode_radar/views/review_load_view.dart';
import 'package:kode_radar/views/stacked_area_view.dart';
import 'package:kode_radar/views/team_radar_view.dart';
import 'package:kode_radar/views/treemap_view.dart';
import 'package:kode_radar/views/trend_lines_view.dart';
import 'package:kode_radar/views/views_common.dart';

RepoActivity _activity(
  String key,
  String name, {
  int open = 3,
  int review = 1,
  int? oldest = 5,
  int? lastDaysAgo = 2,
  String ci = 'success',
  num score = 4,
  String? error,
}) {
  return RepoActivity(
    repoKey: key,
    provider: 'github',
    displayName: name,
    url: 'https://github.com/$name',
    openPrCount: open,
    needsReviewCount: review,
    oldestOpenPrAgeDays: oldest,
    lastActivity: lastDaysAgo == null
        ? null
        : DateTime.now().subtract(Duration(days: lastDaysAgo)),
    ciStatus: ci,
    contributors: const ['alice', 'bob'],
    activityScore: score,
    error: error,
  );
}

List<MetricSnapshot> _series(int n, num base) => [
  for (var i = 0; i < n; i++)
    MetricSnapshot(
      at: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
      openPrs: 2 + i,
      needsReview: i % 2,
      activityScore: base + i,
    ),
];

InsightsData _sampleData() {
  final activities = [
    _activity('github:o/alpha', 'o/alpha', ci: 'failure', score: 9),
    _activity('github:o/beta', 'o/beta', ci: 'running', score: 5, oldest: 20),
    _activity(
      'github:o/gamma',
      'o/gamma',
      ci: 'success',
      score: 2,
      lastDaysAgo: 40,
    ),
    _activity('github:o/delta', 'o/delta', error: 'boom', open: 0),
  ];
  final history = {
    'github:o/alpha': _series(6, 3),
    'github:o/beta': _series(4, 1),
    'github:o/gamma': _series(1, 2),
  };
  final teams = [
    const Team(id: 't1', name: 'Platform', repoKeys: {'github:o/alpha'}),
    const Team(
      id: 't2',
      name: 'Infra',
      repoKeys: {'github:o/beta', 'github:o/gamma'},
    ),
  ];
  return InsightsData(
    activities: activities,
    history: history,
    teams: teams,
    rollups: TeamService.rollupAll(teams, activities),
    people: [
      Person(
        key: 'github:alice',
        displayName: 'Alice',
        githubLogins: const {'alice'},
        authoredOpenPrs: 3,
        reviewRequests: 5,
        isSelf: true,
      ),
      Person(
        key: 'github:bob',
        displayName: 'Bob',
        githubLogins: const {'bob'},
        authoredOpenPrs: 1,
        reviewRequests: 2,
      ),
    ],
    loadedAt: DateTime.now(),
  );
}

void main() {
  final data = _sampleData();
  final empty = InsightsData(
    activities: const [],
    history: const {},
    teams: const [],
    rollups: const {},
    people: const [],
    loadedAt: DateTime.now(),
  );

  final views = <String, Widget Function(InsightsData)>{
    'Pulse': (d) => PulseView(data: d),
    'HealthGauge': (d) => HealthGaugeView(data: d),
    'Bubble': (d) => BubbleView(data: d),
    'Quadrant': (d) => QuadrantView(data: d),
    'Donut': (d) => DonutView(data: d),
    'CiGrid': (d) => CiGridView(data: d),
    'Treemap': (d) => TreemapView(data: d),
    'AgeHistogram': (d) => AgeHistogramView(data: d),
    'Heatmap': (d) => HeatmapView(data: d),
    'TrendLines': (d) => TrendLinesView(data: d),
    'StackedArea': (d) => StackedAreaView(data: d),
    'TeamRadar': (d) => TeamRadarView(data: d),
    'Freshness': (d) => FreshnessView(data: d),
    'Contributors': (d) => ContributorCloudView(data: d),
    'ReviewLoad': (d) => ReviewLoadView(data: d),
    'ProviderSplit': (d) => ProviderSplitView(data: d),
    'RepoTable': (d) => RepoTableView(data: d),
  };

  views.forEach((name, build) {
    testWidgets('$name renders with data', (tester) async {
      await tester.pumpWidget(MaterialApp(home: build(data)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name renders when empty', (tester) async {
      await tester.pumpWidget(MaterialApp(home: build(empty)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
