import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_status_colors.dart';

/// Vector nativo del SVG en assets/logo/encuentralo_escom_logo.svg.
/// Mantiene su geometría de 120 × 120 y permite iluminar cada tramo sin plugins.
class AnimatedCircuitLogo extends StatelessWidget {
  const AnimatedCircuitLogo({
    super.key,
    required this.progress,
    this.size = 176,
  });

  final Animation<double> progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Logotipo Encuéntralo ESCOM: circuito en forma de E',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _CircuitPainter(
              progress,
              colors,
              AppStatusColors.of(context).found.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  _CircuitPainter(this.progress, this.colors, this.foundColor)
    : super(repaint: progress);

  final Animation<double> progress;

  final ColorScheme colors;
  final Color foundColor;
  Color get _cyan => colors.tertiary;
  Color get _green => foundColor;

  // El ramal central recibe la señal antes de continuar al nodo encontrado.
  static final _upper = Path()
    ..moveTo(84, 34)
    ..lineTo(42, 34)
    ..lineTo(42, 60);
  static final _branch = Path()
    ..moveTo(42, 60)
    ..lineTo(74, 60);
  static final _lower = Path()
    ..moveTo(42, 60)
    ..lineTo(42, 86)
    ..lineTo(86, 86);

  double _phase(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    final tile = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, 88, 88),
      const Radius.circular(22),
    );
    canvas.drawRRect(tile, Paint()..color = colors.primaryContainer);
    canvas.drawRRect(
      tile,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (final path in [_upper, _branch, _lower]) {
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.onPrimaryContainer.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _cyan.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    _trace(canvas, _upper, _phase(value, 0, 0.40));
    _trace(canvas, _branch, _phase(value, 0.40, 0.58));
    _trace(canvas, _lower, _phase(value, 0.58, 0.94));

    _node(canvas, const Offset(84, 34), 5.5, _phase(value, 0, 0.06));
    _node(canvas, const Offset(42, 34), 5.5, _phase(value, 0.20, 0.27));
    final junction = _phase(value, 0.34, 0.40);
    _node(canvas, const Offset(42, 60), 6, junction, color: colors.primary);
    canvas.drawCircle(
      const Offset(42, 60),
      6,
      Paint()
        ..color = _cyan.withValues(alpha: 0.16 + junction * 0.84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _node(canvas, const Offset(74, 60), 5, _phase(value, 0.52, 0.58));
    _node(canvas, const Offset(42, 86), 5.5, _phase(value, 0.67, 0.73));

    final found = _phase(value, 0.89, 1);
    final pulse = math.sin(found * math.pi);
    canvas.drawCircle(
      const Offset(86, 86),
      11 + pulse * 4,
      Paint()
        ..color = _green.withValues(alpha: 0.08 + found * 0.27)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _node(canvas, const Offset(86, 86), 7, found, color: _green);
    canvas.restore();
  }

  void _trace(Canvas canvas, Path path, double fraction) {
    if (fraction <= 0) return;
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * fraction),
      Paint()
        ..color = _cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (fraction < 1) {
      final tip = metric
          .getTangentForOffset(metric.length * fraction)!
          .position;
      canvas.drawCircle(
        tip,
        5,
        Paint()
          ..color = _cyan.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(tip, 2, Paint()..color = colors.onPrimaryContainer);
    }
  }

  void _node(
    Canvas canvas,
    Offset center,
    double radius,
    double illumination, {
    Color? color,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = (color ?? _cyan).withValues(
          alpha: 0.16 + illumination * 0.84,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.foundColor != foundColor;
}
