import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../theme/tiptip_colors.dart';
import 'gameplay_mode.dart';
import 'object_pool.dart';

/// Oyun alanı animasyon durumu — [CustomPaint.repaint] ile bağlanır.
class PlayAreaAnimationEngine extends ChangeNotifier {
  PlayAreaAnimationEngine(this.tickerProvider) {
    _ticker = tickerProvider.createTicker(_onTick);
  }

  final TickerProvider tickerProvider;
  late final Ticker _ticker;

  final ObjectPool<_RippleRing> _ripplePool = ObjectPool<_RippleRing>(
    _RippleRing.new,
  );
  final ObjectPool<_StarParticle> _starPool = ObjectPool<_StarParticle>(
    _StarParticle.new,
  );

  final List<_RippleRing> _ripples = <_RippleRing>[];
  final List<_StarParticle> _stars = <_StarParticle>[];

  Duration? _lastElapsed;
  bool _ticking = false;

  static const int _ringsPerTap = 4;
  static const double _rippleDurationMs = 1650;
  static const double _ringStaggerMs = 95;
  static const int _starCount = 14;
  static const double _starLifeMs = 980;
  static const double _starBaseSpeed = 220;

  bool get hasActiveEffects => _ripples.isNotEmpty || _stars.isNotEmpty;

  void handleTap(Offset localPosition, Size areaSize, GameplayMode mode) {
    switch (mode) {
      case GameplayMode.water:
        _spawnRipples(
          localPosition,
          areaSize,
          RipplePaintStyle.circle,
          const Color(0xFF0284C7),
        );
        break;
      case GameplayMode.geometric:
        _spawnRipples(
          localPosition,
          areaSize,
          RipplePaintStyle.hexagon,
          const Color(0xFF7C3AED),
        );
        break;
      case GameplayMode.star:
        _spawnStarBurst(localPosition);
        break;
    }
    _ensureTicker();
  }

  void _spawnRipples(
    Offset origin,
    Size areaSize,
    RipplePaintStyle style,
    Color strokeColor,
  ) {
    final double maxR = math.min(areaSize.width, areaSize.height) * 0.42;
    for (int i = 0; i < _ringsPerTap; i++) {
      final _RippleRing r = _ripplePool.acquire();
      r
        ..center = origin
        ..delayMs = i * _ringStaggerMs
        ..ageMs = 0
        ..durationMs = _rippleDurationMs
        ..maxRadius = maxR
        ..ringIndex = i
        ..style = style
        ..strokeColor = strokeColor
        ..alive = true;
      _ripples.add(r);
    }
    notifyListeners();
  }

  void _spawnStarBurst(Offset origin) {
    final math.Random rng = math.Random();
    for (int i = 0; i < _starCount; i++) {
      final _StarParticle p = _starPool.acquire();
      final double angle = rng.nextDouble() * math.pi * 2;
      final double speed = _starBaseSpeed * (0.75 + rng.nextDouble() * 0.55);
      p
        ..position = origin
        ..vx = math.cos(angle) * speed
        ..vy = math.sin(angle) * speed
        ..ageMs = 0
        ..lifeMs = _starLifeMs
        ..rotation = rng.nextDouble() * math.pi * 2
        ..spin = (rng.nextBool() ? 1 : -1) * (1.8 + rng.nextDouble() * 2.4)
        ..hueShift = rng.nextDouble() * 0.15
        ..alive = true;
      _stars.add(p);
    }
    notifyListeners();
  }

  void _ensureTicker() {
    if (_ticking) {
      return;
    }
    _ticking = true;
    _lastElapsed = null;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final double dtMs = _lastElapsed == null
        ? 16.7
        : (elapsed - _lastElapsed!).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;

    final bool hadEffects = hasActiveEffects;
    _updateRipples(dtMs);
    _updateStars(dtMs);

    if (hasActiveEffects) {
      notifyListeners();
    } else {
      if (hadEffects) {
        notifyListeners();
      }
      _ticker.stop();
      _ticking = false;
      _lastElapsed = null;
    }
  }

  void _updateRipples(double dtMs) {
    for (int i = _ripples.length - 1; i >= 0; i--) {
      final _RippleRing r = _ripples[i];
      r.ageMs += dtMs;
      final double waveAge = r.ageMs - r.delayMs;
      if (waveAge >= r.durationMs) {
        r.alive = false;
        _ripples.removeAt(i);
        _ripplePool.release(r);
      }
    }
  }

  void _updateStars(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    for (int i = _stars.length - 1; i >= 0; i--) {
      final _StarParticle p = _stars[i];
      p.ageMs += dtMs;
      p.position = Offset(
        p.position.dx + p.vx * dtSec,
        p.position.dy + p.vy * dtSec,
      );
      p.rotation += p.spin * dtSec;
      if (p.ageMs >= p.lifeMs) {
        p.alive = false;
        _stars.removeAt(i);
        _starPool.release(p);
      }
    }
  }

  @override
  void dispose() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _ticker.dispose();
    super.dispose();
  }

  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint bg = Paint()..color = TiptipColors.background;
    canvas.drawRect(rect, bg);

    for (final _RippleRing r in _ripples) {
      _paintRippleRing(canvas, r);
    }
    for (final _StarParticle p in _stars) {
      _paintStarParticle(canvas, p);
    }
  }

  void _paintRippleRing(Canvas canvas, _RippleRing r) {
    final double waveAge = r.ageMs - r.delayMs;
    if (waveAge < 0) {
      return;
    }
    final double t = (waveAge / r.durationMs).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(t);
    final double radius = eased * r.maxRadius;
    final double opacity =
        Curves.easeOut.transform(1 - eased) *
        (0.58 - r.ringIndex * 0.1).clamp(0.22, 0.58);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 + (1.0 - eased) * 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = r.strokeColor.withValues(alpha: opacity);

    switch (r.style) {
      case RipplePaintStyle.circle:
        canvas.drawCircle(r.center, radius, stroke);
        canvas.drawCircle(
          r.center,
          radius * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.strokeWidth * 0.52
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = r.strokeColor.withValues(alpha: opacity * 0.45),
        );
        break;
      case RipplePaintStyle.hexagon:
        final Path hex = _hexPath(r.center, radius);
        canvas.drawPath(hex, stroke);
        break;
    }
  }

  Path _hexPath(Offset c, double radius) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (math.pi / 3) * i - math.pi / 6;
      final double x = c.dx + radius * math.cos(angle);
      final double y = c.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _paintStarParticle(Canvas canvas, _StarParticle p) {
    final double t = (p.ageMs / p.lifeMs).clamp(0.0, 1.0);
    final double scale =
        ui.lerpDouble(0, 1.5, Curves.easeOut.transform(t)) ?? 0;
    final double opacity = (1.0 - t) * (1.0 - t * 0.35);
    if (opacity <= 0.01 || scale <= 0.001) {
      return;
    }

    const double outer = 11;
    final Color base = Color.lerp(
      const Color(0xFFFFE082),
      const Color(0xFFEAB308),
      p.hueShift,
    )!;

    canvas.save();
    canvas.translate(p.position.dx, p.position.dy);
    canvas.rotate(p.rotation);
    canvas.scale(scale);

    final Path star = _starPath(
      const Offset(0, 0),
      outerR: outer,
      innerR: outer * 0.42,
    );

    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = base.withValues(alpha: opacity);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: opacity * 0.55);

    canvas.drawPath(star, fill);
    canvas.drawPath(star, stroke);
    canvas.restore();
  }

  /// Yuvarlatılmış çizgi birleşimli beş köşeli yıldız.
  Path _starPath(Offset c, {required double outerR, required double innerR}) {
    const int points = 5;
    final Path path = Path();
    for (int i = 0; i < points * 2; i++) {
      final double a = -math.pi / 2 + (i * math.pi / points);
      final double r = i.isEven ? outerR : innerR;
      final double x = c.dx + r * math.cos(a);
      final double y = c.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}

enum RipplePaintStyle { circle, hexagon }

class _RippleRing {
  Offset center = Offset.zero;
  double ageMs = 0;
  double delayMs = 0;
  double durationMs = 1500;
  double maxRadius = 100;
  int ringIndex = 0;
  RipplePaintStyle style = RipplePaintStyle.circle;
  Color strokeColor = const Color(0xFF0284C7);
  bool alive = false;
}

class _StarParticle {
  Offset position = Offset.zero;
  double vx = 0;
  double vy = 0;
  double ageMs = 0;
  double lifeMs = 900;
  double rotation = 0;
  double spin = 2;
  double hueShift = 0;
  bool alive = false;
}

/// [PlayAreaAnimationEngine] çizimini [repaint] ile bağlar.
class PlayAreaPainter extends CustomPainter {
  PlayAreaPainter(this.engine) : super(repaint: engine);

  final PlayAreaAnimationEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    engine.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant PlayAreaPainter oldDelegate) => false;
}
