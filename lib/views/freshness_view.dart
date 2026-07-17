import 'package:flutter/material.dart';

import 'views_common.dart';

/// "What went quiet" — repos ordered by how long since their last activity,
/// with a freshness heat bar. Stale-but-previously-active repos rise to the top.
class FreshnessView extends StatelessWidget {
  const FreshnessView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final repos = [...data.healthy]
      ..sort((a, b) {
        final da = daysSince(a.lastActivity, now: now);
        final db = daysSince(b.lastActivity, now: now);
        // Nulls (never any activity) sort last.
        if (da == null && db == null)
          return a.displayName.compareTo(b.displayName);
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    final maxDays = repos.fold<int>(1, (m, a) {
      final d = daysSince(a.lastActivity, now: now) ?? 0;
      return d > m ? d : m;
    });

    return ViewScaffold(
      title: 'Freshness',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'No repositories to rank by freshness.')
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: repos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final a = repos[i];
                final days = daysSince(a.lastActivity, now: now);
                final color = freshnessColor(a.lastActivity, now: now);
                final fraction = days == null
                    ? 1.0
                    : (days / maxDays).clamp(0.02, 1.0);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => openUrl(a.url),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            Text(
                              days == null ? 'no activity' : '${days}d ago',
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(color: color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 6,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            color: color,
                          ),
                        ),
                        if (a.openPrCount > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${a.openPrCount} open · ${a.needsReviewCount} need review',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
