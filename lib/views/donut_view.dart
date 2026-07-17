import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'views_common.dart';

/// A donut breaking down where the open PRs live: the biggest slices are the
/// repos carrying the most in-flight work.
class DonutView extends StatelessWidget {
  const DonutView({super.key, required this.data});

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
    Color(0xFF5D4037),
  ];

  @override
  Widget build(BuildContext context) {
    final repos = data.healthy.where((a) => a.openPrCount > 0).toList()
      ..sort((a, b) => b.openPrCount.compareTo(a.openPrCount));

    // Top slices, then aggregate the rest into "other".
    final slices = <_Slice>[];
    const maxSlices = 8;
    for (var i = 0; i < repos.length && i < maxSlices; i++) {
      slices.add(
        _Slice(
          repos[i].displayName.split('/').last,
          repos[i].openPrCount,
          _palette[i % _palette.length],
        ),
      );
    }
    if (repos.length > maxSlices) {
      final rest = repos
          .skip(maxSlices)
          .fold<int>(0, (s, a) => s + a.openPrCount);
      if (rest > 0) {
        slices.add(_Slice('other', rest, const Color(0xFF9E9E9E)));
      }
    }
    final total = slices.fold<int>(0, (s, x) => s + x.value);

    return ViewScaffold(
      title: 'Open PR split',
      loadedAt: data.loadedAt,
      child: slices.isEmpty
          ? const ViewEmpty(message: 'No open PRs to break down.')
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _DonutPainter(
                        slices: slices,
                        total: total,
                        centerColor: Theme.of(context).colorScheme.surface,
                        labelColor: Theme.of(context).colorScheme.onSurface,
                        totalLabel: '$total\nPRs',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final s in slices)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, color: s.color),
                            const SizedBox(width: 5),
                            Text(
                              '${s.name} (${s.value})',
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

class _Slice {
  const _Slice(this.name, this.value, this.color);
  final String name;
  final int value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.centerColor,
    required this.labelColor,
    required this.totalLabel,
  });

  final List<_Slice> slices;
  final int total;
  final Color centerColor;
  final Color labelColor;
  final String totalLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final inner = radius * 0.58;

    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = 2 * math.pi * s.value / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = s.color,
      );
      start += sweep;
    }
    // Punch the hole.
    canvas.drawCircle(center, inner, Paint()..color = centerColor);

    final tp = TextPainter(
      text: TextSpan(
        text: totalLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.total != total;
}
