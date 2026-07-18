import 'package:flutter/material.dart';

import '../activity_service.dart';
import 'views_common.dart';

/// A status board: one tile per repo, colored by CI state, grouped
/// failing → running → unknown → passing so problems surface first.
class CiGridView extends StatelessWidget {
  const CiGridView({super.key, required this.data});

  final InsightsData data;

  static int _rank(String status) => switch (status) {
    'failure' => 0,
    'running' => 1,
    'unknown' => 2,
    _ => 3,
  };

  @override
  Widget build(BuildContext context) {
    final repos = [...data.healthy]
      ..sort((a, b) {
        final r = _rank(a.ciStatus).compareTo(_rank(b.ciStatus));
        return r != 0 ? r : a.displayName.compareTo(b.displayName);
      });

    final counts = <String, int>{};
    for (final a in repos) {
      counts[a.ciStatus] = (counts[a.ciStatus] ?? 0) + 1;
    }

    return ViewScaffold(
      title: 'CI health',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'No CI status to show yet.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final status in const [
                        'failure',
                        'running',
                        'unknown',
                        'success',
                      ])
                        if ((counts[status] ?? 0) > 0)
                          _legend(status, counts[status]!),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.7,
                        ),
                    itemCount: repos.length,
                    itemBuilder: (context, i) => _tile(context, repos[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legend(String status, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ciIcon(status), size: 14, color: ciColor(status)),
        const SizedBox(width: 4),
        Text('${ciLabel(status)} · $count'),
      ],
    );
  }

  Widget _tile(BuildContext context, RepoActivity a) {
    final color = ciColor(a.ciStatus);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openUrl(a.url),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ciIcon(a.ciStatus), size: 16, color: color),
                const Spacer(),
                if (a.openPrCount > 0)
                  Text(
                    '${a.openPrCount} PR',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              a.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
