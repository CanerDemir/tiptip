import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/gameplay_sfx.dart';
import '../gameplay/gameplay_mode.dart';
import '../gameplay/play_area_engine.dart';
import '../theme/tiptip_colors.dart';

/// Oyun ekranı: üstte kaydırmalı mod şeridi, altta CustomPaint oyun alanı.
class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, this.initialMode = GameplayMode.water});

  final GameplayMode initialMode;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  late final ScrollController _modeScrollController;
  late final AnimationController _pulseController;
  late final PlayAreaAnimationEngine _playEngine;

  late int _activeModeIndex;
  bool _isModeAnimating = false;
  final math.Random _noteRandom = math.Random();
  int _lastRainPitch = -1;

  static const double _iconSlot = 56;
  static const double _modeSpacing = 20;

  @override
  void initState() {
    super.initState();
    _activeModeIndex = GameplayMode.values.indexOf(widget.initialMode);
    _modeScrollController = ScrollController(
      initialScrollOffset: _activeModeIndex * _modeStride,
    );
    _modeScrollController.addListener(_handleModeScroll);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _playEngine = PlayAreaAnimationEngine(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(GameplaySfx.instance.warmUp());
    });
  }

  void _handleModeScroll() {
    if (!_modeScrollController.hasClients) {
      return;
    }
    final int next = _centeredIndexForOffset(_modeScrollController.offset);
    if (next != _activeModeIndex) {
      setState(() => _activeModeIndex = next);
    }
  }

  double get _modeStride => _iconSlot + _modeSpacing;

  int _centeredIndexForOffset(double offset) {
    final double s = _modeStride;
    final int idx = ((offset + s / 2) / s).floor().clamp(
      0,
      GameplayMode.values.length - 1,
    );
    return idx;
  }

  Future<void> _snapModeToCenter() async {
    if (_isModeAnimating || !_modeScrollController.hasClients) {
      return;
    }
    final double s = _modeStride;
    final int idx = _centeredIndexForOffset(_modeScrollController.offset);
    final double target = idx * s;
    final double delta = (_modeScrollController.offset - target).abs();
    if (delta < 0.5) {
      if (mounted && _activeModeIndex != idx) {
        setState(() => _activeModeIndex = idx);
      }
      return;
    }
    _isModeAnimating = true;
    try {
      await _modeScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      if (mounted) {
        setState(() => _activeModeIndex = idx);
      }
    } finally {
      _isModeAnimating = false;
    }
  }

  Future<void> _selectModeByTap(int index) async {
    if (_isModeAnimating) {
      return;
    }
    if (!_modeScrollController.hasClients) {
      setState(() => _activeModeIndex = index);
      return;
    }
    HapticFeedback.lightImpact();
    final double target = index * _modeStride;
    final double delta = (_modeScrollController.offset - target).abs();
    if (delta < 0.5) {
      if (mounted && _activeModeIndex != index) {
        setState(() => _activeModeIndex = index);
      }
      return;
    }
    _isModeAnimating = true;
    try {
      await _modeScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      if (mounted) {
        setState(() => _activeModeIndex = index);
      }
    } finally {
      _isModeAnimating = false;
    }
  }

  void _onPlayAreaTap(TapDownDetails details, Size areaSize) {
    HapticFeedback.lightImpact();
    final GameplayMode mode = GameplayMode.values[_activeModeIndex];
    int? pitchClass;
    switch (mode) {
      case GameplayMode.water:
        unawaited(GameplaySfx.instance.playWaterDrip());
        break;
      case GameplayMode.star:
        unawaited(GameplaySfx.instance.playStarTwinkle());
        break;
      case GameplayMode.jelly:
        break;
      case GameplayMode.musicalRain:
        pitchClass = _nextRainPitchClass();
        unawaited(GameplaySfx.instance.playRainPentatonicChime(pitchClass));
        break;
      case GameplayMode.floralBloom:
        unawaited(GameplaySfx.instance.playWaterDrip());
        break;
    }
    _playEngine.handleTapWithPitch(
      details.localPosition,
      areaSize,
      mode,
      pitchClass,
    );
  }

  int _nextRainPitchClass() {
    int next = _noteRandom.nextInt(5);
    if (next == _lastRainPitch) {
      next = (next + 1 + _noteRandom.nextInt(4)) % 5;
    }
    _lastRainPitch = next;
    return next;
  }

  @override
  void dispose() {
    _modeScrollController.removeListener(_handleModeScroll);
    _modeScrollController.dispose();
    _pulseController.dispose();
    _playEngine.dispose();
    unawaited(GameplaySfx.instance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TiptipColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: _ModeSelectorTopBar(
              scrollController: _modeScrollController,
              pulse: _pulseController,
              activeIndex: _activeModeIndex,
              iconSlot: _iconSlot,
              modeSpacing: _modeSpacing,
              onScrollEnd: _snapModeToCenter,
              onModeTap: _selectModeByTap,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size areaSize = constraints.biggest;
                return RepaintBoundary(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails d) =>
                        _onPlayAreaTap(d, areaSize),
                    child: CustomPaint(
                      painter: PlayAreaPainter(_playEngine),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelectorTopBar extends StatelessWidget {
  const _ModeSelectorTopBar({
    required this.scrollController,
    required this.pulse,
    required this.activeIndex,
    required this.iconSlot,
    required this.modeSpacing,
    required this.onScrollEnd,
    required this.onModeTap,
  });

  final ScrollController scrollController;
  final Animation<double> pulse;
  final int activeIndex;
  final double iconSlot;
  final double modeSpacing;
  final Future<void> Function() onScrollEnd;
  final Future<void> Function(int index) onModeTap;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double sidePadding = (screenWidth - iconSlot) / 2;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TiptipColors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SizedBox(
          height: iconSlot * 1.35 + 4,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (ScrollEndNotification notification) {
              onScrollEnd();
              return false;
            },
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              itemCount: GameplayMode.values.length,
              separatorBuilder: (_, _) => SizedBox(width: modeSpacing),
              itemBuilder: (BuildContext context, int index) {
                final GameplayMode mode = GameplayMode.values[index];
                final bool isActive = index == activeIndex;
                return _ModeIconCell(
                  mode: mode,
                  isActive: isActive,
                  iconSlot: iconSlot,
                  pulse: pulse,
                  onTap: () => onModeTap(index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeIconCell extends StatelessWidget {
  const _ModeIconCell({
    required this.mode,
    required this.isActive,
    required this.iconSlot,
    required this.pulse,
    required this.onTap,
  });

  final GameplayMode mode;
  final bool isActive;
  final double iconSlot;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double scale = isActive ? 1.2 : 1.0;
    final double opacity = isActive ? 1.0 : 0.5;

    Widget iconCircle(List<BoxShadow> shadows) {
      return Container(
        width: iconSlot,
        height: iconSlot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TiptipColors.surfaceLevel1,
          boxShadow: shadows,
        ),
        alignment: Alignment.center,
        child: Icon(mode.icon, size: iconSlot * 0.46, color: mode.accent),
      );
    }

    return Semantics(
      label: mode.semanticLabel,
      selected: isActive,
      button: true,
      child: SizedBox(
        width: iconSlot,
        height: iconSlot * 1.35,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: isActive
                ? AnimatedBuilder(
                    animation: pulse,
                    builder: (BuildContext context, Widget? child) {
                      final double t = pulse.value;
                      final double glowBlur = 10 + 14 * t;
                      final double glowSpread = 1 + 3 * t;
                      final double glowOpacity = 0.28 + 0.35 * t;
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: iconCircle(<BoxShadow>[
                            BoxShadow(
                              color: TiptipColors.accentTurquoise.withValues(
                                alpha: glowOpacity,
                              ),
                              blurRadius: glowBlur,
                              spreadRadius: glowSpread,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]),
                        ),
                      );
                    },
                  )
                : Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: iconCircle(<BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
