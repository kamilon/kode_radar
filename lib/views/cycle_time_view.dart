import 'package:flutter/material.dart';

import '../cycle_time.dart';
import '../team.dart';
import 'views_common.dart';

/// Surfaces how long pull requests take to get a first review and to merge,
/// aggregated from the accumulated merged-PR history. Repos are ranked
/// slowest-to-merge first so the cycle-time bottlenecks bubble up; an optional
/// per-team section rolls the same medians up by team. A window selector
/// re-aggregates the already-loaded samples client-side; tapping a repo drills
/// into its individual merged PRs.
class CycleTimeView extends StatefulWidget {
  const CycleTimeView({super.key, required this.data});

  final InsightsData data;

  @override
  State<CycleTimeView> createState() => _CycleTimeViewState();
}

class _CycleTimeViewState extends State<CycleTimeView> {
  static const List<int> _windowChoices = [7, 30, 90];
  int _windowDays = 30;

  Duration get _window => Duration(days: _windowDays);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final samples = widget.data.cycleSamples;
    final now = widget.data.loadedAt;
    final repos = CycleTimeStats.perRepo(samples, now: now, window: _window);
    final overall = CycleTimeStats.summarize(
      samples,
      now: now,
      window: _window,
    );
    final teamStats = _teamStats(samples, now);

    return ViewScaffold(
      title: 'Cycle time',
      loadedAt: now,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    overall.isEmpty
                        ? 'No merged PRs yet'
                        : '${overall.mergedCount} merged · '
                              'review ${_fmt(overall.medianTimeToFirstReviewMs)} · '
                              'merge ${_fmt(overall.medianTimeToMergeMs)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                'Medians for PRs merged in the last $_windowDays days. '
                'Review time is GitHub-only.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: repos.isEmpty
                ? const ViewEmpty(
                    message:
                        'No merged PRs in range yet.\nMerged pull requests '
                        'accumulate as syncs observe them — check back after a '
                        'few refreshes.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (teamStats.isNotEmpty) ...[
                        _SectionLabel(label: 'By team'),
                        for (final t in teamStats)
                          _CycleTile(
                            title: t.name,
                            subtitle: null,
                            summary: t.summary,
                            leadingIcon: Icons.groups_2,
                          ),
                        const SizedBox(height: 16),
                        _SectionLabel(label: 'By repo'),
                      ],
                      for (final r in repos)
                        _CycleTile(
                          title: r.repoDisplay,
                          subtitle: null,
                          summary: r.summary,
                          leadingIcon: Icons.speed,
                          onTap: () => _openDetail(r),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<_TeamCycle> _teamStats(List<MergedPrSample> samples, DateTime now) {
    final teams = widget.data.teams;
    if (teams.isEmpty) return const [];
    final result = <_TeamCycle>[];
    for (final team in teams) {
      if (team.repoKeys.isEmpty) continue;
      final teamSamples = samples
          .where((s) => team.repoKeys.contains(s.repoKey))
          .toList();
      final summary = CycleTimeStats.summarize(
        teamSamples,
        now: now,
        window: _window,
      );
      if (summary.isEmpty) continue;
      result.add(_TeamCycle(team: team, summary: summary));
    }
    result.sort((a, b) {
      final am = a.summary.medianTimeToMergeMs;
      final bm = b.summary.medianTimeToMergeMs;
      if (am == null && bm == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (am == null) return 1;
      if (bm == null) return -1;
      final byMerge = bm.compareTo(am);
      if (byMerge != 0) return byMerge;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  void _openDetail(RepoCycleStats repo) {
    final cutoff = widget.data.loadedAt.subtract(_window);
    final prs =
        widget.data.cycleSamples
            .where(
              (s) => s.repoKey == repo.repoKey && !s.mergedAt.isBefore(cutoff),
            )
            .toList()
          ..sort((a, b) => b.mergedAt.compareTo(a.mergedAt));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RepoCycleDetailPage(
          repoDisplay: repo.repoDisplay,
          summary: repo.summary,
          prs: prs,
          windowDays: _windowDays,
        ),
      ),
    );
  }

  static String _fmt(int? ms) => formatLongDurationMs(ms) ?? '—';
}

class _TeamCycle {
  const _TeamCycle({required this.team, required this.summary});
  final Team team;
  final CycleSummary summary;
  String get name => team.name;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CycleTile extends StatelessWidget {
  const _CycleTile({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.leadingIcon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final CycleSummary summary;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = formatLongDurationMs(summary.medianTimeToFirstReviewMs);
    final merge = formatLongDurationMs(summary.medianTimeToMergeMs);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(leadingIcon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'First review',
                      value: review ?? '—',
                      hint: summary.reviewedCount < summary.mergedCount
                          ? '${summary.reviewedCount}/${summary.mergedCount} with review time'
                          : null,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'To merge',
                      value: merge ?? '—',
                      hint: '${summary.mergedCount} merged',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Per-repo drill-down: the individual merged PRs behind the medians, newest
/// merge first, each showing its own open→first-review and open→merge times.
class _RepoCycleDetailPage extends StatelessWidget {
  const _RepoCycleDetailPage({
    required this.repoDisplay,
    required this.summary,
    required this.prs,
    required this.windowDays,
  });

  final String repoDisplay;
  final CycleSummary summary;
  final List<MergedPrSample> prs;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(repoDisplay)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${summary.mergedCount} merged in the last $windowDays days · '
                'median review '
                '${formatLongDurationMs(summary.medianTimeToFirstReviewMs) ?? '—'} · '
                'median merge '
                '${formatLongDurationMs(summary.medianTimeToMergeMs) ?? '—'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: prs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _PrTile(pr: prs[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrTile extends StatelessWidget {
  const _PrTile({required this.pr});

  final MergedPrSample pr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = formatLongDurationMs(pr.timeToFirstReviewMs);
    final merge = formatLongDurationMs(pr.timeToMergeMs);
    final url = pr.url;
    final number = pr.prKey.split(':').last;

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
                  Expanded(
                    child: Text(
                      pr.title ?? 'PR #$number',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (url != null)
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '#$number'
                '${pr.author != null ? ' · ${pr.author}' : ''}'
                ' · review ${review ?? '—'} · merge ${merge ?? '—'}',
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
