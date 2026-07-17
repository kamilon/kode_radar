import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../metric_snapshot.dart';
import 'views_common.dart';

/// Overlaid activity-score trend lines for the most active repos over the
/// snapshot history — the "are we speeding up or slowing down" view.
class TrendLinesView extends StatelessWidget {
  const TrendLinesView({super.key, required this.data});

  final InsightsData data;

  static const _palette = <Color>[
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF558B2F),
  ];

  @override
  Widget build(BuildContext context) {
    // Repos with at least 2 snapshots, ranked by their latest activity score.
    final series = <_Series>[];
    data.history.forEach((key, snaps) {
      if (snaps.length < 2) return;
      final name =
          data.activities
              .where((a) => a.repoKey == key)
              .map((a) => a.displayName)
              .firstOrNull ??
          key;
      series.add(_Series(name.split('/').last, snaps));
    });
    series.sort(
      (a, b) =>
          b.snaps.last.activityScore.compareTo(a.snaps.last.activityScore),
    );
    final top = series.take(_palette.length).toList();

    return ViewScaffold(
      title: 'Trends',
      loadedAt: data.loadedAt,
      child: top.isEmpty
          ? const ViewEmpty(
              message:
                  'Trends need at least two daily snapshots per repo.\nKeep the app around and they fill in.',
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                    child: LayoutBuilder(
                      builder: (context, c) => CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: _TrendPainter(
                          series: top,
                          colors: _palette,
                          axisColor: Theme.of(context).colorScheme.outline,
                          gridColor: Theme.of(
                            context,
                          ).colorScheme.outlineVariant,
                          labelColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                _legend(context, top),
              ],
            ),
    );
  }

  Widget _legend(BuildContext context, List<_Series> top) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          for (var i = 0; i < top.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 3, color: _palette[i]),
                const SizedBox(width: 5),
                Text(
                  top[i].name,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Series {
  _Series(this.name, this.snaps);
  final String name;
  final List<MetricSnapshot> snaps;
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.series,
    required this.colors,
    required this.axisColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<_Series> series;
  final List<Color> colors;
  final Color axisColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 32.0, padB = 18.0, padT = 6.0, padR = 6.0;
    final plot = Rect.fromLTRB(
      padL,
      padT,
      size.width - padR,
      size.height - padB,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    var minT = double.infinity, maxT = -double.infinity, maxV = 0.0;
    for (final s in series) {
      for (final snap in s.snaps) {
        final t = snap.at.millisecondsSinceEpoch.toDouble();
        minT = math.min(minT, t);
        maxT = math.max(maxT, t);
        maxV = math.max(maxV, snap.activityScore.toDouble());
      }
    }
    if (!minT.isFinite || maxT <= minT) return;
    maxV = math.max(maxV, 1);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
    for (var i = 1; i <= 4; i++) {
      final gy = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), gridPaint);
      _text(
        canvas,
        (maxV * i / 4).round().toString(),
        Offset(plot.left - 4, gy - 5),
      );
    }

    for (var i = 0; i < series.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      final snaps = series[i].snaps;
      for (var j = 0; j < snaps.length; j++) {
        final t = snaps[j].at.millisecondsSinceEpoch.toDouble();
        final x = plot.left + plot.width * (t - minT) / (maxT - minT);
        final y =
            plot.bottom -
            plot.height * (snaps[j].activityScore.toDouble() / maxV);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(
          Offset(x, y),
          2,
          Paint()..color = colors[i % colors.length],
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _text(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width, at.dy));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.series != series;
}
