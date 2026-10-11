import 'package:flutter/material.dart';
import 'splash_motion.dart';

/// The Stitch emblem illustrates list -> checked items -> shopping bag.
/// Its timeline is decorative and never changes shopping data.
class SplashNotebookPainter extends CustomPainter {
  const SplashNotebookPainter({required this.colors, required this.progress});
  final ColorScheme colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 140);
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final surface = colors.brightness == Brightness.dark
        ? colors.surfaceContainerLow
        : Colors.white;
    final paper = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 18, 76, 104),
      const Radius.circular(4),
    );
    canvas.drawRRect(paper, fill..color = surface);
    canvas.drawRRect(
      paper,
      stroke
        ..color = colors.onSurface
        ..strokeWidth = 1.75,
    );
    canvas.drawPath(
      Path()
        ..moveTo(42, 18)
        ..lineTo(42, 13)
        ..quadraticBezierTo(42, 11, 44, 11)
        ..lineTo(68, 11)
        ..quadraticBezierTo(70, 11, 70, 13)
        ..lineTo(70, 18),
      stroke..strokeWidth = 1.5,
    );
    for (var x = 26.0; x < 86; x += 4) {
      canvas.drawLine(
        Offset(x, 28),
        Offset(x + 2, 28),
        stroke
          ..color = colors.outlineVariant
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < 3; i++) {
      final row = SplashMotion.row(i, progress);
      final y = 38.0 + i * 20;
      canvas.save();
      canvas.translate(8 * (1 - row), 0);
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(26, y, 10, 10),
        const Radius.circular(2),
      );
      canvas.drawRRect(box, fill..color = surface.withValues(alpha: row));
      canvas.drawRRect(
        box,
        stroke
          ..color = colors.onSurface.withValues(alpha: row)
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        Offset(42, y + 5),
        Offset([72.0, 68.0, 70.0][i], y + 5),
        stroke..strokeWidth = 1.75,
      );
      canvas.drawLine(
        Offset([77.0, 74.0, 76.0][i], y + 5),
        Offset(84, y + 5),
        stroke
          ..color = colors.onSurfaceVariant.withValues(alpha: row)
          ..strokeWidth = 1.5,
      );
      final check = SplashMotion.check(i, progress);
      final path = Path()
        ..moveTo(28.5, y + 5.2)
        ..lineTo(31.2, y + 7.8)
        ..lineTo(38, y + .5);
      final metric = path.computeMetrics().first;
      if (check > 0) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * check),
          stroke
            ..color = colors.primary
            ..strokeWidth = 1.8,
        );
      }
      canvas.restore();
    }
    canvas.drawLine(
      const Offset(26, 98),
      const Offset(86, 98),
      stroke
        ..color = colors.outlineVariant
        ..strokeWidth = 1,
    );
    final bag = SplashMotion.bag.transform(progress);
    if (bag > 0) {
      canvas.save();
      canvas.translate(12 * (1 - bag), 8 * (1 - bag));
      final body = Path()
        ..moveTo(86, 48)
        ..lineTo(132, 48)
        ..cubicTo(133.7, 48, 135, 49.3, 134.8, 51)
        ..lineTo(130.6, 114)
        ..quadraticBezierTo(130.45, 118, 126.4, 118)
        ..lineTo(90.6, 118)
        ..quadraticBezierTo(86.55, 118, 86.4, 114)
        ..lineTo(83.2, 51)
        ..quadraticBezierTo(83, 48, 86, 48)
        ..close();
      canvas.drawPath(body, fill..color = surface.withValues(alpha: bag));
      canvas.drawPath(
        body,
        stroke
          ..color = colors.onSurface.withValues(alpha: bag)
          ..strokeWidth = 1.75,
      );
      canvas.drawPath(
        Path()
          ..moveTo(97, 48)
          ..lineTo(97, 35)
          ..cubicTo(97, 29.48, 101.48, 25, 107, 25)
          ..lineTo(111, 25)
          ..cubicTo(116.52, 25, 121, 29.48, 121, 35)
          ..lineTo(121, 48),
        stroke
          ..color = colors.primary.withValues(alpha: bag)
          ..strokeWidth = 1.8,
      );
      canvas.drawPath(
        Path()
          ..moveTo(91, 62)
          ..lineTo(109, 72)
          ..lineTo(127, 62),
        stroke
          ..color = colors.outlineVariant.withValues(alpha: bag)
          ..strokeWidth = 1.25,
      );
      canvas.drawCircle(
        const Offset(109, 91),
        5,
        stroke
          ..color = colors.primary.withValues(alpha: bag)
          ..strokeWidth = 1.5,
      );
      canvas.drawPath(
        Path()
          ..moveTo(109, 87)
          ..lineTo(109, 95)
          ..moveTo(105, 91)
          ..lineTo(113, 91),
        stroke..strokeWidth = 1.25,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashNotebookPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
