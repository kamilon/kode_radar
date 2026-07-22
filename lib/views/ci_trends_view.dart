import 'package:flutter/material.dart';

import '../ci_run_history.dart';
import 'views_common.dart';

/// Ranks each workflow/pipeline by how much it needs attention — chronically
/// failing and flaky ones first — from the accumulated CI run history, with a
/// pass/fail sparkline of recent runs. Complements the CI health board (current
/// state) with the trend over time.
class CiTrendsView extends StatelessWidget {
  const CiTrendsView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final trends = data.ciTrends;
    final problems = trends.where((t) => t.hasProblem).length;

    return ViewScaffold(
      title: 'CI trends',
      loadedAt: data.loadedAt,
      child: trends.isEmpty
          ? const ViewEmpty(
              message:
                  'No CI history yet.\nWorkflow runs accumulate as syncs '
                  'observe them — check back after a few refreshes.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      problems == 0
                          ? '${trends.length} workflows · all healthy'
                          : '$problems needing attention · '
                                '${trends.length} workflows',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: problems == 0
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : ciColor('failure'),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'From recent sampled runs across all branches.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: trends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _TrendTile(trend: trends[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TrendTile extends StatelessWidget {
  const _TrendTile({required this.trend});

  final CiWorkflowTrend trend;

  ({String label, Color color})? _badge() {
    if (trend.isChronicallyFailing) {
      return (label: 'Failing', color: ciColor('failure'));
    }
    if (trend.isFlaky) return (label: 'Flaky', color: ciColor('running'));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _badge();
    final url = trend.url;
    final ratePct = (trend.failureRate * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url == null ? null : () => openUrl(url),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ciIcon(trend.lastOutcome),
                    size: 18,
                    color: ciColor(trend.lastOutcome),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trend.workflow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badge != null)
                    _Badge(label: badge.label, color: badge.color),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                trend.repoDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _Sparkline(outcomes: trend.recentOutcomes),
              const SizedBox(height: 6),
              Text(
                trend.total == 0
                    ? 'No completed runs in range'
                    : '$ratePct% failed · ${trend.failures}/${trend.total} runs'
                          '${trend.flips > 0 ? ' · ${trend.flips} flips' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A compact strip of recent run outcomes (oldest on the left) so the pass/fail
/// rhythm — and any flip-flopping — is visible at a glance.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.outcomes});

  /// Newest-first outcomes; rendered reversed so time reads left→right.
  final List<String> outcomes;

  @override
  Widget build(BuildContext context) {
    if (outcomes.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final outcome in outcomes.reversed)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 10,
              height: 14,
              decoration: BoxDecoration(
                color: ciColor(outcome).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
