import 'package:flutter/material.dart';

import '../ci_run_history.dart';
import 'views_common.dart';

/// A drill-down for one workflow/pipeline: its rolled-up stats plus a list of
/// the individual runs behind them (newest first), each tappable to its run
/// page. Pure — it's handed the already-loaded [samples] for this workflow.
class CiWorkflowDetailPage extends StatelessWidget {
  const CiWorkflowDetailPage({
    super.key,
    required this.trend,
    required this.samples,
  });

  final CiWorkflowTrend trend;

  /// The runs for this workflow within the selected window, any order.
  final List<CiRunSample> samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runs = [...samples]
      ..sort((a, b) {
        final af = a.finishedAt;
        final bf = b.finishedAt;
        if (af == null && bf == null) return 0;
        // Newest first; a run with no finish time sorts last (its time is
        // unknown, so it isn't "newest").
        if (af == null) return 1;
        if (bf == null) return -1;
        return bf.compareTo(af);
      });
    final ratePct = (trend.failureRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(trend.workflow),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                trend.repoDisplay,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _Stat(label: 'Failure rate', value: '$ratePct%'),
                _Stat(label: 'Completed', value: '${trend.total}'),
                _Stat(
                  label: trend.isSlowing ? 'Typical ↑' : 'Typical',
                  value: formatDurationMs(trend.medianDurationMs) ?? '—',
                ),
                if (trend.isFlaky)
                  const _Stat(label: 'Verdict', value: 'Flaky')
                else if (trend.isChronicallyFailing)
                  const _Stat(label: 'Verdict', value: 'Failing')
                else if (trend.isSlowing)
                  const _Stat(label: 'Verdict', value: 'Slowing')
                else
                  const _Stat(label: 'Verdict', value: 'OK'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: runs.isEmpty
                ? const ViewEmpty(message: 'No runs in this window.')
                : ListView.separated(
                    itemCount: runs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _RunTile(run: runs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final CiRunSample run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = run.url;
    final when = run.finishedAt;
    final duration = formatDurationMs(run.durationMs);
    final subtitleParts = <String>[
      if (run.conclusion.isNotEmpty) run.conclusion,
      if (when != null) relativeTime(when),
      ?duration,
      if (run.branch != null && run.branch!.isNotEmpty) run.branch!,
    ];
    return ListTile(
      leading: Icon(ciIcon(run.outcome), color: ciColor(run.outcome)),
      title: Text(ciLabel(run.outcome)),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
      trailing: url == null ? null : const Icon(Icons.open_in_new, size: 16),
      onTap: url == null ? null : () => openUrl(url),
    );
  }
}
