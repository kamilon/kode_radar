import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../activity_service.dart';
import 'views_common.dart';

/// A 2×2 triage quadrant: repos plotted by staleness (x) and open-PR load (y).
/// The top-right "act now" corner holds stale repos still carrying work.
class QuadrantView extends StatelessWidget {
  const QuadrantView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final repos = data.healthy
        .where((a) => a.openPrCount > 0 || a.lastActivity != null)
        .toList();

    return ViewScaffold(
      title: 'Triage quadrant',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'Nothing to triage yet.')
          : Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, c) => CustomPaint(
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _QuadrantPainter(
                    repos: repos,
                    now: now,
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    mutedColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    axisColor: Theme.of(context).colorScheme.outline,
                    dividerColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

class _QuadrantPainter extends CustomPainter {
  _QuadrantPainter({
    required this.repos,
    required this.now,
    required this.labelColor,
    required this.mutedColor,
    required this.axisColor,
    required this.dividerColor,
  });

  final List<RepoActivity> repos;
  final DateTime now;
  final Color labelColor;
  final Color mutedColor;
  final Color axisColor;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 30.0, padB = 22.0, padT = 8.0, padR = 8.0;
    final plot = Rect.fromLTRB(
      padL,
      padT,
      size.width - padR,
      size.height - padB,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    // Axis maxima leave room for the fixed thresholds to sit inside the plot
    // even for small datasets, so a single low-activity repo doesn't get pushed
    // into "act now".
    const staleThreshold = 7; // days quiet
    const loadThreshold = 3; // open PRs
    final maxStale = math.max(
      staleThreshold * 2,
      repos
          .map((r) => daysSince(r.lastActivity, now: now) ?? 0)
          .fold<int>(1, math.max),
    );
    final maxLoad = math.max(
      loadThreshold * 2,
      repos.map((r) => r.openPrCount).fold<int>(1, math.max),
    );

    // Dividers at meaningful FIXED thresholds (not the visual midpoint).
    final divX = plot.left + plot.width * (staleThreshold / maxStale);
    final divY = plot.bottom - plot.height * (loadThreshold / maxLoad);

    // Quadrant tints (top-right = stale & loaded = act now = red).
    final tints = [
      (
        Rect.fromLTRB(divX, plot.top, plot.right, divY),
        const Color(0x22C62828),
      ),
      (Rect.fromLTRB(plot.left, plot.top, divX, divY), const Color(0x221565C0)),
      (
        Rect.fromLTRB(plot.left, divY, divX, plot.bottom),
        const Color(0x222E7D32),
      ),
      (
        Rect.fromLTRB(divX, divY, plot.right, plot.bottom),
        const Color(0x22EF6C00),
      ),
    ];
    for (final (rect, color) in tints) {
      canvas.drawRect(rect, Paint()..color = color);
    }

    final divider = Paint()
      ..color = dividerColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(divX, plot.top), Offset(divX, plot.bottom), divider);
    canvas.drawLine(Offset(plot.left, divY), Offset(plot.right, divY), divider);

    // Corner labels.
    _text(
      canvas,
      'act now',
      Offset(plot.right - 6, plot.top + 4),
      mutedColor,
      TextAlign.right,
    );
    _text(
      canvas,
      'busy',
      Offset(plot.left + 6, plot.top + 4),
      mutedColor,
      TextAlign.left,
    );
    _text(
      canvas,
      'healthy',
      Offset(plot.left + 6, plot.bottom - 16),
      mutedColor,
      TextAlign.left,
    );
    _text(
      canvas,
      'dormant',
      Offset(plot.right - 6, plot.bottom - 16),
      mutedColor,
      TextAlign.right,
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
    _text(
      canvas,
      'stale →',
      Offset(plot.right, plot.bottom + 4),
      mutedColor,
      TextAlign.right,
    );

    var labelled = 0;
    for (final r in repos) {
      final stale = daysSince(r.lastActivity, now: now) ?? maxStale;
      final x = plot.left + plot.width * (stale / maxStale);
      final y = plot.bottom - plot.height * (r.openPrCount / maxLoad);
      final color = ciColor(r.ciStatus);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = color.withValues(alpha: 0.7),
      );
      // Only label the actionable "act now" repos (stale AND loaded), capped,
      // so a large fleet doesn't turn into an unreadable wall of text.
      if (stale >= staleThreshold &&
          r.openPrCount >= loadThreshold &&
          labelled < 8) {
        labelled++;
        _text(
          canvas,
          r.displayName.split('/').last,
          Offset(x + 7, y - 6),
          labelColor,
          TextAlign.left,
          9,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    TextAlign align, [
    double size = 10,
  ]) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 110);
    final dx = align == TextAlign.right ? at.dx - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _QuadrantPainter old) => old.repos != repos;
}
