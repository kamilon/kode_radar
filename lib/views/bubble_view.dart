import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../activity_service.dart';
import 'views_common.dart';

/// A scatter plot positioning each repo by oldest-open-PR age (x) and open PR
/// count (y), sized by activity and colored by CI. Repos drifting up-and-right
/// are the ones piling up work.
class BubbleView extends StatelessWidget {
  const BubbleView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final repos = data.healthy
        .where((a) => a.openPrCount > 0 || (a.oldestOpenPrAgeDays ?? 0) > 0)
        .toList();

    return ViewScaffold(
      title: 'Bubble chart',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'No open PRs to plot.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'X: oldest open PR age  ·  Y: open PR count  ·  size: activity  ·  color: CI',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) => CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _BubblePainter(
                          repos: repos,
                          labelColor: Theme.of(context).colorScheme.onSurface,
                          axisColor: Theme.of(context).colorScheme.outline,
                          gridColor: Theme.of(
                            context,
                          ).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.repos,
    required this.labelColor,
    required this.axisColor,
    required this.gridColor,
  });

  final List<RepoActivity> repos;
  final Color labelColor;
  final Color axisColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 34.0, padB = 26.0, padT = 8.0, padR = 8.0;
    final plot = Rect.fromLTRB(
      padL,
      padT,
      size.width - padR,
      size.height - padB,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxX = math.max(
      1,
      repos.map((r) => r.oldestOpenPrAgeDays ?? 0).fold<int>(1, math.max),
    );
    final maxY = math.max(
      1,
      repos.map((r) => r.openPrCount).fold<int>(1, math.max),
    );
    final maxScore = repos
        .map((r) => r.activityScore.toDouble())
        .fold<double>(1, math.max);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Axes.
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);

    // Gridlines + ticks (4 divisions each).
    for (var i = 1; i <= 4; i++) {
      final gx = plot.left + plot.width * i / 4;
      canvas.drawLine(Offset(gx, plot.top), Offset(gx, plot.bottom), gridPaint);
      _text(
        canvas,
        '${(maxX * i / 4).round()}',
        Offset(gx, plot.bottom + 4),
        labelColor,
        9,
        TextAlign.center,
      );
      final gy = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), gridPaint);
      _text(
        canvas,
        '${(maxY * i / 4).round()}',
        Offset(plot.left - 4, gy - 5),
        labelColor,
        9,
        TextAlign.right,
      );
    }

    // Bubbles (largest first so small ones stay clickable/visible on top).
    final sorted = [...repos]
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));
    for (final r in sorted) {
      final x = plot.left + plot.width * ((r.oldestOpenPrAgeDays ?? 0) / maxX);
      final y = plot.bottom - plot.height * (r.openPrCount / maxY);
      final t = maxScore == 0 ? 0.0 : r.activityScore.toDouble() / maxScore;
      final radius = 5.0 + 18.0 * math.sqrt(t.clamp(0, 1));
      final color = ciColor(r.ciStatus);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Label only the top few by activity to avoid clutter.
    for (final r in sorted.take(5)) {
      final x = plot.left + plot.width * ((r.oldestOpenPrAgeDays ?? 0) / maxX);
      final y = plot.bottom - plot.height * (r.openPrCount / maxY);
      final name = r.displayName.split('/').last;
      _text(canvas, name, Offset(x + 6, y - 6), labelColor, 10, TextAlign.left);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double size,
    TextAlign align,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final dx = switch (align) {
      TextAlign.center => at.dx - tp.width / 2,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.repos != repos;
}
