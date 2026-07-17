import 'package:flutter/material.dart';

import '../person.dart';
import 'views_common.dart';

/// A people-centric "who can unblock whom" view: everyone with review requests
/// or authored open PRs, ranked by review load. Framed as collaboration and
/// unblocking — not individual performance ranking.
class ReviewLoadView extends StatelessWidget {
  const ReviewLoadView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final people = [...data.people]
      ..sort((a, b) {
        final byReview = b.reviewRequests.compareTo(a.reviewRequests);
        if (byReview != 0) return byReview;
        final byWip = b.authoredOpenPrs.compareTo(a.authoredOpenPrs);
        if (byWip != 0) return byWip;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

    final maxLoad = people.fold<int>(
      1,
      (m, p) => [
        m,
        p.reviewRequests,
        p.authoredOpenPrs,
      ].reduce((a, b) => a > b ? a : b),
    );

    return ViewScaffold(
      title: 'Review load',
      loadedAt: data.loadedAt,
      child: people.isEmpty
          ? const ViewEmpty(
              message:
                  'No open review requests or authored PRs to show.\nThis is about unblocking, not ranking.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _row(context, people[i], maxLoad),
            ),
    );
  }

  Widget _row(BuildContext context, Person p, int maxLoad) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: p.isSelf ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    _initials(p.displayName),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (p.isSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'You',
                      style: TextStyle(color: scheme.onPrimary, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _bar(
              context,
              'Review requests',
              p.reviewRequests,
              maxLoad,
              const Color(0xFF6A1B9A),
            ),
            const SizedBox(height: 6),
            _bar(
              context,
              'Authored open PRs',
              p.authoredOpenPrs,
              maxLoad,
              const Color(0xFF1565C0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    String label,
    int value,
    int max,
    Color color,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : (value / max).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 22, child: Text('$value', textAlign: TextAlign.right)),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s/_-]+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
