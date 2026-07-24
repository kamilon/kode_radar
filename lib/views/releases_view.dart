import 'package:flutter/material.dart';

import '../release_service.dart';
import 'views_common.dart';

/// Two manager/OSS-watcher questions in one place: **what shipped** (recent
/// releases across every monitored GitHub repo, newest first) and **what's
/// vulnerable** (repos with open Dependabot alerts, worst severity first).
/// GitHub-only; Dependabot alerts are owner-scoped so watched repos you don't
/// administer are noted as unavailable rather than shown as clear.
class ReleasesView extends StatelessWidget {
  const ReleasesView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final releases = data.releases;
    final security = data.security;
    final unavailable = data.securityUnavailableRepos;
    final releasesFailed = data.releasesFailedRepos;
    final hasNothing = releases.isEmpty && security.isEmpty;

    return ViewScaffold(
      title: 'Releases & security',
      loadedAt: data.loadedAt,
      child: hasNothing
          ? ViewEmpty(
              message: (unavailable > 0 || releasesFailed > 0)
                  ? _coverageMessage(releasesFailed, unavailable)
                  : 'No recent releases or open alerts.\nReleases from the last '
                        '${ReleaseService.releaseWindow.inDays} days and open '
                        'Dependabot alerts show here (GitHub only).',
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _SectionLabel(
                  label:
                      'Open security alerts'
                      '${unavailable > 0 ? ' · $unavailable ${_repos(unavailable)} unavailable' : ''}',
                ),
                if (security.isEmpty)
                  _Muted(
                    text: unavailable > 0
                        ? 'No open alerts in the repos that could be read.'
                        : 'No open Dependabot alerts.',
                  )
                else
                  for (final s in security) _SecurityTile(repo: s),
                const SizedBox(height: 16),
                _SectionLabel(
                  label:
                      'Recent releases · last '
                      '${ReleaseService.releaseWindow.inDays}d'
                      '${releasesFailed > 0 ? ' · $releasesFailed ${_repos(releasesFailed)} unavailable' : ''}',
                ),
                if (releases.isEmpty)
                  _Muted(
                    text: releasesFailed > 0
                        ? 'No releases in the repos that could be read.'
                        : 'No releases in range.',
                  )
                else
                  for (final r in releases) _ReleaseTile(release: r),
              ],
            ),
    );
  }

  static String _repos(int n) => n == 1 ? 'repo' : 'repos';

  /// Empty-state coverage note that mentions only the source(s) that actually
  /// have a gap (so it never says "0 repos"), plus the likely causes.
  static String _coverageMessage(int releasesFailed, int unavailable) {
    final parts = <String>[
      if (releasesFailed > 0)
        'releases couldn\u2019t be fetched for $releasesFailed '
            '${_repos(releasesFailed)}',
      if (unavailable > 0)
        'Dependabot alerts weren\u2019t available for $unavailable '
            '${_repos(unavailable)}',
    ];
    return 'Nothing to show yet.\n${_sentenceCase(parts.join('; '))}. '
        'Check your connection, tokens, and (for alerts) repo permissions, '
        'then refresh.';
  }

  static String _sentenceCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

const Color _critical = Color(0xFFB71C1C);
const Color _high = Color(0xFFD32F2F);
const Color _medium = Color(0xFFEF6C00);
const Color _low = Color(0xFF9E9E9E);

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

class _Muted extends StatelessWidget {
  const _Muted({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({required this.repo});
  final RepoSecurity repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[
      if (repo.critical > 0)
        _SevChip(label: 'C', count: repo.critical, color: _critical),
      if (repo.high > 0) _SevChip(label: 'H', count: repo.high, color: _high),
      if (repo.medium > 0)
        _SevChip(label: 'M', count: repo.medium, color: _medium),
      if (repo.low > 0) _SevChip(label: 'L', count: repo.low, color: _low),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.gpp_maybe_outlined,
              size: 18,
              color: repo.critical > 0 || repo.high > 0 ? _high : _medium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                repo.repoDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Wrap(spacing: 4, children: chips),
            if (repo.capped)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '100+',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SevChip extends StatelessWidget {
  const _SevChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label $count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({required this.release});
  final ReleaseItem release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = release.name != null && release.name != release.tag
        ? '${release.tag} · ${release.name}'
        : release.tag;
    final published = release.publishedAt;
    final meta = [
      release.repoDisplay,
      if (published != null) relativeTime(published),
      if (release.author != null) release.author!,
    ].join(' · ');
    final url = release.url;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: url == null ? null : () => openUrl(url),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.new_releases_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
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
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
        ),
      ),
    );
  }
}
