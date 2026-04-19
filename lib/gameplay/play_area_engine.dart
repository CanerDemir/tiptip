import 'dart:math' as math;
import 'dart:typed_data';
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
  final ObjectPool<_JellyWobble> _jellyPool = ObjectPool<_JellyWobble>(
    _JellyWobble.new,
  );
  final ObjectPool<_NotationBit> _notationPool = ObjectPool<_NotationBit>(
    _NotationBit.new,
  );
  final ObjectPool<_FloralCore> _floralPool = ObjectPool<_FloralCore>(
    _FloralCore.new,
  );
  final ObjectPool<_FlowerPetal> _petalPool = ObjectPool<_FlowerPetal>(
    _FlowerPetal.new,
  );

  final List<_RippleRing> _ripples = <_RippleRing>[];
  final List<_StarParticle> _stars = <_StarParticle>[];
  final List<_JellyWobble> _jellies = <_JellyWobble>[];
  final List<_NotationBit> _notationBits = <_NotationBit>[];
  final List<_FloralCore> _floralCores = <_FloralCore>[];
  final List<_FlowerPetal> _flowerPetals = <_FlowerPetal>[];
  final math.Random _rng = math.Random();

  Float32List? _dustPos;
  Float32List? _dustHome;
  Float32List? _dustVel;
  Float32List? _dustPhase;
  int _dustCount = 0;
  double _dustLayoutW = 0;
  double _dustLayoutH = 0;
  bool _magnetActive = false;
  double _magnetX = 0;
  double _magnetY = 0;
  int? _magnetPointerId;
  double _dustTimeSec = 0;

  final Paint _dustVertexPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF7D8694).withValues(alpha: 0.58)
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.55
    ..isAntiAlias = true
    ..blendMode = BlendMode.srcOver;

  Duration? _lastElapsed;
  bool _ticking = false;

  static const int _ringsPerTap = 4;
  static const double _rippleDurationMs = 1650;
  static const double _ringStaggerMs = 95;
  static const int _starCount = 14;
  static const double _starLifeMs = 980;
  static const double _starBaseSpeed = 220;
  static const int _notationBurstCount = 10;
  static const double _floralSeedMs = 220;
  static const double _floralBloomMs = 520;
  static const int _floralPetalCount = 14;
  /// Bloom + flying petal size vs original art (seed stays relatively small).
  static const double _floralVisualScale = 1.68;

  static const double _dustPixelsPerParticle = 138;
  static const int _dustMinCount = 2200;
  static const int _dustMaxCount = 7800;
  static const double _dustMagnetAccel = 5200;
  static const double _dustMagnetVelDamp = 0.991;
  static const double _dustMagnetMaxSpeed = 1180;
  static const double _dustSpringK = 38;
  static const double _dustSpringDamp = 11.5;
  static const double _dustFloatAmpPx = 5.2;
  static const double _dustFloatOmega = 1.05;

  bool get hasActiveEffects =>
      _ripples.isNotEmpty ||
      _stars.isNotEmpty ||
      _jellies.isNotEmpty ||
      _notationBits.isNotEmpty ||
      _floralCores.isNotEmpty ||
      _flowerPetals.isNotEmpty ||
      _dustCount > 0;

  void handleTap(Offset localPosition, Size areaSize, GameplayMode mode) {
    handleTapWithPitch(localPosition, areaSize, mode, null);
  }

  void handleTapWithPitch(
    Offset localPosition,
    Size areaSize,
    GameplayMode mode,
    int? pitchClass,
  ) {
    switch (mode) {
      case GameplayMode.water:
        _spawnRipples(localPosition, areaSize, const Color(0xFF0284C7));
        break;
      case GameplayMode.star:
        _spawnStarBurst(localPosition);
        break;
      case GameplayMode.jelly:
        _spawnJellyWobble(localPosition, areaSize);
        break;
      case GameplayMode.musicalRain:
        _spawnNotationBurst(
          localPosition,
          pitchClass ?? _rng.nextInt(5),
        );
        break;
      case GameplayMode.floralBloom:
        _spawnFloralBloom(localPosition);
        break;
      case GameplayMode.magneticDust:
        break;
    }
    _ensureTicker();
  }

  void magneticTouchDown(Offset local, int pointerId) {
    _magnetActive = true;
    _magnetPointerId = pointerId;
    _magnetX = local.dx;
    _magnetY = local.dy;
    _ensureTicker();
    notifyListeners();
  }

  void magneticTouchMove(Offset local, int pointerId) {
    if (!_magnetActive || _magnetPointerId != pointerId) {
      return;
    }
    _magnetX = local.dx;
    _magnetY = local.dy;
  }

  void magneticTouchUp(int pointerId) {
    if (_magnetPointerId != pointerId) {
      return;
    }
    _magnetActive = false;
    _magnetPointerId = null;
    notifyListeners();
  }

  void _spawnRipples(Offset origin, Size areaSize, Color strokeColor) {
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
        ..strokeColor = strokeColor
        ..alive = true;
      _ripples.add(r);
    }
    notifyListeners();
  }

  void _spawnJellyWobble(Offset origin, Size areaSize) {
    final _JellyWobble wobble = _jellyPool.acquire();
    wobble
      ..center = origin
      ..ageMs = 0
      ..lifeMs = 1500
      ..baseRadius = math.min(areaSize.width, areaSize.height) * 0.33
      ..displacement = -1.0
      ..velocity = -1.4
      ..stiffness = 16.0
      ..damping = 6.8
      ..phase = _rng.nextDouble() * math.pi * 2
      ..alive = true;
    _jellies.add(wobble);
    notifyListeners();
  }

  void _spawnFloralBloom(Offset origin) {
    final _FloralCore core = _floralPool.acquire();
    core
      ..center = origin
      ..ageMs = 0
      ..hueSeed = _rng.nextInt(100000)
      ..alive = true;
    _floralCores.add(core);
    notifyListeners();
  }

  void _spawnNotationBurst(Offset origin, int pitchClass) {
    for (int i = 0; i < _notationBurstCount; i++) {
      final _NotationBit bit = _notationPool.acquire();
      final double angle = _rng.nextDouble() * math.pi * 2;
      final double speed = 150 + _rng.nextDouble() * 160;
      bit
        ..x = origin.dx + (_rng.nextDouble() - 0.5) * 10
        ..y = origin.dy + (_rng.nextDouble() - 0.5) * 10
        ..vx = math.cos(angle) * speed
        ..vy = math.sin(angle) * speed - 40
        ..size = 6.5 + _rng.nextDouble() * 3.5
        ..pitchClass = pitchClass
        ..rotation = _rng.nextDouble() * math.pi * 2
        ..spin = (_rng.nextBool() ? 1 : -1) * (2.2 + _rng.nextDouble() * 3.2)
        ..lifeMs = 720 + _rng.nextDouble() * 260
        ..ageMs = 0
        ..alive = true;
      _notationBits.add(bit);
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
    _updateJellies(dtMs);
    _updateNotationBits(dtMs);
    _updateFloralCores(dtMs);
    _updateFlowerPetals(dtMs);
    if (_dustCount > 0) {
      _updateMagneticDust(dtMs);
    }

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

  void _updateJellies(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    for (int i = _jellies.length - 1; i >= 0; i--) {
      final _JellyWobble j = _jellies[i];
      j.ageMs += dtMs;

      final double acceleration =
          (-j.stiffness * j.displacement) - (j.damping * j.velocity);
      j.velocity += acceleration * dtSec;
      j.displacement += j.velocity * dtSec;

      if (j.ageMs >= j.lifeMs ||
          (j.ageMs > j.lifeMs * 0.6 &&
              j.displacement.abs() < 0.01 &&
              j.velocity.abs() < 0.02)) {
        j.alive = false;
        _jellies.removeAt(i);
        _jellyPool.release(j);
      }
    }
  }

  void _updateNotationBits(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    const double drag = 0.985;
    for (int i = _notationBits.length - 1; i >= 0; i--) {
      final _NotationBit n = _notationBits[i];
      n.ageMs += dtMs;
      n.x += n.vx * dtSec;
      n.y += n.vy * dtSec;
      n.vx *= drag;
      n.vy *= drag;
      n.vy += 90 * dtSec;
      n.rotation += n.spin * dtSec;
      if (n.ageMs >= n.lifeMs) {
        n.alive = false;
        _notationBits.removeAt(i);
        _notationPool.release(n);
      }
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

  void _updateFloralCores(double dtMs) {
    final double totalMs = _floralSeedMs + _floralBloomMs;
    for (int i = _floralCores.length - 1; i >= 0; i--) {
      final _FloralCore c = _floralCores[i];
      c.ageMs += dtMs;
      if (c.ageMs >= totalMs) {
        _explodeFloralCore(c);
        c.alive = false;
        _floralCores.removeAt(i);
        _floralPool.release(c);
      }
    }
  }

  void _explodeFloralCore(_FloralCore c) {
    for (int i = 0; i < _floralPetalCount; i++) {
      final _FlowerPetal petal = _petalPool.acquire();
      final double baseAngle = (i / _floralPetalCount) * math.pi * 2;
      final double spread = (_rng.nextDouble() - 0.5) * 0.4;
      final double angle = baseAngle + spread;
      final double speed = 195 + _rng.nextDouble() * 165;
      petal
        ..x = c.center.dx
        ..y = c.center.dy
        ..vx = math.cos(angle) * speed
        ..vy = math.sin(angle) * speed * 0.72
        ..rotation = angle + math.pi / 2
        ..spin = (_rng.nextBool() ? 1 : -1) * (2.2 + _rng.nextDouble() * 3.2)
        ..ageMs = 0
        ..lifeMs = 2100 + _rng.nextDouble() * 500
        ..hueSeed = c.hueSeed
        ..hueIndex = i
        ..variant = i % 3
        ..flutterPhase = _rng.nextDouble() * math.pi * 2
        ..width = (11 + _rng.nextDouble() * 7) * _floralVisualScale
        ..length = (17 + _rng.nextDouble() * 11) * _floralVisualScale
        ..alive = true;
      _flowerPetals.add(petal);
    }
  }

  void _updateFlowerPetals(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    const double gravity = 240;
    for (int i = _flowerPetals.length - 1; i >= 0; i--) {
      final _FlowerPetal p = _flowerPetals[i];
      p.ageMs += dtMs;
      final double flutter =
          math.sin(p.ageMs * 0.0085 + p.flutterPhase) * 32 * dtSec;
      p.vx += flutter;
      p.vx *= 0.991;
      p.vy *= 0.997;
      p.vy += gravity * dtSec;
      p.x += p.vx * dtSec;
      p.y += p.vy * dtSec;
      p.rotation += p.spin * dtSec * 0.42;
      if (p.ageMs >= p.lifeMs) {
        p.alive = false;
        _flowerPetals.removeAt(i);
        _petalPool.release(p);
      }
    }
  }

  Color _floralPetalColor(int hueSeed, int index) {
    final double hue = ((hueSeed * 0.137) + index * 23.7) % 360;
    return HSVColor.fromAHSV(1, hue, 0.36, 0.97).toColor();
  }

  Path _organicPetalPath(int variant) {
    final Path path = Path();
    switch (variant % 3) {
      case 0:
        path.moveTo(14, 0);
        path.cubicTo(10, 6.5, -4, 10.5, -12, 4);
        path.cubicTo(-9, -2.5, 2, -8, 14, 0);
        break;
      case 1:
        path.moveTo(15.5, 0.5);
        path.cubicTo(11, 8, -6.5, 11.5, -11, 2);
        path.cubicTo(-7, -8.5, 4.5, -7.5, 15.5, 0.5);
        break;
      default:
        path.moveTo(13, 1);
        path.cubicTo(9, 8.5, -8, 7.5, -10, 0);
        path.cubicTo(-6, -9.5, 8, -6, 13, 1);
        break;
    }
    path.close();
    return path;
  }

  void _paintFloralCore(Canvas canvas, _FloralCore c) {
    if (c.ageMs < _floralSeedMs) {
      final double st = (c.ageMs / _floralSeedMs).clamp(0.0, 1.0);
      final double e = Curves.easeOut.transform(st);
      final double r = ui.lerpDouble(2.8, 7.2, e)!;
      final Paint seed = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF8D6E63),
            const Color(0xFF5D4037),
          ],
        ).createShader(Rect.fromCircle(center: c.center, radius: r * 1.4));
      canvas.drawCircle(c.center, r, seed);
      final Paint glint = Paint()
        ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.35 * e);
      canvas.drawCircle(
        Offset(c.center.dx - r * 0.25, c.center.dy - r * 0.35),
        r * 0.28,
        glint,
      );
      return;
    }

    final double bt =
        ((c.ageMs - _floralSeedMs) / _floralBloomMs).clamp(0.0, 1.0);
    final double grow = Curves.easeOutBack.transform(bt).clamp(0.0, 1.15);
    final double s = grow * _floralVisualScale;
    const int bloomPetals = 10;
    final Offset o = c.center;

    final Paint centerGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFFFF59D).withValues(alpha: 0.95),
          const Color(0xFFFFE082).withValues(alpha: 0.55),
          const Color(0xFFFFB74D).withValues(alpha: 0.15),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: o, radius: 14 * s));
    canvas.drawCircle(o, 8 * s, centerGlow);

    for (int i = 0; i < bloomPetals; i++) {
      final double angle = (i / bloomPetals) * math.pi * 2;
      final Color col = _floralPetalColor(c.hueSeed, i);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(angle);
      canvas.translate(11 * s, 0);
      final RRect petal = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: 24 * s,
          height: 10 * s,
        ),
        Radius.circular(5 * s),
      );
      final Paint fill = Paint()
        ..color = col.withValues(alpha: 0.82);
      final Paint edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * _floralVisualScale
        ..color = Color.lerp(col, Colors.white, 0.4)!
            .withValues(alpha: 0.35);
      canvas.drawRRect(petal, fill);
      canvas.drawRRect(petal, edge);
      canvas.restore();
    }

    final Paint pistil = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.9);
    canvas.drawCircle(o, 3.2 * s, pistil);
  }

  void _paintFlowerPetal(Canvas canvas, _FlowerPetal p) {
    final double t = (p.ageMs / p.lifeMs).clamp(0.0, 1.0);
    final double fade =
        (1.0 - Curves.easeIn.transform(t)) * (1.0 - t * 0.12);
    if (fade <= 0.02) {
      return;
    }

    final Color base = _floralPetalColor(p.hueSeed, p.hueIndex);
    final Path shape = _organicPetalPath(p.variant);
    final double sx = p.length / 15.0;
    final double sy = p.width / 11.0;

    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rotation);
    canvas.scale(sx, sy);

    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = base.withValues(alpha: (0.62 * fade).clamp(0.0, 1.0));
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15 / math.min(sx, sy)
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(base, Colors.white, 0.38)!
          .withValues(alpha: 0.28 * fade);

    canvas.drawPath(shape, fill);
    canvas.drawPath(shape, stroke);
    canvas.restore();
  }

  @override
  void dispose() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _ticker.dispose();
    _disposeMagneticDust();
    super.dispose();
  }

  void paint(Canvas canvas, Size size, GameplayMode activeMode) {
    if (activeMode != GameplayMode.magneticDust) {
      _disposeMagneticDust();
    } else {
      _ensureMagneticDust(size);
    }

    final Rect rect = Offset.zero & size;
    final Paint bg = Paint()..color = TiptipColors.background;
    canvas.drawRect(rect, bg);

    for (final _RippleRing r in _ripples) {
      _paintRippleRing(canvas, r);
    }
    for (final _JellyWobble j in _jellies) {
      _paintJellyWobble(canvas, j);
    }
    for (final _FloralCore c in _floralCores) {
      _paintFloralCore(canvas, c);
    }
    for (final _NotationBit n in _notationBits) {
      _paintNotationBit(canvas, n);
    }
    for (final _FlowerPetal petal in _flowerPetals) {
      _paintFlowerPetal(canvas, petal);
    }
    for (final _StarParticle p in _stars) {
      _paintStarParticle(canvas, p);
    }
    if (activeMode == GameplayMode.magneticDust && _dustCount > 0) {
      _paintMagneticDust(canvas);
    }

    if (activeMode == GameplayMode.magneticDust && _dustCount > 0) {
      _ensureTicker();
    }
  }

  void _ensureMagneticDust(Size size) {
    if (size.width < 8 || size.height < 8) {
      return;
    }
    final int targetCount =
        ((size.width * size.height) / _dustPixelsPerParticle)
            .floor()
            .clamp(_dustMinCount, _dustMaxCount);
    final bool sameLayout =
        _dustCount == targetCount &&
        (size.width - _dustLayoutW).abs() < 0.5 &&
        (size.height - _dustLayoutH).abs() < 0.5;
    if (sameLayout && _dustPos != null) {
      return;
    }

    _disposeMagneticDust();
    _dustLayoutW = size.width;
    _dustLayoutH = size.height;
    _dustCount = targetCount;
    _dustPos = Float32List(targetCount * 2);
    _dustHome = Float32List(targetCount * 2);
    _dustVel = Float32List(targetCount * 2);
    _dustPhase = Float32List(targetCount);

    final math.Random dustRng = math.Random();
    for (int i = 0; i < targetCount; i++) {
      final double x = dustRng.nextDouble() * size.width;
      final double y = dustRng.nextDouble() * size.height;
      final int i2 = i * 2;
      _dustHome![i2] = x;
      _dustHome![i2 + 1] = y;
      _dustPos![i2] = x;
      _dustPos![i2 + 1] = y;
      _dustVel![i2] = 0;
      _dustVel![i2 + 1] = 0;
      _dustPhase![i] = dustRng.nextDouble() * math.pi * 2;
    }
    _dustTimeSec = 0;
    _ensureTicker();
  }

  void _disposeMagneticDust() {
    if (_dustCount == 0) {
      return;
    }
    _magnetActive = false;
    _magnetPointerId = null;
    _dustPos = null;
    _dustHome = null;
    _dustVel = null;
    _dustPhase = null;
    _dustCount = 0;
    _dustLayoutW = 0;
    _dustLayoutH = 0;
  }

  void _updateMagneticDust(double dtMs) {
    final Float32List? pos = _dustPos;
    final Float32List? home = _dustHome;
    final Float32List? vel = _dustVel;
    final Float32List? phase = _dustPhase;
    if (pos == null ||
        home == null ||
        vel == null ||
        phase == null ||
        _dustCount <= 0) {
      return;
    }

    final double dt = dtMs / 1000.0;
    _dustTimeSec += dt;

    if (_magnetActive) {
      for (int i = 0; i < _dustCount; i++) {
        final int k = i * 2;
        double x = pos[k];
        double y = pos[k + 1];
        double vx = vel[k];
        double vy = vel[k + 1];
        final double dx = _magnetX - x;
        final double dy = _magnetY - y;
        final double distSq = dx * dx + dy * dy + 100;
        final double inv = 1.0 / math.sqrt(distSq);
        final double ax = dx * inv * _dustMagnetAccel;
        final double ay = dy * inv * _dustMagnetAccel;
        vx = vx * _dustMagnetVelDamp + ax * dt;
        vy = vy * _dustMagnetVelDamp + ay * dt;
        final double v2 = vx * vx + vy * vy;
        final double maxS = _dustMagnetMaxSpeed;
        if (v2 > maxS * maxS) {
          final double s = maxS / math.sqrt(v2);
          vx *= s;
          vy *= s;
        }
        x += vx * dt;
        y += vy * dt;
        pos[k] = x;
        pos[k + 1] = y;
        vel[k] = vx;
        vel[k + 1] = vy;
      }
    } else {
      final double t = _dustTimeSec;
      for (int i = 0; i < _dustCount; i++) {
        final int k = i * 2;
        final double hx = home[k];
        final double hy = home[k + 1];
        double x = pos[k];
        double y = pos[k + 1];
        double vx = vel[k];
        double vy = vel[k + 1];
        final double ph = phase[i];
        final double tx =
            hx + _dustFloatAmpPx * math.sin(_dustFloatOmega * t + ph);
        final double ty =
            hy +
            _dustFloatAmpPx *
                math.cos(_dustFloatOmega * 0.91 * t + ph * 1.27);
        final double ax = _dustSpringK * (tx - x) - _dustSpringDamp * vx;
        final double ay = _dustSpringK * (ty - y) - _dustSpringDamp * vy;
        vx += ax * dt;
        vy += ay * dt;
        x += vx * dt;
        y += vy * dt;
        pos[k] = x;
        pos[k + 1] = y;
        vel[k] = vx;
        vel[k + 1] = vy;
      }
    }
  }

  void _paintMagneticDust(Canvas canvas) {
    final Float32List? pos = _dustPos;
    if (pos == null || _dustCount <= 0) {
      return;
    }
    canvas.drawRawPoints(ui.PointMode.points, pos, _dustVertexPaint);
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
  }

  void _paintJellyWobble(Canvas canvas, _JellyWobble j) {
    final double lifeT = (j.ageMs / j.lifeMs).clamp(0.0, 1.0);
    final double settle = Curves.easeOutCubic.transform(1 - lifeT);
    final double sink = j.displacement * (0.7 + settle * 0.8);
    final double organic = 0.08 * settle;
    final double opacity = (0.38 * settle).clamp(0.0, 0.38);

    final Rect waxRect = Rect.fromCircle(
      center: j.center,
      radius: j.baseRadius * (0.6 + settle * 0.55),
    );
    final Paint waxFill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.25),
        radius: 1.0,
        colors: <Color>[
          const Color(0xFFFFF9EA).withValues(alpha: opacity * 0.95),
          const Color(0xFFFDF0D5).withValues(alpha: opacity * 0.55),
          const Color(0xFFF6D7A9).withValues(alpha: opacity * 0.2),
        ],
        stops: const <double>[0.0, 0.58, 1.0],
      ).createShader(waxRect);

    final Path body = _organicCirclePath(
      center: j.center,
      radius: j.baseRadius * (1 + sink * 0.07),
      amplitude: organic + sink.abs() * 0.06,
      frequency: 3.4,
      phase: j.phase + lifeT * 7.5,
    );
    canvas.drawPath(body, waxFill);
    _paintJellySpecularSheen(
      canvas,
      body,
      center: j.center,
      radius: j.baseRadius,
      lifeT: lifeT,
      settle: settle,
      phase: j.phase,
    );

    for (int i = 0; i < 4; i++) {
      final double ringT = i / 3;
      final double r = j.baseRadius * (0.2 + ringT * 0.85) * (1 + sink * 0.05);
      final double ringOpacity = (opacity * (1 - ringT * 0.2)).clamp(0.0, 1.0);
      final Paint ringStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 + (3 - i) * 0.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD9A86C).withValues(alpha: ringOpacity);
      final Path ringPath = _organicCirclePath(
        center: j.center,
        radius: r,
        amplitude: organic * (1.1 - ringT * 0.3) + sink.abs() * 0.04,
        frequency: 3.0 + ringT * 1.2,
        phase: j.phase + ringT * 1.5 + lifeT * 6.2,
      );
      canvas.drawPath(ringPath, ringStroke);
    }
  }

  void _paintJellySpecularSheen(
    Canvas canvas,
    Path body, {
    required Offset center,
    required double radius,
    required double lifeT,
    required double settle,
    required double phase,
  }) {
    final double alpha = (0.14 * settle).clamp(0.0, 0.14);
    if (alpha <= 0.001) {
      return;
    }

    // Tiny drifting highlight that mimics waxy specular response.
    final double drift =
        math.sin((lifeT * 2.2 * math.pi) + phase) * radius * 0.18;
    final Offset sheenCenter = Offset(
      center.dx - radius * 0.24 + drift,
      center.dy -
          radius * 0.26 +
          (radius * 0.05 * math.cos(lifeT * 5.4 + phase)),
    );
    final Rect sheenRect = Rect.fromCenter(
      center: sheenCenter,
      width: radius * 0.9,
      height: radius * 0.34,
    );

    final Paint sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: alpha * 0.9),
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 0.34, 0.62, 1.0],
      ).createShader(sheenRect);

    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(sheenRect, sheen);
    canvas.restore();
  }

  Path _organicCirclePath({
    required Offset center,
    required double radius,
    required double amplitude,
    required double frequency,
    required double phase,
  }) {
    const int segments = 64;
    final Path path = Path();
    for (int i = 0; i <= segments; i++) {
      final double t = i / segments;
      final double a = t * math.pi * 2;
      final double distort = 1 + amplitude * math.sin((a * frequency) + phase);
      final double rr = radius * distort;
      final double x = center.dx + rr * math.cos(a);
      final double y = center.dy + rr * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  static const List<String> _rainPitchLabels = <String>[
    'C4',
    'D4',
    'E4',
    'G4',
    'A4',
  ];

  Color _rainPitchColor(int pitchClass) {
    return Color.lerp(
      const Color(0xFF2DD4BF),
      const Color(0xFF0EA5E9),
      ((pitchClass % 5) / 4).clamp(0, 1).toDouble(),
    )!;
  }

  String _rainPitchLabel(int pitchClass) {
    return _rainPitchLabels[pitchClass.clamp(0, _rainPitchLabels.length - 1)];
  }

  void _paintNotationBit(Canvas canvas, _NotationBit n) {
    final double t = (n.ageMs / n.lifeMs).clamp(0.0, 1.0);
    final double fade =
        (1.0 - Curves.easeOut.transform(t)) * (1.0 - t * 0.15);
    if (fade <= 0.02) {
      return;
    }

    final double streakLen = 18 + n.size * 1.2;
    final double speed = math.sqrt(n.vx * n.vx + n.vy * n.vy) + 0.001;
    final double ux = n.vx / speed;
    final double uy = n.vy / speed;
    final Offset tail = Offset(n.x - ux * streakLen, n.y - uy * streakLen);
    final Paint streak = Paint()
      ..shader = LinearGradient(
        begin: Alignment(ux, uy),
        end: Alignment(-ux, -uy),
        colors: <Color>[
          _rainPitchColor(n.pitchClass).withValues(alpha: 0),
          _rainPitchColor(n.pitchClass).withValues(alpha: 0.12 * fade),
        ],
      ).createShader(Rect.fromPoints(tail, Offset(n.x, n.y)))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(tail, Offset(n.x, n.y), streak);

    _paintNotationGlyph(
      canvas,
      n.x,
      n.y,
      n.pitchClass,
      n.size,
      fade,
      n.rotation,
    );
  }

  void _paintNotationGlyph(
    Canvas canvas,
    double cx,
    double cy,
    int pitchClass,
    double size,
    double fade,
    double rotation,
  ) {
    final Color noteTint = _rainPitchColor(pitchClass);
    final Color noteColor = noteTint.withValues(alpha: (0.92 * fade).clamp(0.0, 1.0));

    const IconData noteIcon = Icons.music_note_rounded;
    final String label = _rainPitchLabel(pitchClass);
    final TextPainter labelPainter = TextPainter(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: String.fromCharCode(noteIcon.codePoint),
            style: TextStyle(
              inherit: false,
              fontFamily: noteIcon.fontFamily,
              package: noteIcon.fontPackage,
              fontSize: size * 0.95,
              color: noteColor,
              height: 1.05,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(
              fontSize: size * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: noteColor,
              height: 1.05,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout(maxWidth: 220);

    final double pad = 5;
    final double badgeW = labelPainter.width + pad * 2;
    final double badgeH = labelPainter.height + pad * 2;
    final RRect badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, badgeW, badgeH),
      Radius.circular(size * 0.45),
    );
    final Paint bg = Paint()
      ..color = Colors.white.withValues(alpha: (0.9 * fade).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    final Paint border = Paint()
      ..color = noteTint.withValues(alpha: (0.4 * fade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    canvas.translate(-badgeW / 2, -badgeH / 2);
    canvas.drawRRect(badge, bg);
    canvas.drawRRect(badge, border);
    labelPainter.paint(canvas, Offset(pad, pad));
    canvas.restore();
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

class _FloralCore {
  Offset center = Offset.zero;
  double ageMs = 0;
  int hueSeed = 0;
  bool alive = false;
}

class _FlowerPetal {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double rotation = 0;
  double spin = 0;
  double ageMs = 0;
  double lifeMs = 2200;
  int hueSeed = 0;
  int hueIndex = 0;
  int variant = 0;
  double flutterPhase = 0;
  double width = 14;
  double length = 20;
  bool alive = false;
}

class _RippleRing {
  Offset center = Offset.zero;
  double ageMs = 0;
  double delayMs = 0;
  double durationMs = 1500;
  double maxRadius = 100;
  int ringIndex = 0;
  Color strokeColor = const Color(0xFF0284C7);
  bool alive = false;
}

class _JellyWobble {
  Offset center = Offset.zero;
  double ageMs = 0;
  double lifeMs = 1500;
  double baseRadius = 120;
  double displacement = 0;
  double velocity = 0;
  double stiffness = 16;
  double damping = 6.8;
  double phase = 0;
  bool alive = false;
}

class _NotationBit {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double size = 9;
  int pitchClass = 0;
  double rotation = 0;
  double spin = 0;
  double lifeMs = 800;
  double ageMs = 0;
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
  PlayAreaPainter(this.engine, this.activeMode) : super(repaint: engine);

  final PlayAreaAnimationEngine engine;
  final GameplayMode activeMode;

  @override
  void paint(Canvas canvas, Size size) {
    engine.paint(canvas, size, activeMode);
  }

  @override
  bool shouldRepaint(covariant PlayAreaPainter oldDelegate) =>
      oldDelegate.activeMode != activeMode;
}
