import 'package:flutter/material.dart';

import '../ci_run_history.dart';
import 'ci_workflow_detail_page.dart';
import 'views_common.dart';

/// Ranks each workflow/pipeline by how much it needs attention — chronically
/// failing and flaky ones first — from the accumulated (default-branch) CI run
/// history, with a pass/fail sparkline of recent runs. A window selector
/// re-aggregates the already-loaded samples client-side; tapping a workflow
/// drills into its individual runs.
class CiTrendsView extends StatefulWidget {
  const CiTrendsView({super.key, required this.data});

  final InsightsData data;

  @override
  State<CiTrendsView> createState() => _CiTrendsViewState();
}

class _CiTrendsViewState extends State<CiTrendsView> {
  static const List<int> _windowChoices = [7, 30, 90];
  int _windowDays = 30;

  Duration get _window => Duration(days: _windowDays);

  @override
  Widget build(BuildContext context) {
    final samples = widget.data.ciRunSamples;
    // Anchor aggregation to the load time so it matches the drill-down cutoff
    // (both use loadedAt), even if the view lingers open across the cutoff.
    final trends = CiWorkflowTrend.aggregate(
      samples,
      now: widget.data.loadedAt,
      window: _window,
    );
    final problems = trends.where((t) => t.hasProblem).length;

    return ViewScaffold(
      title: 'CI trends',
      loadedAt: widget.data.loadedAt,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trends.isEmpty
                        ? 'No CI history yet'
                        : problems == 0
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
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: [
                    for (final d in _windowChoices)
                      ButtonSegment(value: d, label: Text('${d}d')),
                  ],
                  selected: {_windowDays},
                  onSelectionChanged: (s) =>
                      setState(() => _windowDays = s.first),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Default-branch runs seen in the last $_windowDays days.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: trends.isEmpty
                ? const ViewEmpty(
                    message:
                        'No CI history yet.\nWorkflow runs accumulate as syncs '
                        'observe them — check back after a few refreshes.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: trends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _TrendTile(
                      trend: trends[i],
                      onTap: () => _openDetail(trends[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(CiWorkflowTrend trend) {
    // Same anchor as aggregation (loadedAt) so the drill-down list can't drift
    // out of sync with the tile's run count.
    final cutoff = widget.data.loadedAt.subtract(_window);
    final runs = widget.data.ciRunSamples
        .where(
          (s) =>
              s.repoKey == trend.repoKey &&
              s.groupKey == trend.groupKey &&
              (s.finishedAt == null || !s.finishedAt!.isBefore(cutoff)),
        )
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CiWorkflowDetailPage(trend: trend, samples: runs),
      ),
    );
  }
}

class _TrendTile extends StatelessWidget {
  const _TrendTile({required this.trend, required this.onTap});

  final CiWorkflowTrend trend;
  final VoidCallback onTap;

  ({String label, Color color})? _statusBadge() {
    if (trend.isChronicallyFailing) {
      return (label: 'Failing', color: ciColor('failure'));
    }
    if (trend.isFlaky) return (label: 'Flaky', color: ciColor('running'));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _statusBadge();
    final ratePct = (trend.failureRate * 100).round();
    final typical = formatDurationMs(trend.medianDurationMs);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  if (trend.isSlowing)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: _Badge(label: 'Slowing', color: Color(0xFF8E24AA)),
                    ),
                  if (badge != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _Badge(label: badge.label, color: badge.color),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                (trend.total == 0
                        ? 'No completed runs in range'
                        : '$ratePct% failed · ${trend.failures}/${trend.total} runs'
                              '${trend.flips > 0 ? ' · ${trend.flips} flips' : ''}') +
                    (typical != null ? ' · ~$typical' : ''),
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
