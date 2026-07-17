import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../team.dart';
import '../team_service.dart';
import 'views_common.dart';

/// One radar/spider chart per team across five normalized dimensions, so team
/// "shapes" can be compared at a glance.
class TeamRadarView extends StatelessWidget {
  const TeamRadarView({super.key, required this.data});

  final InsightsData data;

  static const _axes = [
    'Open PRs',
    'Review',
    'Oldest PR',
    'Activity',
    'People',
  ];

  @override
  Widget build(BuildContext context) {
    final teams = data.teams;

    // Per-axis maxima across teams for normalization.
    double maxOpen = 1, maxReview = 1, maxAge = 1, maxAct = 1, maxPeople = 1;
    for (final t in teams) {
      final r = data.rollups[t.id];
      if (r == null) continue;
      maxOpen = math.max(maxOpen, r.openPrs.toDouble());
      maxReview = math.max(maxReview, r.needsReview.toDouble());
      maxAge = math.max(maxAge, (r.oldestOpenPrAgeDays ?? 0).toDouble());
      maxAct = math.max(maxAct, r.activityScore.toDouble());
      maxPeople = math.max(maxPeople, r.contributors.length.toDouble());
    }

    return ViewScaffold(
      title: 'Team radar',
      loadedAt: data.loadedAt,
      child: teams.isEmpty
          ? const ViewEmpty(
              message:
                  'No teams yet. Create teams (More → Teams) to compare their shapes here.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: teams.length,
              itemBuilder: (context, i) {
                final team = teams[i];
                final r = data.rollups[team.id];
                final values = r == null
                    ? <double>[0, 0, 0, 0, 0]
                    : <double>[
                        r.openPrs / maxOpen,
                        r.needsReview / maxReview,
                        (r.oldestOpenPrAgeDays ?? 0) / maxAge,
                        r.activityScore / maxAct,
                        r.contributors.length / maxPeople,
                      ];
                return _card(context, team, r, values);
              },
            ),
    );
  }

  Widget _card(
    BuildContext context,
    Team team,
    TeamRollup? rollup,
    List<double> values,
  ) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _RadarPainter(
                  values: values,
                  axes: _axes,
                  fill: color,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                  labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              rollup == null
                  ? '—'
                  : '${rollup.repoCount} repos · ${rollup.openPrs} PRs',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.axes,
    required this.fill,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> axes;
  final Color fill;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    if (radius <= 0) return;
    final n = values.length;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Concentric rings.
    for (var ring = 1; ring <= 3; ring++) {
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * i / n;
        final r = radius * ring / 3;
        final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Spokes + axis labels.
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      final edge =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(center, edge, gridPaint);
      final labelPos =
          center +
          Offset(
            math.cos(angle) * (radius + 10),
            math.sin(angle) * (radius + 10),
          );
      final tp = TextPainter(
        text: TextSpan(
          text: axes[i],
          style: TextStyle(color: labelColor, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    // Value polygon.
    final valuePath = Path();
    for (var i = 0; i <= n; i++) {
      final idx = i % n;
      final angle = -math.pi / 2 + 2 * math.pi * idx / n;
      final r = radius * values[idx].clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(valuePath, Paint()..color = fill.withValues(alpha: 0.25));
    canvas.drawPath(
      valuePath,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.values != values;
}
