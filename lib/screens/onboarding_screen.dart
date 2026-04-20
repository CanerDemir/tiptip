import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../gameplay/gameplay_mode.dart';
import '../theme/tiptip_colors.dart';
import '../widgets/tiptip_logo_mark.dart';

/// Karşılama ekranı: logo, selamlama, mod ikonları ve oyunu başlat CTA.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onStartPlaying});

  /// "Start Playing" basıldığında (ör. ana ekrana geçiş).
  final ValueChanged<GameplayMode>? onStartPlaying;

  static const double _wordmarkSize = 32;
  static const double _wordmarkTracking = _wordmarkSize * 0.02;
  static const double _greetingSize = 24;
  static const double _modeIconDiameter = 96;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  GameplayMode? _selectedMode;

  void _selectMode(GameplayMode mode) {
    HapticFeedback.lightImpact();
    setState(() => _selectedMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: TiptipColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            _Header(wordmarkTracking: OnboardingScreen._wordmarkTracking),
            const SizedBox(height: 28),
            Expanded(
              child: _Body(
                greetingSize: OnboardingScreen._greetingSize,
                modeIconDiameter: OnboardingScreen._modeIconDiameter,
                selectedMode: _selectedMode,
                onModeSelected: _selectMode,
              ),
            ),
            _StartPlayingFooter(
              paddingBottom: padding.bottom + 20,
              isEnabled: _selectedMode != null,
              onPressed: _selectedMode == null
                  ? null
                  : () => widget.onStartPlaying?.call(_selectedMode!),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.wordmarkTracking});

  final double wordmarkTracking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const TiptipLogoMark(size: 120),
          const SizedBox(height: 20),
          Text(
            'TıpTıp',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: OnboardingScreen._wordmarkSize,
              fontWeight: FontWeight.w700,
              letterSpacing: wordmarkTracking,
              color: TiptipColors.textPrimary,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.greetingSize,
    required this.modeIconDiameter,
    required this.selectedMode,
    required this.onModeSelected,
  });

  final double greetingSize;
  final double modeIconDiameter;
  final GameplayMode? selectedMode;
  final ValueChanged<GameplayMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hello, Friend!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: greetingSize,
              fontWeight: FontWeight.w500,
              color: TiptipColors.textPrimary,
              height: 1.35,
            ),
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.water,
                        isSelected: selectedMode == GameplayMode.water,
                        onTap: () => onModeSelected(GameplayMode.water),
                      ),
                      const SizedBox(width: 16),
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.star,
                        isSelected: selectedMode == GameplayMode.star,
                        onTap: () => onModeSelected(GameplayMode.star),
                      ),
                      const SizedBox(width: 16),
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.jelly,
                        isSelected: selectedMode == GameplayMode.jelly,
                        onTap: () => onModeSelected(GameplayMode.jelly),
                      ),
                      const SizedBox(width: 16),
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.musicalRain,
                        isSelected: selectedMode == GameplayMode.musicalRain,
                        onTap: () => onModeSelected(GameplayMode.musicalRain),
                      ),
                      const SizedBox(width: 16),
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.floralBloom,
                        isSelected: selectedMode == GameplayMode.floralBloom,
                        onTap: () => onModeSelected(GameplayMode.floralBloom),
                      ),
                      const SizedBox(width: 16),
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.magneticDust,
                        isSelected: selectedMode == GameplayMode.magneticDust,
                        onTap: () => onModeSelected(GameplayMode.magneticDust),
                      ),
                      const SizedBox(width: 16),
                      _ModeIconCircle(
                        diameter: modeIconDiameter,
                        mode: GameplayMode.soapBubbles,
                        isSelected: selectedMode == GameplayMode.soapBubbles,
                        onTap: () => onModeSelected(GameplayMode.soapBubbles),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModeIconCircle extends StatelessWidget {
  const _ModeIconCircle({
    required this.diameter,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final double diameter;
  final GameplayMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = mode.accent;
    return Semantics(
      label: mode.semanticLabel,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.62,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TiptipColors.surfaceLevel1,
                border: Border.all(
                  color: isSelected
                      ? iconColor.withValues(alpha: 0.75)
                      : iconColor.withValues(alpha: 0.18),
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: iconColor.withValues(alpha: isSelected ? 0.3 : 0.12),
                    blurRadius: isSelected ? 18 : 10,
                    spreadRadius: isSelected ? 1.5 : 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                mode.icon,
                size: diameter * (isSelected ? 0.48 : 0.44),
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mavi → turkuaz gradyan, hap şeklinde, geniş dokunma alanı ve hafif titreşim.
class _StartPlayingFooter extends StatelessWidget {
  const _StartPlayingFooter({
    required this.paddingBottom,
    required this.isEnabled,
    this.onPressed,
  });

  final double paddingBottom;
  final bool isEnabled;
  final VoidCallback? onPressed;

  static const LinearGradient _ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[TiptipColors.accentBlue, TiptipColors.accentTurquoise],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, paddingBottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isEnabled
              ? _ctaGradient
              : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    TiptipColors.textPrimary.withValues(alpha: 0.26),
                    TiptipColors.textPrimary.withValues(alpha: 0.19),
                  ],
                ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isEnabled
                  ? TiptipColors.accentTurquoise.withValues(alpha: 0.42)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  },
            borderRadius: BorderRadius.circular(999),
            splashColor: Colors.white.withValues(alpha: 0.22),
            highlightColor: Colors.white.withValues(alpha: 0.12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 58,
                minWidth: double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
                child: Center(
                  child: Text(
                    'Start Playing',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: isEnabled
                          ? TiptipColors.onAccent
                          : Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
