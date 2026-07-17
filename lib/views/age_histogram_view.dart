import 'package:flutter/material.dart';

import 'views_common.dart';

/// A histogram bucketing repos by the age of their oldest open PR, so review
/// backlog by staleness is visible at a glance.
class AgeHistogramView extends StatelessWidget {
  const AgeHistogramView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final withPrs = data.healthy
        .where((a) => (a.oldestOpenPrAgeDays ?? -1) >= 0 && a.openPrCount > 0)
        .toList();

    // Count of repos per bucket, and total open PRs per bucket.
    final repoCounts = <int, int>{};
    final prCounts = <int, int>{};
    for (final a in withPrs) {
      final age = a.oldestOpenPrAgeDays ?? 0;
      for (var i = 0; i < ageBuckets.length; i++) {
        if (ageBuckets[i].contains(age)) {
          repoCounts[i] = (repoCounts[i] ?? 0) + 1;
          prCounts[i] = (prCounts[i] ?? 0) + a.openPrCount;
          break;
        }
      }
    }
    final maxRepo = repoCounts.values.fold<int>(1, (m, v) => v > m ? v : m);

    return ViewScaffold(
      title: 'PR age',
      loadedAt: data.loadedAt,
      child: withPrs.isEmpty
          ? const ViewEmpty(message: 'No open PRs to bucket by age.')
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Repos by age of their oldest open PR',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < ageBuckets.length; i++)
                          Expanded(
                            child: _bar(
                              context,
                              bucket: ageBuckets[i],
                              repos: repoCounts[i] ?? 0,
                              prs: prCounts[i] ?? 0,
                              fraction: (repoCounts[i] ?? 0) / maxRepo,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required AgeBucket bucket,
    required int repos,
    required int prs,
    required double fraction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$repos',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: repos == 0
                      ? 2
                      : (c.maxHeight * fraction).clamp(6.0, c.maxHeight),
                  decoration: BoxDecoration(
                    color: bucket.color.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(bucket.label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            '$prs PRs',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
