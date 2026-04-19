import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Hafif, çocuk dostu oyun alanı sesleri — [assets/audio] altındaki WAV dosyaları.
class GameplaySfx {
  GameplaySfx._();
  static final GameplaySfx instance = GameplaySfx._();

  AudioPlayer? _water;
  AudioPlayer? _star;
  AudioPlayer? _rain;
  bool _initialized = false;

  /// [pubspec.yaml] ile birebir aynı tam yol — web'de çift `assets/` oluşmasını önler.
  static const List<String> _rainNoteBundlePaths = <String>[
    'assets/audio/rain_note_c4.wav',
    'assets/audio/rain_note_d4.wav',
    'assets/audio/rain_note_e4.wav',
    'assets/audio/rain_note_g4.wav',
    'assets/audio/rain_note_a4.wav',
  ];

  final List<Uint8List?> _rainNoteBytes = List<Uint8List?>.filled(5, null);

  /// Web asset sunucusu zaten `assets/` kökünde; tekrar önek eklenince 404 olur.
  String _bundleLoadKey(String manifestPath) {
    if (kIsWeb && manifestPath.startsWith('assets/')) {
      return manifestPath.substring('assets/'.length);
    }
    return manifestPath;
  }

  Future<void> _ensureRainNotesLoaded() async {
    for (int i = 0; i < _rainNoteBundlePaths.length; i++) {
      if (_rainNoteBytes[i] != null) {
        continue;
      }
      final ByteData data = await rootBundle.load(
        _bundleLoadKey(_rainNoteBundlePaths[i]),
      );
      _rainNoteBytes[i] = data.buffer.asUint8List();
    }
  }

  /// İlk karede çağrılabilir; ilk dokunuşta gecikmeyi azaltır.
  Future<void> warmUp() async {
    if (_initialized) {
      return;
    }
    _water = AudioPlayer();
    _star = AudioPlayer();
    _rain = AudioPlayer();
    // WebAudio bazı cihazlarda lowLatency ile uyumsuz; web'de varsayılan mod.
    if (!kIsWeb) {
      await _water!.setPlayerMode(PlayerMode.lowLatency);
      await _star!.setPlayerMode(PlayerMode.lowLatency);
      await _rain!.setPlayerMode(PlayerMode.lowLatency);
    }
    await _water!.setReleaseMode(ReleaseMode.stop);
    await _star!.setReleaseMode(ReleaseMode.stop);
    await _rain!.setReleaseMode(ReleaseMode.stop);
    await _water!.setVolume(0.42);
    await _star!.setVolume(0.38);
    await _rain!.setVolume(0.34);
    await _ensureRainNotesLoaded();
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

  /// Musical Rain: pentatonik diziden gerçek nota sesi (Web için bytes + MIME).
  Future<void> playRainPentatonicChime(int pitchClass) async {
    try {
      await warmUp();
      final int index = pitchClass.clamp(0, _rainNoteBundlePaths.length - 1);
      final Uint8List? bytes = _rainNoteBytes[index];
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      await _rain!.setPlaybackRate(1.0);
      await _rain!.play(
        BytesSource(bytes, mimeType: 'audio/wav'),
      );
    } catch (_) {
      // Varlık veya platform hatasında sessizce devam et.
    }
  }

  Future<void> dispose() async {
    await _water?.dispose();
    await _star?.dispose();
    await _rain?.dispose();
    _water = null;
    _star = null;
    _rain = null;
    for (int i = 0; i < _rainNoteBytes.length; i++) {
      _rainNoteBytes[i] = null;
    }
    _initialized = false;
  }
}
