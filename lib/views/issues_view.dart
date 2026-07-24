import 'package:flutter/material.dart';

import '../issue_service.dart';
import 'views_common.dart';

/// Surfaces where open (and stale) issue backlogs are piling up: per-repo and
/// per-team open-issue counts, ranked most-stale first so the backlogs that
/// need triage bubble up. GitHub-only for now (ADO work items are a planned
/// follow-up).
class IssuesView extends StatelessWidget {
  const IssuesView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repos = IssueStats.rankRepos(data.issueSnapshots);
    final teams = IssueStats.perTeam(data.issueSnapshots, data.teams);
    final totalOpen = repos.fold<int>(0, (t, r) => t + r.openCount);
    final totalStale = repos.fold<int>(0, (t, r) => t + r.staleCount);
    final failed = data.issuesFailedRepos;

    return ViewScaffold(
      title: 'Issues',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? ViewEmpty(
              message: failed > 0
                  ? 'Couldn\u2019t fetch issues for $failed '
                        '${failed == 1 ? 'repo' : 'repos'}.\nCheck your '
                        'connection and tokens, then refresh.'
                  : 'No open issues.\nOpen-issue counts are fetched for GitHub '
                        'repos — check back after a sync, or once a monitored '
                        'repo has open issues.',
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    '$totalOpen open · $totalStale stale '
                    '(>${IssueService.staleThreshold.inDays}d) · GitHub only'
                    '${failed > 0 ? ' · $failed unavailable' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: totalStale > 0
                          ? _stale
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (teams.isNotEmpty) ...[
                  _SectionLabel(label: 'By team'),
                  for (final t in teams)
                    _IssueTile(
                      title: t.teamName,
                      leadingIcon: Icons.groups_2,
                      openCount: t.openCount,
                      staleCount: t.staleCount,
                      oldestAgeDays: null,
                    ),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'By repo'),
                ],
                for (final r in repos)
                  _IssueTile(
                    title: r.repoDisplay,
                    leadingIcon: Icons.bug_report_outlined,
                    openCount: r.openCount,
                    staleCount: r.staleCount,
                    oldestAgeDays: r.oldestAgeDays,
                  ),
              ],
            ),
    );
  }
}

const Color _stale = Color(0xFFEF6C00);

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

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.title,
    required this.leadingIcon,
    required this.openCount,
    required this.staleCount,
    required this.oldestAgeDays,
  });

  final String title;
  final IconData leadingIcon;
  final int openCount;
  final int staleCount;
  final int? oldestAgeDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (staleCount > 0) '$staleCount stale',
      if (oldestAgeDays != null) 'oldest ${oldestAgeDays}d',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(leadingIcon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: staleCount > 0
                            ? _stale
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$openCount',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
