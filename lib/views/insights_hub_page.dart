import 'package:flutter/material.dart';

import '../activity_service.dart';
import '../app_http.dart';
import '../ci_run_history_store.dart';
import '../metric_store.dart';
import '../people_service.dart';
import '../team_service.dart';
import '../team_store.dart';
import 'age_histogram_view.dart';
import 'bubble_view.dart';
import 'ci_grid_view.dart';
import 'ci_trends_view.dart';
import 'contributor_cloud_view.dart';
import 'donut_view.dart';
import 'freshness_view.dart';
import 'health_gauge_view.dart';
import 'heatmap_view.dart';
import 'provider_split_view.dart';
import 'pulse_view.dart';
import 'quadrant_view.dart';
import 'repo_table_view.dart';
import 'review_load_view.dart';
import 'stacked_area_view.dart';
import 'team_radar_view.dart';
import 'treemap_view.dart';
import 'trend_lines_view.dart';
import 'views_common.dart';

/// Experimental gallery of alternative visualizations of the monitored data.
/// Loads the data once and hands an [InsightsData] to each view, so switching
/// between views is instant and consistent.
class InsightsHubPage extends StatefulWidget {
  const InsightsHubPage({super.key});

  @override
  State<InsightsHubPage> createState() => _InsightsHubPageState();
}

class _InsightsHubPageState extends State<InsightsHubPage> {
  InsightsData? _data;
  bool _loading = true;
  String? _error;
  int _loadSeq = 0;

  static final List<ViewInfo> _views = [
    ViewInfo(
      title: 'Pulse',
      blurb: 'Headline counters + aggregate trend',
      icon: Icons.speed,
      builder: (d) => PulseView(data: d),
    ),
    ViewInfo(
      title: 'Fleet health',
      blurb: 'Composite health score gauge',
      icon: Icons.health_and_safety,
      builder: (d) => HealthGaugeView(data: d),
    ),
    ViewInfo(
      title: 'Bubble chart',
      blurb: 'PR age × count, sized by activity',
      icon: Icons.bubble_chart,
      builder: (d) => BubbleView(data: d),
    ),
    ViewInfo(
      title: 'Triage quadrant',
      blurb: 'Staleness × load, 2×2 triage',
      icon: Icons.grid_goldenratio,
      builder: (d) => QuadrantView(data: d),
    ),
    ViewInfo(
      title: 'Open PR split',
      blurb: 'Donut of PRs by repo',
      icon: Icons.donut_large,
      builder: (d) => DonutView(data: d),
    ),
    ViewInfo(
      title: 'CI health',
      blurb: 'Status board, failures first',
      icon: Icons.grid_view,
      builder: (d) => CiGridView(data: d),
    ),
    ViewInfo(
      title: 'CI trends',
      blurb: 'Flaky & chronically-failing workflows',
      icon: Icons.timeline,
      builder: (d) => CiTrendsView(data: d),
    ),
    ViewInfo(
      title: 'Treemap',
      blurb: 'Repos sized by activity',
      icon: Icons.dashboard,
      builder: (d) => TreemapView(data: d),
    ),
    ViewInfo(
      title: 'PR age',
      blurb: 'Backlog bucketed by staleness',
      icon: Icons.bar_chart,
      builder: (d) => AgeHistogramView(data: d),
    ),
    ViewInfo(
      title: 'Heatmap',
      blurb: 'Repo × day activity grid',
      icon: Icons.calendar_view_month,
      builder: (d) => HeatmapView(data: d),
    ),
    ViewInfo(
      title: 'Trends',
      blurb: 'Overlaid activity trend lines',
      icon: Icons.show_chart,
      builder: (d) => TrendLinesView(data: d),
    ),
    ViewInfo(
      title: 'Stacked activity',
      blurb: 'Who drives momentum over time',
      icon: Icons.area_chart,
      builder: (d) => StackedAreaView(data: d),
    ),
    ViewInfo(
      title: 'Team radar',
      blurb: 'Compare team shapes',
      icon: Icons.radar,
      builder: (d) => TeamRadarView(data: d),
    ),
    ViewInfo(
      title: 'Freshness',
      blurb: 'What went quiet, ranked',
      icon: Icons.local_fire_department,
      builder: (d) => FreshnessView(data: d),
    ),
    ViewInfo(
      title: 'Contributors',
      blurb: 'Who is active across repos',
      icon: Icons.groups_2,
      builder: (d) => ContributorCloudView(data: d),
    ),
    ViewInfo(
      title: 'Review load',
      blurb: 'Who can unblock whom',
      icon: Icons.rate_review,
      builder: (d) => ReviewLoadView(data: d),
    ),
    ViewInfo(
      title: 'Provider split',
      blurb: 'GitHub vs Azure DevOps',
      icon: Icons.compare_arrows,
      builder: (d) => ProviderSplitView(data: d),
    ),
    ViewInfo(
      title: 'Repo table',
      blurb: 'Dense sortable metrics table',
      icon: Icons.table_rows,
      builder: (d) => RepoTableView(data: d),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Run the two network passes concurrently so loading People doesn't
      // serialize behind the repo activity fetch.
      final (activities, people) = await (
        ActivityService.computeAll(client: AppHttp.client),
        PeopleService.computeAll(client: AppHttp.client),
      ).wait;
      // Record a trend snapshot from this load too (deduped ~1/day), matching
      // Radar/Teams/Digest, so opening Insights also advances trend history.
      await MetricStore.capture(activities, restrictToMonitored: true);
      // Accumulate this fetch's CI runs, then read back the rolled-up trends so
      // the CI trends view reflects the freshest history.
      await CiRunHistoryStore.recordSafely(
        activities.expand((a) => a.recentRuns),
      );
      final ciTrends = await CiRunHistoryStore.trends();
      final history = await MetricStore.all();
      final teams = await TeamStore.list();
      final rollups = TeamService.rollupAll(teams, activities);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _data = InsightsData(
          activities: activities,
          history: history,
          teams: teams,
          rollups: rollups,
          people: people,
          ciTrends: ciTrends,
          loadedAt: DateTime.now(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemCount: _views.length,
        itemBuilder: (context, i) {
          final view = _views[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => view.builder(data)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      view.icon,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const Spacer(),
                    Text(
                      view.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      view.blurb,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
