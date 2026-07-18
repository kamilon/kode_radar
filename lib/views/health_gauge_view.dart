import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'views_common.dart';

/// A single composite "fleet health" score (0–100) on a gauge, with the
/// contributing factors broken out so the number is explainable.
class HealthGaugeView extends StatelessWidget {
  const HealthGaugeView({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final repos = data.healthy;
    final now = DateTime.now();

    // Each factor is a 0..1 score (1 = healthy).
    // CI factor: pass rate among repos with a definitive result (success vs
    // failure). When NO repo has a definitive result it's omitted entirely (not
    // defaulted to 1.0), so the score never reads as "100% CI passing" with no
    // CI data.
    final success = repos.where((a) => a.ciStatus == 'success').length;
    final failure = repos.where((a) => a.ciStatus == 'failure').length;
    final double? ci = (success + failure) == 0
        ? null
        : success / (success + failure);
    final fresh = repos.isEmpty
        ? 1.0
        : repos.where((a) {
                final d = daysSince(a.lastActivity, now: now);
                return d != null && d <= 7;
              }).length /
              repos.length;
    final aging = repos.isEmpty
        ? 1.0
        : repos.where((a) => (a.oldestOpenPrAgeDays ?? 0) <= 14).length /
              repos.length;
    final totalOpen = repos.fold<int>(0, (s, a) => s + a.openPrCount);
    final totalReview = repos.fold<int>(0, (s, a) => s + a.needsReviewCount);
    final review = totalOpen == 0
        ? 1.0
        : (1 - (totalReview / totalOpen)).clamp(0.0, 1.0);

    final factors = <({String label, double value})>[
      if (ci != null) (label: 'CI passing', value: ci),
      (label: 'Recently active', value: fresh),
      (label: 'PRs not aging', value: aging),
      (label: 'Review kept up', value: review),
    ];
    final score = (repos.isEmpty || factors.isEmpty)
        ? 0
        : (factors.fold<double>(0, (s, f) => s + f.value) /
                  factors.length *
                  100)
              .round();

    return ViewScaffold(
      title: 'Fleet health',
      loadedAt: data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'No repositories to score.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _GaugePainter(
                      score: score / 100,
                      color: heatColor(1 - score / 100),
                      trackColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      labelColor: Theme.of(context).colorScheme.onSurface,
                      scoreText: '$score',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final f in factors) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text('${(f.value * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: f.value,
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: heatColor(1 - f.value),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.score,
    required this.color,
    required this.trackColor,
    required this.labelColor,
    required this.scoreText,
  });

  final double score; // 0..1
  final Color color;
  final Color trackColor;
  final Color labelColor;
  final String scoreText;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = math.min(size.width / 2, size.height * 0.9) - 12;
    if (radius <= 0) return;
    const startAngle = math.pi; // 180°, left
    const sweepFull = math.pi; // half circle

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull,
      false,
      track,
    );

    final value = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull * score.clamp(0.0, 1.0),
      false,
      value,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: scoreText,
        style: TextStyle(
          color: labelColor,
          fontSize: 44,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height + 4));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.score != score;
}
