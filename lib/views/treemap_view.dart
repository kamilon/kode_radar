import 'package:flutter/material.dart';

import '../activity_service.dart';
import 'views_common.dart';

/// A treemap where each repo's area is proportional to its activity score and
/// its color reflects freshness — a compact "where is the energy" overview.
class TreemapView extends StatelessWidget {
  const TreemapView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final repos = data.healthy.where((a) => a.activityScore > 0).toList()
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));

    return ViewScaffold(
      title: 'Treemap',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'No activity to lay out yet.')
          : Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, c) {
                  final cells = _squarify(
                    repos,
                    Rect.fromLTWH(0, 0, c.maxWidth, c.maxHeight),
                  );
                  return Stack(
                    children: [for (final cell in cells) _tile(context, cell)],
                  );
                },
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, _Cell cell) {
    final r = cell.rect;
    final color = freshnessColor(cell.repo.lastActivity);
    final showLabel = r.width > 54 && r.height > 30;
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: InkWell(
          onTap: () => openUrl(cell.repo.url),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(4),
            child: showLabel
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cell.repo.displayName.split('/').last,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onColorFor(color),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (r.height > 46)
                        Text(
                          '${cell.repo.openPrCount} PR',
                          style: TextStyle(
                            color: onColorFor(color).withValues(alpha: 0.9),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Simple longest-axis binary-split treemap: partitions items ~50/50 by value
  /// and splits along the longer side, which keeps cells reasonably square
  /// without a full squarified pass.
  static List<_Cell> _squarify(List<RepoActivity> repos, Rect rect) {
    final cells = <_Cell>[];
    void layout(List<RepoActivity> items, Rect r) {
      if (items.isEmpty || r.width <= 0 || r.height <= 0) return;
      if (items.length == 1) {
        cells.add(_Cell(items.first, r));
        return;
      }
      final total = items.fold<double>(0, (s, a) => s + a.activityScore);
      var acc = 0.0;
      var split = 0;
      for (; split < items.length - 1; split++) {
        if (acc + items[split].activityScore >= total / 2) break;
        acc += items[split].activityScore;
      }
      split = split.clamp(0, items.length - 2);
      final left = items.sublist(0, split + 1);
      final right = items.sublist(split + 1);
      final leftVal = left.fold<double>(0, (s, a) => s + a.activityScore);
      final frac = total == 0 ? 0.5 : (leftVal / total).clamp(0.1, 0.9);
      if (r.width >= r.height) {
        final w = r.width * frac;
        layout(left, Rect.fromLTWH(r.left, r.top, w, r.height));
        layout(right, Rect.fromLTWH(r.left + w, r.top, r.width - w, r.height));
      } else {
        final h = r.height * frac;
        layout(left, Rect.fromLTWH(r.left, r.top, r.width, h));
        layout(right, Rect.fromLTWH(r.left, r.top + h, r.width, r.height - h));
      }
    }

    layout(repos, rect);
    return cells;
  }
}

class _Cell {
  const _Cell(this.repo, this.rect);
  final RepoActivity repo;
  final Rect rect;
}
