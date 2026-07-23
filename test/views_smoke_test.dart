import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/activity_service.dart';
import 'package:kode_radar/ci_run_history.dart';
import 'package:kode_radar/metric_snapshot.dart';
import 'package:kode_radar/person.dart';
import 'package:kode_radar/team.dart';
import 'package:kode_radar/team_service.dart';
import 'package:kode_radar/views/age_histogram_view.dart';
import 'package:kode_radar/views/bubble_view.dart';
import 'package:kode_radar/views/ci_grid_view.dart';
import 'package:kode_radar/views/ci_trends_view.dart';
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
    ciRunSamples: [
      for (var i = 0; i < 4; i++)
        CiRunSample(
          provider: 'github',
          repoKey: 'github:acme/kode',
          repoDisplay: 'acme/kode',
          workflow: 'CI',
          workflowId: '1',
          runKey: 'github:acme/kode:$i',
          outcome: i.isEven ? CiOutcome.success : CiOutcome.failure,
          conclusion: i.isEven ? 'success' : 'failure',
          finishedAt: DateTime.now().subtract(Duration(days: i)),
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
    'CiTrends': (d) => CiTrendsView(data: d),
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

  // ---- Edge cases the reviewers called out --------------------------------

  InsightsData bundle({
    List<RepoActivity> activities = const [],
    Map<String, List<MetricSnapshot>> history = const {},
    List<Person> people = const [],
  }) {
    return InsightsData(
      activities: activities,
      history: history,
      teams: const [],
      rollups: const {},
      people: people,
      loadedAt: DateTime.now(),
    );
  }

  testWidgets('AgeHistogram survives a very short surface', (tester) async {
    tester.view.physicalSize = const Size(400, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: AgeHistogramView(data: data)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('StackedArea keeps repos with duplicate leaf names', (
    tester,
  ) async {
    final dup = bundle(
      activities: [
        _activity('github:orgA/app', 'orgA/app'),
        _activity('github:orgB/app', 'orgB/app'),
      ],
      history: {
        'github:orgA/app': _series(3, 5),
        'github:orgB/app': _series(3, 9),
      },
    );
    await tester.pumpWidget(MaterialApp(home: StackedAreaView(data: dup)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReviewLoad handles odd display names', (tester) async {
    final odd = bundle(
      people: [
        Person(key: 'a', displayName: 'bot_', reviewRequests: 1),
        Person(key: 'b', displayName: 'team/', authoredOpenPrs: 2),
        Person(key: 'c', displayName: 'Renée Doe', reviewRequests: 3),
        Person(key: 'd', displayName: 'a-', reviewRequests: 1),
        Person(key: 'e', displayName: '', reviewRequests: 1),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: ReviewLoadView(data: odd)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProviderSplit handles a single-provider fleet', (tester) async {
    final ghOnly = bundle(
      activities: [
        _activity('github:o/a', 'o/a'),
        _activity('github:o/b', 'o/b'),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: ProviderSplitView(data: ghOnly)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-repo score views do not crash', (tester) async {
    final one = bundle(
      activities: [
        _activity(
          'github:o/solo',
          'o/solo',
          open: 1,
          oldest: 1,
          lastDaysAgo: 1,
        ),
      ],
      history: {'github:o/solo': _series(1, 3)},
    );
    final builds = <Widget Function(InsightsData)>[
      (d) => QuadrantView(data: d),
      (d) => TreemapView(data: d),
      (d) => DonutView(data: d),
      (d) => BubbleView(data: d),
      (d) => HealthGaugeView(data: d),
    ];
    for (final b in builds) {
      await tester.pumpWidget(MaterialApp(home: b(one)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
