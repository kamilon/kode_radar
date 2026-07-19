import 'package:flutter/material.dart';

import '../metric_snapshot.dart';
import 'views_common.dart';

/// A contribution-graph-style grid: repos as rows, recent snapshot days as
/// columns, each cell shaded by that day's activity score.
class HeatmapView extends StatelessWidget {
  const HeatmapView({super.key, required this.data});

  final InsightsData data;

  static const int _maxDays = 30;

  @override
  Widget build(BuildContext context) {
    // Distinct snapshot days across all repos (UTC), most recent last.
    final daySet = <DateTime>{};
    for (final snaps in data.history.values) {
      for (final s in snaps) {
        daySet.add(DateTime.utc(s.at.year, s.at.month, s.at.day));
      }
    }
    final days = daySet.toList()..sort();
    final shownDays = days.length > _maxDays
        ? days.sublist(days.length - _maxDays)
        : days;

    // Rows: repos that have any snapshot, labeled and score-mapped per day.
    final rows = <_Row>[];
    var maxScore = 1.0;
    data.history.forEach((key, snaps) {
      if (snaps.isEmpty) return;
      final name =
          data.activities
              .where((a) => a.repoKey == key)
              .map((a) => a.displayName)
              .fold<String?>(null, (p, e) => p ?? e) ??
          key;
      final byDay = <DateTime, double>{};
      for (final entry in latestSnapshotByDay(snaps).entries) {
        final v = entry.value.activityScore.toDouble();
        byDay[entry.key] = v;
        if (v > maxScore) maxScore = v;
      }
      rows.add(_Row(name.split('/').last, byDay));
    });
    rows.sort((a, b) => a.name.compareTo(b.name));

    return ViewScaffold(
      title: 'Heatmap',
      loadedAt: data.loadedAt,
      child: (rows.isEmpty || shownDays.isEmpty)
          ? const ViewEmpty(
              message:
                  'The heatmap fills in as daily snapshots accumulate.\nCheck back after using the app across a few days.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Activity score per day (${shownDays.length} days). $scoreNote',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const labelW = 96.0;
                        final cell = ((c.maxWidth - labelW) / shownDays.length)
                            .clamp(4.0, 22.0);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final row in rows)
                              _rowWidget(
                                context,
                                row,
                                shownDays,
                                labelW,
                                cell,
                                maxScore,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _rowWidget(
    BuildContext context,
    _Row row,
    List<DateTime> days,
    double labelW,
    double cell,
    double maxScore,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: labelW,
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final d in days)
            Builder(
              builder: (context) {
                final v = row.byDay[d];
                // A day with a snapshot but zero activity reads as background
                // (empty), not a faint colored cell — 0 activity != some
                // activity. Only strictly-positive scores get a heat color.
                final color = (v != null && v > 0)
                    ? heatColor((v / maxScore).clamp(0.05, 1.0))
                    : Theme.of(context).colorScheme.surfaceContainerHighest;
                return Container(
                  width: cell,
                  height: cell,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Row {
  _Row(this.name, this.byDay);
  final String name;
  final Map<DateTime, double> byDay;
}
