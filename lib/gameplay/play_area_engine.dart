import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../theme/tiptip_colors.dart';
import 'gameplay_mode.dart';
import 'object_pool.dart';

/// Oyun alanı animasyon durumu — [CustomPaint.repaint] ile bağlanır.
///
/// Water ripples: [Ticker] sürücülü aktif halka listesi (bellek için havuz);
/// her dokunuşta 3–4 gecikmeli halka, köşeye kadar genişleme ve tamamlanınca listeden çıkarılır.
///
/// Star burst: dokunuş başına 5–8 parçacık, [ObjectPool] ile geri dönüşüm.
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
  final ObjectPool<_SoapBubble> _bubblePool = ObjectPool<_SoapBubble>(
    _SoapBubble.new,
  );
  final ObjectPool<_BubbleShard> _shardPool = ObjectPool<_BubbleShard>(
    _BubbleShard.new,
  );
  final ObjectPool<_PaintSplat> _splatPool = ObjectPool<_PaintSplat>(
    _PaintSplat.new,
  );

  final List<_RippleRing> _ripples = <_RippleRing>[];
  final List<_StarParticle> _stars = <_StarParticle>[];
  final List<_JellyWobble> _jellies = <_JellyWobble>[];
  final List<_NotationBit> _notationBits = <_NotationBit>[];
  final List<_FloralCore> _floralCores = <_FloralCore>[];
  final List<_FlowerPetal> _flowerPetals = <_FlowerPetal>[];
  final List<_SoapBubble> _bubbles = <_SoapBubble>[];
  final List<_BubbleShard> _bubbleShards = <_BubbleShard>[];
  final List<_PaintSplat> _paintSplats = <_PaintSplat>[];
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

  Float32List? _fireflyPos;
  Float32List? _fireflyVel;
  Float32List? _fireflyPhase;
  Float32List? _fireflySize;
  int _fireflyCount = 0;
  double _fireflyLayoutW = 0;
  double _fireflyLayoutH = 0;
  bool _fireflyAttractActive = false;
  double _fireflyX = 0;
  double _fireflyY = 0;
  int? _fireflyPointerId;
  double _fireflyTimeSec = 0;

  final Paint _fireflyOuterPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
    ..isAntiAlias = true;
  final Paint _fireflyInnerPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4)
    ..isAntiAlias = true;
  final Paint _fireflyCorePaint = Paint()..isAntiAlias = true;

  Duration? _lastElapsed;
  bool _ticking = false;

  static const double _rippleDurationMs = 1550;
  static const double _ringStaggerMs = 112;
  static const double _rippleStrokePx = 2.0;
  static const double _rippleOpacityStart = 0.6;
  static const Color _rippleCyanSoft = Color(0xFF9FE8FF);
  static const Color _rippleCyanDeep = Color(0xFF4AB8E8);
  static const double _starLifeMs = 1050;
  static const double _starSpeedMin = 175;
  static const double _starSpeedMax = 340;
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

  // Firefly swarm: dozens of ambient glowing orbs that accelerate toward a
  // held touch and drift+flicker when released.
  static const double _fireflyPixelsPerParticle = 9500;
  static const int _fireflyMinCount = 48;
  static const int _fireflyMaxCount = 150;
  static const double _fireflyAttractAccel = 2400;
  static const double _fireflyAttractDamp = 0.93;
  static const double _fireflySwirl = 0.38;
  static const double _fireflyMaxSpeed = 520;
  static const double _fireflyDriftDamp = 0.994;
  static const double _fireflyWanderAccelPx = 10;
  static const double _fireflyWanderOmega = 0.55;
  static const double _fireflyReleaseSpeedMin = 80;
  static const double _fireflyReleaseSpeedMax = 190;
  static const double _fireflyReleaseAngleJitter = 0.9;
  static const Color _fireflyBgColor = Color(0xFF1F2233);
  static const Color _fireflyHaloColor = Color(0xFFFBBF24);
  static const Color _fireflyInnerColor = Color(0xFFFFEF6E);

  static const double _bubbleRadiusMin = 22;
  static const double _bubbleRadiusMax = 46;
  static const double _bubbleRiseSpeedMin = 32;
  static const double _bubbleRiseSpeedMax = 58;
  static const double _bubbleSwayAmpMin = 14;
  static const double _bubbleSwayAmpMax = 32;
  static const double _bubbleSwayFreqMin = 0.65;
  static const double _bubbleSwayFreqMax = 1.25;
  static const double _bubblePopLifeMs = 260;
  static const int _bubbleShardCount = 8;

  /// Spring-wobble parameters for the paint splat: critically-ish underdamped
  /// so the blob expands fast, overshoots a hair, then settles.
  static const double _splatWobbleStiffness = 95.0;
  static const double _splatWobbleDamping = 6.5;
  /// Initial displacement: blob starts at ~45% of its final size and springs
  /// outward to its settled radius.
  static const double _splatInitialDisplacement = -0.55;

  static const double _splatHoldMs = 6000;
  static const double _splatFadeMs = 1200;
  static const double _splatRadiusMin = 48;
  static const double _splatRadiusMax = 92;
  // Fewer lobes → each lobe is wider and survives the heavy metaball blur.
  static const int _splatLobeMin = 6;
  static const int _splatLobeMax = 9;
  // Per-lobe radius range, expressed as multiplier of the blob's base radius.
  // Wider spread = deeper bumps / pinches in the silhouette.
  static const double _splatLobeRadiusMin = 0.55;
  static const double _splatLobeRadiusMax = 1.40;
  // Extra angular jitter so lobes don't sit on a regular polygon.
  static const double _splatLobeAngleJitter = 0.18;
  // Per-blob non-uniform scaling (stretch) so some splats look tall/eggy and
  // others wide — this is what's left after the 30-sigma blur homogenises
  // fine lobe detail.
  static const double _splatAspectMin = 0.72;
  static const double _splatAspectMax = 1.32;

  /// Heavy gaussian blur on each blob — the other half of the metaball trick;
  /// paired with the high-contrast alpha matrix in the screen widget, this is
  /// what creates the merging "melting" behaviour between nearby blobs.
  static const double _splatMetaballBlurSigma = 30.0;

  /// Lime Green, Bright Orange, Hot Pink — child-friendly paint palette.
  static const List<Color> _splatPalette = <Color>[
    Color(0xFFA3E635),
    Color(0xFFFB923C),
    Color(0xFFEC4899),
  ];

  bool get hasActiveEffects =>
      _ripples.isNotEmpty ||
      _stars.isNotEmpty ||
      _jellies.isNotEmpty ||
      _notationBits.isNotEmpty ||
      _floralCores.isNotEmpty ||
      _flowerPetals.isNotEmpty ||
      _bubbles.isNotEmpty ||
      _bubbleShards.isNotEmpty ||
      _paintSplats.isNotEmpty ||
      _dustCount > 0 ||
      _fireflyCount > 0;

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
        _spawnRipples(localPosition, areaSize);
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
      case GameplayMode.soapBubbles:
        handleBubbleTap(localPosition);
        return;
      case GameplayMode.paintSplat:
        _spawnPaintSplat(localPosition);
        break;
      case GameplayMode.fireflyGlow:
        break;
    }
    _ensureTicker();
  }

  /// Soap Bubbles: tapping on an existing bubble pops it, otherwise spawns one.
  BubbleTapResult handleBubbleTap(Offset localPosition) {
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final _SoapBubble b = _bubbles[i];
      if (b.popping) {
        continue;
      }
      final double dx = localPosition.dx - b.x;
      final double dy = localPosition.dy - b.y;
      final double hitR = b.radius + 6;
      if (dx * dx + dy * dy <= hitR * hitR) {
        _startBubblePop(b);
        _ensureTicker();
        return BubbleTapResult.popped;
      }
    }
    _spawnBubble(localPosition);
    _ensureTicker();
    return BubbleTapResult.spawned;
  }

  void _spawnBubble(Offset origin) {
    final _SoapBubble b = _bubblePool.acquire();
    final double radius = _bubbleRadiusMin +
        _rng.nextDouble() * (_bubbleRadiusMax - _bubbleRadiusMin);
    final double rise = _bubbleRiseSpeedMin +
        _rng.nextDouble() * (_bubbleRiseSpeedMax - _bubbleRiseSpeedMin);
    final double swayAmp = _bubbleSwayAmpMin +
        _rng.nextDouble() * (_bubbleSwayAmpMax - _bubbleSwayAmpMin);
    final double swayFreq = _bubbleSwayFreqMin +
        _rng.nextDouble() * (_bubbleSwayFreqMax - _bubbleSwayFreqMin);
    b
      ..baseX = origin.dx
      ..x = origin.dx
      ..y = origin.dy
      ..radius = radius
      ..riseSpeed = rise
      ..swayAmp = swayAmp
      ..swayFreq = swayFreq
      ..swayPhase = _rng.nextDouble() * math.pi * 2
      ..hueSeed = _rng.nextDouble()
      ..spawnScaleMs = 0
      ..ageMs = 0
      ..popping = false
      ..popAgeMs = 0
      ..alive = true;
    _bubbles.add(b);
    notifyListeners();
  }

  void _spawnPaintSplat(Offset origin) {
    final _PaintSplat splat = _splatPool.acquire();
    final int lobeCount = _splatLobeMin +
        _rng.nextInt(_splatLobeMax - _splatLobeMin + 1);
    final double baseRadius = _splatRadiusMin +
        _rng.nextDouble() * (_splatRadiusMax - _splatRadiusMin);
    final Color color = _splatPalette[_rng.nextInt(_splatPalette.length)];
    final Float32List lobeRadii = Float32List(lobeCount);
    final Float32List lobeAngleJitter = Float32List(lobeCount);
    const double radiusSpread = _splatLobeRadiusMax - _splatLobeRadiusMin;
    for (int i = 0; i < lobeCount; i++) {
      lobeRadii[i] =
          _splatLobeRadiusMin + _rng.nextDouble() * radiusSpread;
      lobeAngleJitter[i] =
          (_rng.nextDouble() - 0.5) * 2 * _splatLobeAngleJitter;
    }
    // Non-uniform per-splat stretch. We pick the X scale freely, then derive Y
    // from its reciprocal-ish so the average area stays similar across taps.
    const double aspectSpread = _splatAspectMax - _splatAspectMin;
    final double sx = _splatAspectMin + _rng.nextDouble() * aspectSpread;
    // sy ranges roughly in the same band but is anti-correlated with sx so we
    // get eggy/wide shapes instead of everything being bigger or smaller.
    final double sy = _splatAspectMin +
        (_splatAspectMax - sx) +
        (_rng.nextDouble() - 0.5) * 0.15;
    splat
      ..center = origin
      ..baseRadius = baseRadius
      ..baseRotation = _rng.nextDouble() * math.pi * 2
      ..aspectX = sx.clamp(_splatAspectMin, _splatAspectMax).toDouble()
      ..aspectY = sy.clamp(_splatAspectMin, _splatAspectMax).toDouble()
      ..color = color
      ..lobeRadii = lobeRadii
      ..lobeAngleJitter = lobeAngleJitter
      ..wobbleDisplacement = _splatInitialDisplacement
      ..wobbleVelocity = 0
      ..ageMs = 0
      ..alive = true;
    _paintSplats.add(splat);
    notifyListeners();
  }

  void _startBubblePop(_SoapBubble b) {
    if (b.popping) {
      return;
    }
    b.popping = true;
    b.popAgeMs = 0;
    for (int i = 0; i < _bubbleShardCount; i++) {
      final _BubbleShard s = _shardPool.acquire();
      final double angle =
          (i / _bubbleShardCount) * math.pi * 2 + _rng.nextDouble() * 0.35;
      final double speed = 110 + _rng.nextDouble() * 140;
      s
        ..x = b.x + math.cos(angle) * b.radius * 0.55
        ..y = b.y + math.sin(angle) * b.radius * 0.55
        ..vx = math.cos(angle) * speed
        ..vy = math.sin(angle) * speed - 40
        ..size = 1.6 + _rng.nextDouble() * 2.4
        ..hueSeed = b.hueSeed
        ..ageMs = 0
        ..lifeMs = 340 + _rng.nextDouble() * 180
        ..alive = true;
      _bubbleShards.add(s);
    }
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

  /// Firefly Glow: touch-down begins the swarm attraction at [local].
  void fireflyTouchDown(Offset local, int pointerId) {
    _fireflyAttractActive = true;
    _fireflyPointerId = pointerId;
    _fireflyX = local.dx;
    _fireflyY = local.dy;
    _ensureTicker();
    notifyListeners();
  }

  /// Firefly Glow: move the swarm target while the finger is down.
  void fireflyTouchMove(Offset local, int pointerId) {
    if (!_fireflyAttractActive || _fireflyPointerId != pointerId) {
      return;
    }
    _fireflyX = local.dx;
    _fireflyY = local.dy;
  }

  /// Firefly Glow: on release, give each firefly an outward-radial impulse
  /// (with a small random angular jitter) so they scatter and drift.
  void fireflyTouchUp(int pointerId) {
    if (_fireflyPointerId != pointerId) {
      return;
    }
    _fireflyAttractActive = false;
    _fireflyPointerId = null;
    _applyFireflyReleaseImpulse();
    notifyListeners();
  }

  void _applyFireflyReleaseImpulse() {
    final Float32List? pos = _fireflyPos;
    final Float32List? vel = _fireflyVel;
    if (pos == null || vel == null || _fireflyCount <= 0) {
      return;
    }
    for (int i = 0; i < _fireflyCount; i++) {
      final int k = i * 2;
      final double dx = pos[k] - _fireflyX;
      final double dy = pos[k + 1] - _fireflyY;
      final double dist = math.sqrt(dx * dx + dy * dy);
      double nx;
      double ny;
      if (dist < 0.001) {
        final double a = _rng.nextDouble() * math.pi * 2;
        nx = math.cos(a);
        ny = math.sin(a);
      } else {
        nx = dx / dist;
        ny = dy / dist;
      }
      final double jitter =
          (_rng.nextDouble() - 0.5) * _fireflyReleaseAngleJitter;
      final double ca = math.cos(jitter);
      final double sa = math.sin(jitter);
      final double rx = nx * ca - ny * sa;
      final double ry = nx * sa + ny * ca;
      final double speed = _fireflyReleaseSpeedMin +
          _rng.nextDouble() *
              (_fireflyReleaseSpeedMax - _fireflyReleaseSpeedMin);
      vel[k] = rx * speed;
      vel[k + 1] = ry * speed;
    }
  }

  void _spawnRipples(Offset origin, Size areaSize) {
    final double maxR = _rippleMaxRadiusToEdges(origin, areaSize);
    final int ringCount = 3 + _rng.nextInt(2);
    for (int i = 0; i < ringCount; i++) {
      final _RippleRing r = _ripplePool.acquire();
      r
        ..center = origin
        ..delayMs = i * _ringStaggerMs
        ..ageMs = 0
        ..durationMs = _rippleDurationMs
        ..maxRadius = maxR
        ..alive = true;
      _ripples.add(r);
    }
    notifyListeners();
  }

  /// Dokunuş noktasından oyun alanı köşelerine uzaklığın üst sınırı (tam ekran dalga).
  double _rippleMaxRadiusToEdges(Offset origin, Size size) {
    final double dx = math.max(origin.dx, size.width - origin.dx);
    final double dy = math.max(origin.dy, size.height - origin.dy);
    return math.sqrt(dx * dx + dy * dy) + 3;
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

  static const List<Color> _starBurstPalette = <Color>[
    Color(0xFFFFC940),
    Color(0xFFFFE082),
    Color(0xFFFFF9C4),
    Color(0xFFFFFFFF),
    Color(0xFFFFD54F),
  ];

  void _spawnStarBurst(Offset origin) {
    final int burstCount = 5 + _rng.nextInt(4);
    for (int i = 0; i < burstCount; i++) {
      final _StarParticle p = _starPool.acquire();
      final double angle = _rng.nextDouble() * math.pi * 2;
      final double speed =
          _starSpeedMin + _rng.nextDouble() * (_starSpeedMax - _starSpeedMin);
      p
        ..position = origin
        ..vx = math.cos(angle) * speed
        ..vy = math.sin(angle) * speed
        ..ageMs = 0
        ..lifeMs = _starLifeMs * (0.88 + _rng.nextDouble() * 0.24)
        ..rotation = _rng.nextDouble() * math.pi * 2
        ..spin = (_rng.nextBool() ? 1 : -1) * (1.6 + _rng.nextDouble() * 2.6)
        ..fillColor = _starBurstPalette[_rng.nextInt(_starBurstPalette.length)]
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
    _updateBubbles(dtMs);
    _updateBubbleShards(dtMs);
    _updatePaintSplats(dtMs);
    if (_dustCount > 0) {
      _updateMagneticDust(dtMs);
    }
    if (_fireflyCount > 0) {
      _updateFireflies(dtMs);
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

  void _updateBubbles(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final _SoapBubble b = _bubbles[i];
      b.ageMs += dtMs;
      b.spawnScaleMs += dtMs;

      if (b.popping) {
        b.popAgeMs += dtMs;
        if (b.popAgeMs >= _bubblePopLifeMs) {
          b.alive = false;
          _bubbles.removeAt(i);
          _bubblePool.release(b);
        }
        continue;
      }

      b.y -= b.riseSpeed * dtSec;
      final double t = b.ageMs / 1000.0;
      b.x = b.baseX + math.sin(t * b.swayFreq * math.pi * 2 + b.swayPhase) *
          b.swayAmp;

      final double topBound = -b.radius * 1.2;
      if (b.y < topBound) {
        b.alive = false;
        _bubbles.removeAt(i);
        _bubblePool.release(b);
      }
    }
  }

  void _updatePaintSplats(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    final double totalMs = _splatHoldMs + _splatFadeMs;
    for (int i = _paintSplats.length - 1; i >= 0; i--) {
      final _PaintSplat s = _paintSplats[i];
      s.ageMs += dtMs;

      // Spring integration: acc = -k·x − c·v (Hooke + viscous damping).
      final double acc = (-_splatWobbleStiffness * s.wobbleDisplacement) -
          (_splatWobbleDamping * s.wobbleVelocity);
      s.wobbleVelocity += acc * dtSec;
      s.wobbleDisplacement += s.wobbleVelocity * dtSec;

      if (s.ageMs >= totalMs) {
        s.alive = false;
        _paintSplats.removeAt(i);
        _splatPool.release(s);
      }
    }
  }

  void _updateBubbleShards(double dtMs) {
    final double dtSec = dtMs / 1000.0;
    for (int i = _bubbleShards.length - 1; i >= 0; i--) {
      final _BubbleShard s = _bubbleShards[i];
      s.ageMs += dtMs;
      s.vx *= 0.965;
      s.vy *= 0.965;
      s.vy += 220 * dtSec;
      s.x += s.vx * dtSec;
      s.y += s.vy * dtSec;
      if (s.ageMs >= s.lifeMs) {
        s.alive = false;
        _bubbleShards.removeAt(i);
        _shardPool.release(s);
      }
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
    _disposeFireflies();
    super.dispose();
  }

  void paint(Canvas canvas, Size size, GameplayMode activeMode) {
    if (activeMode != GameplayMode.magneticDust) {
      _disposeMagneticDust();
    } else {
      _ensureMagneticDust(size);
    }
    if (activeMode != GameplayMode.fireflyGlow) {
      _disposeFireflies();
    } else {
      _ensureFireflies(size);
    }

    final Rect rect = Offset.zero & size;
    final Color bgColor = activeMode == GameplayMode.fireflyGlow
        ? _fireflyBgColor
        : TiptipColors.background;
    final Paint bg = Paint()..color = bgColor;
    canvas.drawRect(rect, bg);

    // NOTE: paint splats are deliberately NOT drawn here. They render through
    // the dedicated [PaintSplatMetaballPainter] (wrapped in a [ColorFiltered]
    // that thresholds alpha for the metaball merge) and the on-top
    // [PaintSplatHighlightsPainter] layer in the gameplay screen widget tree.

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
    for (final _SoapBubble b in _bubbles) {
      _paintSoapBubble(canvas, b);
    }
    for (final _BubbleShard s in _bubbleShards) {
      _paintBubbleShard(canvas, s);
    }
    if (activeMode == GameplayMode.magneticDust && _dustCount > 0) {
      _paintMagneticDust(canvas);
    }
    if (activeMode == GameplayMode.fireflyGlow && _fireflyCount > 0) {
      _paintFireflies(canvas);
    }

    if ((activeMode == GameplayMode.magneticDust && _dustCount > 0) ||
        (activeMode == GameplayMode.fireflyGlow && _fireflyCount > 0)) {
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

  void _ensureFireflies(Size size) {
    if (size.width < 8 || size.height < 8) {
      return;
    }
    final int targetCount =
        ((size.width * size.height) / _fireflyPixelsPerParticle)
            .floor()
            .clamp(_fireflyMinCount, _fireflyMaxCount);
    final bool sameLayout =
        _fireflyCount == targetCount &&
        (size.width - _fireflyLayoutW).abs() < 0.5 &&
        (size.height - _fireflyLayoutH).abs() < 0.5;
    if (sameLayout && _fireflyPos != null) {
      return;
    }

    _disposeFireflies();
    _fireflyLayoutW = size.width;
    _fireflyLayoutH = size.height;
    _fireflyCount = targetCount;
    _fireflyPos = Float32List(targetCount * 2);
    _fireflyVel = Float32List(targetCount * 2);
    _fireflyPhase = Float32List(targetCount);
    _fireflySize = Float32List(targetCount);

    final math.Random r = math.Random();
    for (int i = 0; i < targetCount; i++) {
      final int k = i * 2;
      _fireflyPos![k] = r.nextDouble() * size.width;
      _fireflyPos![k + 1] = r.nextDouble() * size.height;
      final double vAngle = r.nextDouble() * math.pi * 2;
      final double vSpeed = 8 + r.nextDouble() * 18;
      _fireflyVel![k] = math.cos(vAngle) * vSpeed;
      _fireflyVel![k + 1] = math.sin(vAngle) * vSpeed;
      _fireflyPhase![i] = r.nextDouble() * math.pi * 2;
      _fireflySize![i] = 1.8 + r.nextDouble() * 1.6;
    }
    _fireflyTimeSec = 0;
    _ensureTicker();
  }

  void _disposeFireflies() {
    if (_fireflyCount == 0) {
      return;
    }
    _fireflyAttractActive = false;
    _fireflyPointerId = null;
    _fireflyPos = null;
    _fireflyVel = null;
    _fireflyPhase = null;
    _fireflySize = null;
    _fireflyCount = 0;
    _fireflyLayoutW = 0;
    _fireflyLayoutH = 0;
  }

  void _updateFireflies(double dtMs) {
    final Float32List? pos = _fireflyPos;
    final Float32List? vel = _fireflyVel;
    final Float32List? phase = _fireflyPhase;
    if (pos == null || vel == null || phase == null || _fireflyCount <= 0) {
      return;
    }

    final double dt = dtMs / 1000.0;
    _fireflyTimeSec += dt;
    final double w = _fireflyLayoutW;
    final double h = _fireflyLayoutH;
    final double wrapMargin = 28.0;

    if (_fireflyAttractActive) {
      final double tx = _fireflyX;
      final double ty = _fireflyY;
      for (int i = 0; i < _fireflyCount; i++) {
        final int k = i * 2;
        double x = pos[k];
        double y = pos[k + 1];
        double vx = vel[k];
        double vy = vel[k + 1];
        final double dx = tx - x;
        final double dy = ty - y;
        // Soften denominator so fireflies orbit the target rather than
        // collapse into a single pixel — the "swarm" feel.
        final double distSq = dx * dx + dy * dy + 900;
        final double inv = 1.0 / math.sqrt(distSq);
        final double ax = dx * inv * _fireflyAttractAccel;
        final double ay = dy * inv * _fireflyAttractAccel;
        // Tangential component (perpendicular) adds orbital swirl.
        final double sx = -dy * inv * _fireflyAttractAccel * _fireflySwirl;
        final double sy = dx * inv * _fireflyAttractAccel * _fireflySwirl;
        vx = (vx + (ax + sx) * dt) * _fireflyAttractDamp;
        vy = (vy + (ay + sy) * dt) * _fireflyAttractDamp;

        final double v2 = vx * vx + vy * vy;
        if (v2 > _fireflyMaxSpeed * _fireflyMaxSpeed) {
          final double s = _fireflyMaxSpeed / math.sqrt(v2);
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
      final double t = _fireflyTimeSec;
      for (int i = 0; i < _fireflyCount; i++) {
        final int k = i * 2;
        double x = pos[k];
        double y = pos[k + 1];
        double vx = vel[k];
        double vy = vel[k + 1];
        final double ph = phase[i];
        // Gentle wandering drift (keeps fireflies alive-looking while idle).
        vx += math.cos(_fireflyWanderOmega * t + ph) *
            _fireflyWanderAccelPx *
            dt;
        vy += math.sin(_fireflyWanderOmega * 0.87 * t + ph * 1.3) *
            _fireflyWanderAccelPx *
            dt;
        vx *= _fireflyDriftDamp;
        vy *= _fireflyDriftDamp;

        x += vx * dt;
        y += vy * dt;

        // Wrap around edges so the swarm doesn't leak off-canvas after the
        // release impulse pushes some fireflies off-screen.
        if (x < -wrapMargin) x += w + wrapMargin * 2;
        if (x > w + wrapMargin) x -= w + wrapMargin * 2;
        if (y < -wrapMargin) y += h + wrapMargin * 2;
        if (y > h + wrapMargin) y -= h + wrapMargin * 2;

        pos[k] = x;
        pos[k + 1] = y;
        vel[k] = vx;
        vel[k + 1] = vy;
      }
    }
  }

  void _paintFireflies(Canvas canvas) {
    final Float32List? pos = _fireflyPos;
    final Float32List? phase = _fireflyPhase;
    final Float32List? size = _fireflySize;
    if (pos == null || phase == null || size == null || _fireflyCount <= 0) {
      return;
    }
    final double t = _fireflyTimeSec;
    final Paint outer = _fireflyOuterPaint;
    final Paint inner = _fireflyInnerPaint;
    final Paint core = _fireflyCorePaint;
    for (int i = 0; i < _fireflyCount; i++) {
      final int k = i * 2;
      final double x = pos[k];
      final double y = pos[k + 1];
      final double sz = size[i];
      final double ph = phase[i];
      // Per-firefly flicker — unique phase + speed gives asynchronous twinkle.
      final double flickRaw =
          0.58 + 0.42 * math.sin(t * (2.2 + (ph % 1.0) * 1.4) + ph * 2.0);
      final double a = flickRaw.clamp(0.18, 1.0);
      final Offset c = Offset(x, y);

      outer.color = _fireflyHaloColor.withValues(alpha: 0.22 * a);
      canvas.drawCircle(c, sz * 4.6, outer);

      inner.color = _fireflyInnerColor.withValues(alpha: 0.62 * a);
      canvas.drawCircle(c, sz * 2.0, inner);

      core.color = Colors.white.withValues(alpha: 0.95 * a);
      canvas.drawCircle(c, sz * 0.8, core);
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
    final double opacity = _rippleOpacityStart * (1.0 - eased);
    if (opacity <= 0.002) {
      return;
    }

    final Color ringColor = Color.lerp(
      _rippleCyanSoft,
      _rippleCyanDeep,
      eased,
    )!.withValues(alpha: opacity);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rippleStrokePx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = ringColor;

    canvas.drawCircle(r.center, radius, stroke);
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
    const double scaleWindow = 0.44;
    final double scaleT = (t / scaleWindow).clamp(0.0, 1.0);
    final double rawScale = 1.5 * Curves.elasticOut.transform(scaleT);
    final double scale = rawScale.clamp(0.0, 1.5);
    final double opacity =
        1.0 - Curves.easeInCubic.transform(((t - 0.12) / 0.88).clamp(0.0, 1.0));
    if (opacity <= 0.008 || scale <= 0.001) {
      return;
    }

    const double outer = 11;
    final Color base = p.fillColor;

    canvas.save();
    canvas.translate(p.position.dx, p.position.dy);
    canvas.rotate(p.rotation);
    canvas.scale(scale);

    final Path star = _roundedFivePointStarPath(
      const Offset(0, 0),
      outerR: outer,
      innerR: outer * 0.42,
    );

    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = base.withValues(alpha: opacity);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: opacity * 0.5);

    canvas.drawPath(star, fill);
    canvas.drawPath(star, stroke);
    canvas.restore();
  }

  static const List<Color> _bubbleIrisPalette = <Color>[
    Color(0xFFB9E7FF),
    Color(0xFFDDC4FF),
    Color(0xFFFFD6F2),
    Color(0xFFCFFFE8),
    Color(0xFFFFF2C7),
  ];

  Color _bubbleTint(double hueSeed, int idx) {
    final int k = ((hueSeed * 997.0).abs().floor() + idx) %
        _bubbleIrisPalette.length;
    return _bubbleIrisPalette[k];
  }

  void _paintSoapBubble(Canvas canvas, _SoapBubble b) {
    double scale = 1.0;
    double alpha = 1.0;

    if (b.popping) {
      final double pt = (b.popAgeMs / _bubblePopLifeMs).clamp(0.0, 1.0);
      scale = 1.0 + Curves.easeOutCubic.transform(pt) * 0.38;
      alpha = (1.0 - Curves.easeIn.transform(pt)).clamp(0.0, 1.0);
    } else {
      final double st = (b.spawnScaleMs / 220.0).clamp(0.0, 1.0);
      scale = Curves.easeOutBack.transform(st).clamp(0.0, 1.2);
    }
    if (alpha <= 0.01 || scale <= 0.01) {
      return;
    }

    final double r = b.radius * scale;
    final Offset c = Offset(b.x, b.y);

    // Thin outer glow halo — sells the "glowing rim".
    final Paint halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFFE0F4FF).withValues(alpha: 0.22 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(c, r, halo);

    // Translucent body — soapy milky-white radial gradient. The previously
    // near-clear interior now gets a soft white wash so the bubble reads as
    // a filled soap film against any background.
    final Rect bodyRect = Rect.fromCircle(center: c, radius: r);
    final Paint body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.18, -0.22),
        radius: 1.0,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.32 * alpha),
          Colors.white.withValues(alpha: 0.24 * alpha),
          Colors.white.withValues(alpha: 0.30 * alpha),
          Colors.white.withValues(alpha: 0.38 * alpha),
        ],
        stops: const <double>[0.0, 0.55, 0.85, 1.0],
      ).createShader(bodyRect);
    canvas.drawCircle(c, r, body);

    // Iridescent band — subtle rainbow sweep just inside the rim for the
    // "Nano Banana" colour-shifted soap sheen.
    final Paint iris = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18
      ..shader = SweepGradient(
        startAngle: b.hueSeed * math.pi * 2,
        endAngle: b.hueSeed * math.pi * 2 + math.pi * 2,
        colors: <Color>[
          _bubbleTint(b.hueSeed, 0).withValues(alpha: 0.22 * alpha),
          _bubbleTint(b.hueSeed, 1).withValues(alpha: 0.30 * alpha),
          _bubbleTint(b.hueSeed, 2).withValues(alpha: 0.22 * alpha),
          _bubbleTint(b.hueSeed, 3).withValues(alpha: 0.30 * alpha),
          _bubbleTint(b.hueSeed, 4).withValues(alpha: 0.22 * alpha),
          _bubbleTint(b.hueSeed, 0).withValues(alpha: 0.22 * alpha),
        ],
      ).createShader(bodyRect);
    canvas.drawCircle(c, r * 0.92, iris);

    // Thin crisp rim — the glowing edge outline.
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = Colors.white.withValues(alpha: 0.55 * alpha);
    canvas.drawCircle(c, r, rim);

    // Waxy specular highlight — small bright oval top-left.
    final Offset sheenCenter = Offset(
      c.dx - r * 0.36,
      c.dy - r * 0.42,
    );
    final Rect sheenRect = Rect.fromCenter(
      center: sheenCenter,
      width: r * 0.78,
      height: r * 0.42,
    );
    final Paint sheen = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.85 * alpha),
          Colors.white.withValues(alpha: 0.25 * alpha),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(sheenRect);
    canvas.save();
    canvas.translate(sheenCenter.dx, sheenCenter.dy);
    canvas.rotate(-0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: sheenRect.width,
        height: sheenRect.height,
      ),
      sheen,
    );
    canvas.restore();

    // Tiny pinpoint glint — extra wet-plastic waxy feel.
    final Paint glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * alpha);
    canvas.drawCircle(
      Offset(c.dx - r * 0.18, c.dy - r * 0.58),
      r * 0.07,
      glint,
    );
  }

  /// Organic blob path: walks lobe points at varying radii and connects them
  /// with [Path.quadraticBezierTo] through their midpoints, producing the soft
  /// rounded-edge silhouette characteristic of a thick paint splat.
  Path _buildSplatPath({
    required Offset center,
    required double radius,
    required double rotation,
    required Float32List radii,
    required Float32List angleJitter,
    double aspectX = 1.0,
    double aspectY = 1.0,
  }) {
    final int n = radii.length;
    final List<Offset> pts = List<Offset>.filled(n, Offset.zero);
    for (int i = 0; i < n; i++) {
      final double a = rotation + (i / n) * math.pi * 2 + angleJitter[i];
      final double r = radius * radii[i];
      // Per-axis stretch applied AFTER the polar placement so the silhouette
      // keeps its lobe structure but becomes egg-shaped, oval, etc.
      pts[i] = Offset(
        center.dx + math.cos(a) * r * aspectX,
        center.dy + math.sin(a) * r * aspectY,
      );
    }

    Offset mid(Offset a, Offset b) => Offset(
          (a.dx + b.dx) * 0.5,
          (a.dy + b.dy) * 0.5,
        );

    final Path path = Path();
    final Offset start = mid(pts[n - 1], pts[0]);
    path.moveTo(start.dx, start.dy);
    for (int i = 0; i < n; i++) {
      final Offset ctrl = pts[i];
      final Offset next = mid(pts[i], pts[(i + 1) % n]);
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, next.dx, next.dy);
    }
    path.close();
    return path;
  }

  /// Fade envelope for a splat (no fade-in — it bursts into view).
  double _splatAlpha(_PaintSplat s) {
    if (s.ageMs < _splatHoldMs) {
      return 1.0;
    }
    final double u =
        ((s.ageMs - _splatHoldMs) / _splatFadeMs).clamp(0.0, 1.0);
    return (1.0 - Curves.easeIn.transform(u)).clamp(0.0, 1.0);
  }

  /// Live radius: settled size modulated by the spring-wobble displacement.
  double _splatCurrentRadius(_PaintSplat s) {
    final double scale = math.max(0.0, 1.0 + s.wobbleDisplacement);
    return s.baseRadius * scale;
  }

  /// Solid-colour blob with a heavy gaussian blur — this layer is intended
  /// to be rendered inside a [ColorFiltered] widget whose matrix thresholds
  /// alpha, turning overlapping gaussians into one merged metaball.
  void _paintSplatMetaball(Canvas canvas, _PaintSplat s) {
    final double alpha = _splatAlpha(s);
    final double r = _splatCurrentRadius(s);
    if (alpha <= 0.01 || r <= 0.5) {
      return;
    }
    final Path blob = _buildSplatPath(
      center: s.center,
      radius: r,
      rotation: s.baseRotation,
      radii: s.lobeRadii,
      angleJitter: s.lobeAngleJitter,
      aspectX: s.aspectX,
      aspectY: s.aspectY,
    );
    // Solid vibrant colour so merges read cleanly after alpha-thresholding.
    final Paint paint = Paint()
      ..color = s.color.withValues(alpha: alpha)
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, _splatMetaballBlurSigma);
    canvas.drawPath(blob, paint);
  }

  /// Waxy "Nano Banana" highlight drawn OUTSIDE the metaball filter so it
  /// doesn't get thresholded — this is the secondary lighter paint layer
  /// on top of each blob that gives it a subtle raised/wet feel.
  void _paintSplatHighlight(Canvas canvas, _PaintSplat s) {
    final double alpha = _splatAlpha(s);
    final double r = _splatCurrentRadius(s);
    if (alpha <= 0.04 || r <= 1) {
      return;
    }

    final Color lighter = Color.lerp(s.color, Colors.white, 0.55)!;

    // Small inner shadow rim on the bottom-right for the 3D raised lip.
    // Offsets / sizes scale with the blob's aspect so heavily-stretched
    // splats don't have their sheen fall outside the silhouette.
    final double rx = r * s.aspectX;
    final double ry = r * s.aspectY;

    final Offset shadowCenter = Offset(
      s.center.dx + rx * 0.22,
      s.center.dy + ry * 0.28,
    );
    final Rect shadowRect = Rect.fromCenter(
      center: shadowCenter,
      width: rx * 1.56,
      height: ry * 1.56,
    );
    final Paint innerShadow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: 0.16 * alpha),
        ],
        stops: const <double>[0.55, 1.0],
      ).createShader(shadowRect);
    canvas.drawOval(shadowRect, innerShadow);

    // Top-left glossy highlight — waxy secondary paint layer.
    final Offset hc = Offset(
      s.center.dx - rx * 0.30,
      s.center.dy - ry * 0.36,
    );
    final Rect hr = Rect.fromCenter(
      center: hc,
      width: rx * 0.90,
      height: ry * 0.52,
    );
    final Paint highlight = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.55 * alpha),
          lighter.withValues(alpha: 0.28 * alpha),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(hr);
    canvas.save();
    canvas.translate(hc.dx, hc.dy);
    canvas.rotate(-0.42);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: hr.width,
        height: hr.height,
      ),
      highlight,
    );
    canvas.restore();
  }

  /// Public metaball-pass entry point — called from the dedicated
  /// [PaintSplatMetaballPainter] inside a [ColorFiltered] widget.
  void paintSplatMetaballs(Canvas canvas) {
    for (final _PaintSplat s in _paintSplats) {
      _paintSplatMetaball(canvas, s);
    }
  }

  /// Waxy-highlight pass — drawn on top of the merged metaball layer (NOT
  /// through the ColorFiltered threshold) so highlights remain subtle.
  void paintSplatHighlights(Canvas canvas) {
    for (final _PaintSplat s in _paintSplats) {
      _paintSplatHighlight(canvas, s);
    }
  }

  void _paintBubbleShard(Canvas canvas, _BubbleShard s) {
    final double t = (s.ageMs / s.lifeMs).clamp(0.0, 1.0);
    final double fade = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    if (fade <= 0.02) {
      return;
    }
    final double size = s.size * (1.0 - t * 0.35);
    final Color tint = _bubbleTint(s.hueSeed, 2);

    final Paint glow = Paint()
      ..color = tint.withValues(alpha: 0.25 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    canvas.drawCircle(Offset(s.x, s.y), size * 1.6, glow);

    final Paint core = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * fade);
    canvas.drawCircle(Offset(s.x, s.y), size, core);

    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = tint.withValues(alpha: 0.5 * fade);
    canvas.drawCircle(Offset(s.x, s.y), size, rim);
  }

  /// Beş uçlu yıldız; dış köşeler [quadraticBezierTo] ile yumuşatılmış (yuvarlak uçlar).
  Path _roundedFivePointStarPath(
    Offset c, {
    required double outerR,
    required double innerR,
  }) {
    const int points = 5;
    final List<Offset> outer = List<Offset>.generate(
      points,
      (int k) {
        final double a = -math.pi / 2 + k * 2 * math.pi / points;
        return Offset(
          c.dx + outerR * math.cos(a),
          c.dy + outerR * math.sin(a),
        );
      },
    );
    final List<Offset> inner = List<Offset>.generate(
      points,
      (int k) {
        final double a =
            -math.pi / 2 + k * 2 * math.pi / points + math.pi / points;
        return Offset(
          c.dx + innerR * math.cos(a),
          c.dy + innerR * math.sin(a),
        );
      },
    );

    final Path path = Path();
    path.moveTo(inner[points - 1].dx, inner[points - 1].dy);
    for (int k = 0; k < points; k++) {
      path.quadraticBezierTo(
        outer[k].dx,
        outer[k].dy,
        inner[k].dx,
        inner[k].dy,
      );
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
  Color fillColor = const Color(0xFFFFE082);
  bool alive = false;
}

class _SoapBubble {
  double x = 0;
  double y = 0;
  double baseX = 0;
  double radius = 30;
  double riseSpeed = 40;
  double swayAmp = 20;
  double swayFreq = 0.9;
  double swayPhase = 0;
  double ageMs = 0;
  double spawnScaleMs = 0;
  double hueSeed = 0;
  bool popping = false;
  double popAgeMs = 0;
  bool alive = false;
}

class _BubbleShard {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double size = 2;
  double hueSeed = 0;
  double ageMs = 0;
  double lifeMs = 400;
  bool alive = false;
}

enum BubbleTapResult { spawned, popped }

class _PaintSplat {
  Offset center = Offset.zero;
  double baseRadius = 60;
  double baseRotation = 0;
  // Per-axis stretch so each blob has a distinct egg / oval / wide silhouette.
  double aspectX = 1.0;
  double aspectY = 1.0;
  Color color = const Color(0xFFFB923C);
  Float32List lobeRadii = Float32List(0);
  Float32List lobeAngleJitter = Float32List(0);
  double ageMs = 0;
  // Spring-wobble state — rendered scale is (1 + wobbleDisplacement).
  double wobbleDisplacement = 0;
  double wobbleVelocity = 0;
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

/// Paints only the heavy-blurred, solid-colour paint-splat blobs onto a
/// transparent canvas. Intended to be the child of a [ColorFiltered] widget
/// whose matrix thresholds the alpha channel — together they produce the
/// metaball "merging" effect when blurred blobs overlap.
class PaintSplatMetaballPainter extends CustomPainter {
  PaintSplatMetaballPainter(this.engine) : super(repaint: engine);

  final PlayAreaAnimationEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    engine.paintSplatMetaballs(canvas);
  }

  @override
  bool shouldRepaint(covariant PaintSplatMetaballPainter oldDelegate) => false;
}

/// Paints the waxy top-left highlight + bottom-right inner-shadow pass over
/// the merged metaball layer. NOT wrapped by the threshold filter, so these
/// decorative layers remain subtle instead of being fully opaque/clipped.
class PaintSplatHighlightsPainter extends CustomPainter {
  PaintSplatHighlightsPainter(this.engine) : super(repaint: engine);

  final PlayAreaAnimationEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    engine.paintSplatHighlights(canvas);
  }

  @override
  bool shouldRepaint(covariant PaintSplatHighlightsPainter oldDelegate) =>
      false;
}
