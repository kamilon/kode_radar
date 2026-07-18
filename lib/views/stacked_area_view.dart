import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'views_common.dart';

/// A stacked-area chart of activity score over time, composed of the busiest
/// repos — shows how much each repo contributes to overall momentum day to day.
class StackedAreaView extends StatelessWidget {
  const StackedAreaView({super.key, required this.data});

  final InsightsData data;

  static const _palette = <Color>[
    Color(0xFF1565C0),
    Color(0xFF00897B),
    Color(0xFF7CB342),
    Color(0xFFF9A825),
    Color(0xFFEF6C00),
    Color(0xFFC62828),
  ];

  @override
  Widget build(BuildContext context) {
    // Union of all snapshot days.
    final daySet = <DateTime>{};
    for (final snaps in data.history.values) {
      for (final s in snaps) {
        daySet.add(DateTime.utc(s.at.year, s.at.month, s.at.day));
      }
    }
    final days = daySet.toList()..sort();

    // Per-repo activity-by-day keyed by repoKey (not the leaf name, which can
    // collide across orgs), ranked by total contribution; keep top N + rest.
    final byRepo = <String, Map<DateTime, double>>{};
    final totals = <String, double>{};
    final labels = <String, String>{};
    data.history.forEach((key, snaps) {
      final name =
          data.activities
              .where((a) => a.repoKey == key)
              .map((a) => a.displayName)
              .fold<String?>(null, (p, e) => p ?? e) ??
          key;
      labels[key] = name.split('/').last;
      final map = <DateTime, double>{};
      var total = 0.0;
      for (final s in snaps) {
        final d = DateTime.utc(s.at.year, s.at.month, s.at.day);
        map[d] = (map[d] ?? 0) + s.activityScore.toDouble();
        total += s.activityScore.toDouble();
      }
      byRepo[key] = map;
      totals[key] = total;
    });
    final ranked = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final top = ranked.take(_palette.length - 1).toList();

    // Build stacked layers (top repos, then "other").
    final layers = <_Layer>[];
    for (var i = 0; i < top.length; i++) {
      layers.add(
        _Layer(labels[top[i]] ?? top[i], byRepo[top[i]]!, _palette[i]),
      );
    }
    if (ranked.length > top.length) {
      final other = <DateTime, double>{};
      for (final key in ranked.skip(top.length)) {
        byRepo[key]!.forEach((d, v) => other[d] = (other[d] ?? 0) + v);
      }
      layers.add(_Layer('other', other, _palette.last));
    }

    final enough = days.length >= 2 && layers.isNotEmpty;

    return ViewScaffold(
      title: 'Stacked activity',
      loadedAt: data.loadedAt,
      child: !enough
          ? const ViewEmpty(
              message:
                  'Stacked trends need at least two days of snapshots.\nThey fill in as the app is used over time.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      scoreNote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                    child: LayoutBuilder(
                      builder: (context, c) => CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: _StackPainter(
                          days: days,
                          layers: layers,
                          axisColor: Theme.of(context).colorScheme.outline,
                          labelColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final l in layers)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, color: l.color),
                            const SizedBox(width: 5),
                            Text(
                              l.name,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Layer {
  const _Layer(this.name, this.byDay, this.color);
  final String name;
  final Map<DateTime, double> byDay;
  final Color color;
}

class _StackPainter extends CustomPainter {
  _StackPainter({
    required this.days,
    required this.layers,
    required this.axisColor,
    required this.labelColor,
  });

  final List<DateTime> days;
  final List<_Layer> layers;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 30.0, padB = 16.0, padT = 6.0, padR = 6.0;
    final plot = Rect.fromLTRB(
      padL,
      padT,
      size.width - padR,
      size.height - padB,
    );
    if (plot.width <= 0 || plot.height <= 0 || days.length < 2) return;

    // Column totals to find the max stacked height.
    var maxTotal = 1.0;
    for (final d in days) {
      var t = 0.0;
      for (final l in layers) {
        t += l.byDay[d] ?? 0;
      }
      maxTotal = math.max(maxTotal, t);
    }

    double xFor(int i) => plot.left + plot.width * i / (days.length - 1);
    double yFor(double v) => plot.bottom - plot.height * (v / maxTotal);

    // Draw from top of stack down so earlier (bigger) layers sit at the bottom.
    final cumulative = List<double>.filled(days.length, 0);
    for (final layer in layers) {
      final top = Path();
      final bottom = <Offset>[];
      for (var i = 0; i < days.length; i++) {
        final base = cumulative[i];
        final add = layer.byDay[days[i]] ?? 0;
        final upper = base + add;
        final p = Offset(xFor(i), yFor(upper));
        if (i == 0) {
          top.moveTo(p.dx, p.dy);
        } else {
          top.lineTo(p.dx, p.dy);
        }
        bottom.add(Offset(xFor(i), yFor(base)));
        cumulative[i] = upper;
      }
      for (var i = bottom.length - 1; i >= 0; i--) {
        top.lineTo(bottom[i].dx, bottom[i].dy);
      }
      top.close();
      canvas.drawPath(
        top,
        Paint()..color = layer.color.withValues(alpha: 0.85),
      );
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
  }

  @override
  bool shouldRepaint(covariant _StackPainter old) =>
      old.layers != layers || old.days != days;
}
