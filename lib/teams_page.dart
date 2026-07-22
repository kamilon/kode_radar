import 'package:flutter/material.dart';

import 'activity_service.dart';
import 'app_http.dart';
import 'ci_run_history_store.dart';
import 'digest_page.dart';
import 'manage_teams_page.dart';
import 'metric_snapshot.dart';
import 'metric_store.dart';
import 'sparkline.dart';
import 'team.dart';
import 'team_detail_page.dart';
import 'team_service.dart';
import 'team_store.dart';

/// Team-first monitoring lens: per-team rollups of repo activity, with a trend
/// sparkline, plus entry points to the Digest and Manage Teams.
class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  List<Team> _teams = const [];
  Map<String, TeamRollup> _rollups = const {};
  Map<String, List<num>> _series = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await TeamStore.list();
      final activities = await ActivityService.computeAll(
        client: AppHttp.client,
      );
      // Record a trend snapshot from this load too (deduped ~1/day).
      await MetricStore.capture(activities, restrictToMonitored: true);
      await CiRunHistoryStore.recordSafely(
        activities.expand((a) => a.recentRuns),
      );
      final rollups = TeamService.rollupAll(teams, activities);
      final history = await MetricStore.all();
      final series = <String, List<num>>{
        for (final team in teams) team.id: _teamSeries(team, history),
      };
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _rollups = rollups;
        _series = series;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TeamsPage failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading teams. Pull to retry.';
        _loading = false;
      });
    }
  }

  /// Aggregates the team's member-repo snapshots into a single day-bucketed
  /// activity-score series (ascending by day), so repos with uneven capture
  /// histories align by date rather than by list index.
  List<num> _teamSeries(Team team, Map<String, List<MetricSnapshot>> history) {
    // Bucket member-repo snapshots by calendar day and sum activityScore per
    // day, so repos with different capture histories align by date (not by
    // list index).
    final byDay = <DateTime, num>{};
    for (final key in team.repoKeys) {
      final snaps = history[key];
      if (snaps == null) continue;
      for (final entry in latestSnapshotByDay(snaps).entries) {
        byDay[entry.key] = (byDay[entry.key] ?? 0) + entry.value.activityScore;
      }
    }
    if (byDay.isEmpty) return const [];
    final days = byDay.keys.toList()..sort();
    return [for (final d in days) byDay[d]!];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Digest',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DigestPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'Manage teams',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTeamsPage()),
              );
              if (!mounted) return;
              await _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    if (_teams.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          const Center(child: Text('No teams yet.')),
          const SizedBox(height: 8),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create a team'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageTeamsPage()),
                );
                if (!mounted) return;
                await _load();
              },
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        final rollup = _rollups[team.id];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TeamDetailPage(team: team)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Sparkline(values: _series[team.id] ?? const []),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (team.repoKeys.isEmpty)
                    Text(
                      'No repositories assigned yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (rollup == null || rollup.repoCount == 0)
                    Text(
                      'No data yet — assigned repos are loading or failed to '
                      'fetch.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _metric(Icons.folder, '${rollup.repoCount} repos'),
                        _metric(Icons.merge_type, '${rollup.openPrs} open PRs'),
                        _metric(
                          Icons.rate_review,
                          '${rollup.needsReview} review requested',
                        ),
                        _metric(
                          Icons.people,
                          '${rollup.contributors.length} contributors',
                        ),
                        _metric(
                          Icons.update,
                          _relativeTime(rollup.lastActivity),
                        ),
                        if (rollup.oldestOpenPrAgeDays != null)
                          _metric(
                            Icons.schedule,
                            'oldest ${rollup.oldestOpenPrAgeDays}d',
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return 'no activity';
    final diff = DateTime.now().difference(value);
    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
