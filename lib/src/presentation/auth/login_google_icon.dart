import 'package:flutter/material.dart';

/// The four vector paths from the approved Stitch export, without an
/// enclosing badge or an approximate ring glyph.
class LoginGoogleIcon extends StatelessWidget {
  const LoginGoogleIcon({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _GooglePainter()),
  );
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final red = Path()
      ..moveTo(12, 5)
      ..relativeCubicTo(1.6, 0, 3, .6, 4.1, 1.6)
      ..relativeLineTo(3.1, -3.1)
      ..cubicTo(17.3, 1.8, 14.8, 1, 12, 1)
      ..cubicTo(7.5, 1, 3.7, 3.6, 1.9, 7.3)
      ..relativeLineTo(3.7, 2.9)
      ..cubicTo(6.5, 7.4, 9, 5, 12, 5)
      ..close();
    final blue = Path()
      ..moveTo(23.5, 12.3)
      ..relativeCubicTo(0, -.8, -.1, -1.6, -.2, -2.3)
      ..lineTo(12, 10)
      ..relativeLineTo(0, 4.5)
      ..relativeLineTo(6.5, 0)
      ..relativeCubicTo(-.3, 1.5, -1.1, 2.8, -2.4, 3.7)
      ..relativeLineTo(3.7, 2.9)
      ..relativeCubicTo(2.2, -2, 3.7, -5, 3.7, -8.8)
      ..close();
    final yellow = Path()
      ..moveTo(5.6, 14.8)
      ..relativeCubicTo(-.2, -.7, -.4, -1.5, -.4, -2.3)
      ..relativeCubicTo(0, -.8, .1, -1.6, .4, -2.3)
      ..lineTo(1.9, 7.3)
      ..cubicTo(.7, 9.7, 0, 12.3, 0, 15)
      ..relativeCubicTo(0, 2.7, .7, 5.3, 1.9, 7.7)
      ..relativeLineTo(3.7, -2.9)
      ..close();
    final green = Path()
      ..moveTo(12, 23)
      ..relativeCubicTo(3.2, 0, 6, -1.1, 8, -3)
      ..relativeLineTo(-3.7, -2.9)
      ..relativeCubicTo(-1.1, .7, -2.5, 1.2, -4.3, 1.2)
      ..relativeCubicTo(-3, 0, -5.5, -2.4, -6.4, -5.2)
      ..lineTo(1.9, 16)
      ..cubicTo(3.7, 20.4, 7.5, 23, 12, 23)
      ..close();
    canvas.drawPath(red, Paint()..color = const Color(0xFFEA4335));
    canvas.drawPath(blue, Paint()..color = const Color(0xFF4285F4));
    canvas.drawPath(yellow, Paint()..color = const Color(0xFFFBBC05));
    canvas.drawPath(green, Paint()..color = const Color(0xFF34A853));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
