import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tiptip_colors.dart';

/// Yuvarlatılmış kutu içinde stilize damla ve yıldız — onboarding / marka.
class TiptipLogoMark extends StatelessWidget {
  const TiptipLogoMark({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: TiptipColors.surfaceLevel1,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: TiptipColors.accentTurquoise.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: CustomPaint(
          painter: _DropletStarPainter(),
          size: Size.square(size * 0.72),
        ),
      ),
    );
  }
}

class _DropletStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    final Path droplet = _waterDropletPath(bounds);
    final Paint dropletFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[TiptipColors.accentTurquoise, TiptipColors.accentBlue],
      ).createShader(bounds);

    canvas.drawPath(droplet, dropletFill);

    final double starSize = size.shortestSide * 0.22;
    final Offset starCenter = Offset(
      bounds.right - size.width * 0.1,
      bounds.top + size.height * 0.12,
    );
    final Path star = _fivePointStar(starCenter, starSize);

    canvas.drawPath(star, Paint()..color = const Color(0xFFFFE082));
    canvas.drawPath(
      star,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, starSize * 0.06),
    );
  }

  Path _waterDropletPath(Rect bounds) {
    final double w = bounds.width;
    final double h = bounds.height;
    final double cx = bounds.center.dx;
    final double top = bounds.top + h * 0.06;
    final double bottom = bounds.bottom - h * 0.02;
    final double bulbR = w * 0.34;

    final Path path = Path();
    path.moveTo(cx, top);
    path.cubicTo(
      cx + bulbR * 1.1,
      top + bulbR * 0.2,
      cx + bulbR * 1.05,
      top + bulbR * 1.2,
      cx + bulbR * 0.75,
      top + bulbR * 1.85,
    );
    path.quadraticBezierTo(
      cx + bulbR * 0.35,
      (top + bottom) * 0.52,
      cx,
      bottom,
    );
    path.quadraticBezierTo(
      cx - bulbR * 0.35,
      (top + bottom) * 0.52,
      cx - bulbR * 0.75,
      top + bulbR * 1.85,
    );
    path.cubicTo(
      cx - bulbR * 1.05,
      top + bulbR * 1.2,
      cx - bulbR * 1.1,
      top + bulbR * 0.2,
      cx,
      top,
    );
    path.close();
    return path;
  }

  Path _fivePointStar(Offset center, double radius) {
    const int points = 5;
    final Path path = Path();
    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? radius : radius * 0.42;
      final double angle = (i * math.pi / points) - math.pi / 2;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
