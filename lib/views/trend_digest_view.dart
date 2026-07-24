import 'package:flutter/material.dart';

import '../trend_digest.dart';
import 'views_common.dart';

/// A manager digest: for each team, this period vs the previous one — merge
/// throughput, review latency, merge time, and CI failure rate — with the
/// changes that regressed flagged. Teams that regressed sort first. A window
/// selector re-aggregates the already-loaded histories client-side.
class TrendDigestView extends StatefulWidget {
  const TrendDigestView({super.key, required this.data});

  final InsightsData data;

  @override
  State<TrendDigestView> createState() => _TrendDigestViewState();
}

class _TrendDigestViewState extends State<TrendDigestView> {
  static const List<int> _windowChoices = [7, 14, 30];
  int _windowDays = 7;

  Duration get _window => Duration(days: _windowDays);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = widget.data.loadedAt;
    final trends = TrendDigest.compare(
      teams: widget.data.teams,
      cycleSamples: widget.data.cycleSamples,
      ciSamples: widget.data.ciRunSamples,
      now: now,
      window: _window,
    );
    final regressed = trends.where((t) => t.hasRegression).length;

    return ViewScaffold(
      title: 'Trends digest',
      loadedAt: now,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trends.isEmpty
                        ? 'No team trends yet'
                        : regressed == 0
                        ? '${trends.length} teams · all steady'
                        : '$regressed regressed · ${trends.length} teams',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: regressed == 0
                          ? theme.colorScheme.onSurfaceVariant
                          : _worse,
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
                'Last $_windowDays days vs the previous $_windowDays. '
                'Review time is GitHub-only.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: trends.isEmpty
                ? const ViewEmpty(
                    message:
                        'No team trends yet.\nAdd teams and let a couple of '
                        'sync cycles accumulate merged-PR and CI history, then '
                        'week-over-week trends appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: trends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _TeamCard(trend: trends[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

const Color _worse = Color(0xFFD32F2F);
const Color _better = Color(0xFF2E7D32);

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.trend});

  final TeamTrend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cur = trend.current;
    final prev = trend.previous;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_2,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trend.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final r in trend.regressions)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _Badge(label: _kindLabel(r.kind)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _CountMetric(
                  label: 'Merged',
                  current: cur.mergedCount,
                  previous: prev.mergedCount,
                ),
                _DurationMetric(
                  label: 'Review',
                  currentMs: cur.medianTimeToFirstReviewMs,
                  previousMs: prev.medianTimeToFirstReviewMs,
                ),
                _DurationMetric(
                  label: 'Merge',
                  currentMs: cur.medianTimeToMergeMs,
                  previousMs: prev.medianTimeToMergeMs,
                ),
                _RateMetric(
                  label: 'CI fail',
                  current: cur.ciFailureRate,
                  previous: prev.ciFailureRate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _kindLabel(RegressionKind kind) => switch (kind) {
    RegressionKind.reviewLatencyUp => 'Review ↑',
    RegressionKind.mergeTimeUp => 'Merge ↑',
    RegressionKind.ciFailureRateUp => 'CI ↑',
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _worse.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _worse.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _worse,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shared metric column: a label, a big current value, and a small change hint.
class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.change,
    this.changeColor,
  });

  final String label;
  final String value;
  final String? change;
  final Color? changeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          change ?? '—',
          style: theme.textTheme.bodySmall?.copyWith(
            color: changeColor ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CountMetric extends StatelessWidget {
  const _CountMetric({
    required this.label,
    required this.current,
    required this.previous,
  });

  final String label;
  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final delta = current - previous;
    // More merges is generally good (green when up, neutral when down).
    return _MetricColumn(
      label: label,
      value: '$current',
      change: delta == 0 ? 'vs $previous' : '${delta > 0 ? '+' : ''}$delta',
      changeColor: delta > 0 ? _better : null,
    );
  }
}

class _DurationMetric extends StatelessWidget {
  const _DurationMetric({
    required this.label,
    required this.currentMs,
    required this.previousMs,
  });

  final String label;
  final int? currentMs;
  final int? previousMs;

  @override
  Widget build(BuildContext context) {
    final value = formatLongDurationMs(currentMs) ?? '—';
    String? change;
    Color? color;
    if (currentMs != null && previousMs != null && previousMs! > 0) {
      final up = currentMs! > previousMs!;
      final down = currentMs! < previousMs!;
      // Faster (down) is better; slower (up) is worse.
      color = up ? _worse : (down ? _better : null);
      final arrow = up ? '↑' : (down ? '↓' : '=');
      change = '$arrow ${formatLongDurationMs(previousMs) ?? '—'}';
    } else if (currentMs != null) {
      change = 'new';
    }
    return _MetricColumn(
      label: label,
      value: value,
      change: change,
      changeColor: color,
    );
  }
}

class _RateMetric extends StatelessWidget {
  const _RateMetric({
    required this.label,
    required this.current,
    required this.previous,
  });

  final double? current;
  final double? previous;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = current == null ? '—' : '${(current! * 100).round()}%';
    String? change;
    Color? color;
    if (current != null && previous != null) {
      final up = current! > previous!;
      final down = current! < previous!;
      // Lower failure rate (down) is better.
      color = up ? _worse : (down ? _better : null);
      final arrow = up ? '↑' : (down ? '↓' : '=');
      change = '$arrow ${(previous! * 100).round()}%';
    }
    return _MetricColumn(
      label: label,
      value: value,
      change: change,
      changeColor: color,
    );
  }
}
