import 'package:flutter/material.dart';

import '../activity_service.dart';
import 'views_common.dart';

/// Side-by-side comparison of the two providers (GitHub vs Azure DevOps) across
/// the headline metrics — useful when monitoring a mixed fleet.
class ProviderSplitView extends StatelessWidget {
  const ProviderSplitView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final gh = _tally(data.healthy.where((a) => a.provider == 'github'));
    final ado = _tally(data.healthy.where((a) => a.provider != 'github'));

    final metrics = <({String label, int gh, int ado})>[
      (label: 'Repos', gh: gh.repos, ado: ado.repos),
      (label: 'Open PRs', gh: gh.openPrs, ado: ado.openPrs),
      (label: 'Need review', gh: gh.needsReview, ado: ado.needsReview),
      (label: 'CI failing', gh: gh.failing, ado: ado.failing),
      (label: 'Contributors', gh: gh.contributors, ado: ado.contributors),
    ];

    final hasBoth = gh.repos > 0 && ado.repos > 0;

    return ViewScaffold(
      title: 'Provider split',
      loadedAt: data.loadedAt,
      child: (gh.repos == 0 && ado.repos == 0)
          ? const ViewEmpty(message: 'No repositories to compare.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _header(context, 'GitHub', const Color(0xFF24292F)),
                    const SizedBox(width: 8),
                    _header(context, 'Azure DevOps', const Color(0xFF0078D4)),
                  ],
                ),
                const SizedBox(height: 16),
                for (final m in metrics) ...[
                  Text(m.label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _dualBar(context, m.gh, m.ado),
                  const SizedBox(height: 16),
                ],
                if (!hasBoth)
                  Text(
                    'Only one provider is in use; add repos from the other to '
                    'see a real comparison.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _dualBar(BuildContext context, int gh, int ado) {
    final total = gh + ado;
    const ghColor = Color(0xFF24292F);
    const adoColor = Color(0xFF0078D4);
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$gh',
            textAlign: TextAlign.right,
            style: const TextStyle(color: ghColor, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 22,
              child: total == 0
                  ? Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    )
                  : Row(
                      children: [
                        // Only emit non-zero segments — Expanded requires
                        // flex > 0 — so a single-provider fleet shows 100:0.
                        if (gh > 0)
                          Expanded(
                            flex: gh,
                            child: Container(
                              color: ghColor.withValues(alpha: 0.85),
                            ),
                          ),
                        if (ado > 0)
                          Expanded(
                            flex: ado,
                            child: Container(
                              color: adoColor.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            '$ado',
            style: const TextStyle(
              color: adoColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static _Tally _tally(Iterable<RepoActivity> repos) {
    final contributors = <String>{};
    var openPrs = 0, needsReview = 0, failing = 0, count = 0;
    for (final a in repos) {
      count++;
      openPrs += a.openPrCount;
      needsReview += a.needsReviewCount;
      if (a.ciStatus == 'failure') failing++;
      contributors.addAll(a.contributors);
    }
    return _Tally(count, openPrs, needsReview, failing, contributors.length);
  }
}

class _Tally {
  const _Tally(
    this.repos,
    this.openPrs,
    this.needsReview,
    this.failing,
    this.contributors,
  );
  final int repos;
  final int openPrs;
  final int needsReview;
  final int failing;
  final int contributors;
}
