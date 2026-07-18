import 'package:flutter/material.dart';

import '../metric_snapshot.dart';
import '../sparkline.dart';
import 'views_common.dart';

/// A "what's the state of the world" dashboard: headline counters plus an
/// aggregate activity trend.
class PulseView extends StatelessWidget {
  const PulseView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final repos = data.healthy;
    final now = DateTime.now();

    final openPrs = repos.fold<int>(0, (s, a) => s + a.openPrCount);
    final needsReview = repos.fold<int>(0, (s, a) => s + a.needsReviewCount);
    final failing = repos.where((a) => a.ciStatus == 'failure').length;
    final running = repos.where((a) => a.ciStatus == 'running').length;
    final stale = repos.where((a) {
      final d = daysSince(a.lastActivity, now: now);
      return d == null || d > 14;
    }).length;
    final errored = data.activities.where((a) => a.error != null).length;
    final oldest = repos
        .map((a) => a.oldestOpenPrAgeDays ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final contributors = <String>{
      for (final a in repos) ...a.contributors,
    }.length;

    final trend = _aggregateActivity(data.history);

    return ViewScaffold(
      title: 'Pulse',
      loadedAt: data.loadedAt,
      child: data.isEmpty
          ? const ViewEmpty(message: 'No repositories to summarize yet.')
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 520
                      ? 4
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    StatTile(
                      label: 'Open PRs',
                      value: '$openPrs',
                      icon: Icons.merge_type,
                    ),
                    StatTile(
                      label: 'Need review',
                      value: '$needsReview',
                      icon: Icons.rate_review,
                      color: const Color(0xFF6A1B9A),
                    ),
                    StatTile(
                      label: 'CI failing',
                      value: '$failing',
                      icon: Icons.cancel,
                      color: const Color(0xFFC62828),
                      sub: running > 0 ? '$running running' : null,
                    ),
                    StatTile(
                      label: 'Stale repos',
                      value: '$stale',
                      icon: Icons.bedtime,
                      color: const Color(0xFF8D6E63),
                      sub: 'quiet >14d',
                    ),
                    StatTile(
                      label: 'Oldest PR',
                      value: oldest > 0 ? '${oldest}d' : '—',
                      icon: Icons.hourglass_bottom,
                      color: const Color(0xFFEF6C00),
                    ),
                    StatTile(
                      label: 'Repos',
                      value: '${data.activities.length}',
                      icon: Icons.folder_open,
                      sub: errored > 0 ? '$errored errored' : null,
                    ),
                    StatTile(
                      label: 'Contributors',
                      value: '$contributors',
                      icon: Icons.people,
                      color: const Color(0xFF00897B),
                    ),
                    StatTile(
                      label: 'Teams',
                      value: '${data.teams.length}',
                      icon: Icons.groups,
                      color: const Color(0xFF1565C0),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aggregate activity trend',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trend.length < 2
                              ? 'Trend builds up as snapshots accumulate over days.'
                              : 'Total activity score across all repos per snapshot. $scoreNote',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (trend.length >= 2)
                          Center(
                            child: Sparkline(
                              values: trend,
                              width: MediaQuery.of(context).size.width - 88,
                              height: 72,
                            ),
                          )
                        else
                          const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Sums each snapshot day's total activityScore across all repos into a time
  /// series (oldest→newest).
  static List<num> _aggregateActivity(
    Map<String, List<MetricSnapshot>> history,
  ) {
    final byDay = <DateTime, num>{};
    for (final snapshots in history.values) {
      for (final s in snapshots) {
        final at = s.at;
        final day = DateTime.utc(at.year, at.month, at.day);
        byDay[day] = (byDay[day] ?? 0) + s.activityScore;
      }
    }
    final days = byDay.keys.toList()..sort();
    return [for (final d in days) byDay[d]!];
  }
}
