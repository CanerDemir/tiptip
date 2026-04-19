import 'package:audioplayers/audioplayers.dart';

/// Hafif, çocuk dostu oyun alanı sesleri — [assets/audio] altındaki WAV dosyaları.
class GameplaySfx {
  GameplaySfx._();
  static final GameplaySfx instance = GameplaySfx._();

  AudioPlayer? _water;
  AudioPlayer? _star;
  bool _initialized = false;

  /// İlk karede çağrılabilir; ilk dokunuşta gecikmeyi azaltır.
  Future<void> warmUp() async {
    if (_initialized) {
      return;
    }
    _water = AudioPlayer();
    _star = AudioPlayer();
    await _water!.setPlayerMode(PlayerMode.lowLatency);
    await _star!.setPlayerMode(PlayerMode.lowLatency);
    await _water!.setReleaseMode(ReleaseMode.stop);
    await _star!.setReleaseMode(ReleaseMode.stop);
    await _water!.setVolume(0.42);
    await _star!.setVolume(0.38);
    _initialized = true;
  }

  /// Su modu: yumuşak damla / damlama.
  Future<void> playWaterDrip() async {
    try {
      await warmUp();
      await _water!.play(AssetSource('audio/water_drip.wav'));
    } catch (_) {
      // Varlık veya platform hatasında sessizce devam et.
    }
  }

  /// Yıldız modu: parlak, kısa “twinkle” dokunuşu.
  Future<void> playStarTwinkle() async {
    try {
      await warmUp();
      await _star!.play(AssetSource('audio/star_twinkle.wav'));
    } catch (_) {
      // Varlık veya platform hatasında sessizce devam et.
    }
  }

  Future<void> dispose() async {
    await _water?.dispose();
    await _star?.dispose();
    _water = null;
    _star = null;
    _initialized = false;
  }
}
