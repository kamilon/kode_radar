import 'package:flutter/material.dart';

import 'views_common.dart';

/// A word-cloud of open-PR authors across all repos, sized by how many repos
/// they're active in. Framed as collaboration/awareness — who's moving things —
/// not a performance ranking.
class ContributorCloudView extends StatelessWidget {
  const ContributorCloudView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    // Count in how many repos each contributor appears.
    final counts = <String, int>{};
    for (final a in data.healthy) {
      for (final c in a.contributors) {
        final name = c.trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final maxCount = entries.isEmpty ? 1 : entries.first.value;

    final scheme = Theme.of(context).colorScheme;

    return ViewScaffold(
      title: 'Contributors',
      loadedAt: data.loadedAt,
      child: entries.isEmpty
          ? const ViewEmpty(
              message:
                  'No open-PR authors to show. Framed as collaboration, '
                  'not a leaderboard.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active across repos (${entries.length} people)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final e in entries)
                        _chip(context, e.key, e.value, maxCount),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _chip(BuildContext context, String name, int count, int maxCount) {
    final t = maxCount <= 1 ? 1.0 : count / maxCount;
    final fontSize = 13.0 + 20.0 * t;
    final color = heatColor(0.25 + 0.55 * t);
    return Tooltip(
      message: 'in $count ${count == 1 ? 'repo' : 'repos'}',
      child: Text(
        name,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: t > 0.6 ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}
