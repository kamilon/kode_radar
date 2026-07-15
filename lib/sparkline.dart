import 'dart:math' as math;

import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 24,
    this.width = 80,
  });

  final List<num> values;
  final Color? color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: List<num>.of(values),
          color: paintColor,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<num> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.min(2.0, math.max(1.0, size.height / 12))
      ..style = PaintingStyle.stroke;

    if (values.length == 1) {
      final radius = math.min(
        3.0,
        math.max(1.0, math.min(size.width, size.height) / 4),
      );
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    var minValue = values.first.toDouble();
    var maxValue = minValue;
    for (final value in values.skip(1)) {
      final doubleValue = value.toDouble();
      minValue = math.min(minValue, doubleValue);
      maxValue = math.max(maxValue, doubleValue);
    }

    final range = maxValue - minValue;
    final lastIndex = values.length - 1;
    final path = Path();

    for (var index = 0; index < values.length; index += 1) {
      final value = values[index].toDouble();
      final normalized = range == 0 ? 0.5 : (value - minValue) / range;
      final point = Offset(
        size.width * index / lastIndex,
        size.height - (normalized * size.height),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.color != color ||
        oldDelegate.values.length != values.length) {
      return true;
    }

    for (var index = 0; index < values.length; index += 1) {
      if (oldDelegate.values[index] != values[index]) {
        return true;
      }
    }

    return false;
  }
}
