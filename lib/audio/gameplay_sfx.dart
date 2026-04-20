import 'dart:math' as math;
import 'dart:typed_data';

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
  AudioPlayer? _bubble;
  Uint8List? _bubblePopBytes;
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
    _bubble = AudioPlayer();
    // WebAudio bazı cihazlarda lowLatency ile uyumsuz; web'de varsayılan mod.
    if (!kIsWeb) {
      await _water!.setPlayerMode(PlayerMode.lowLatency);
      await _star!.setPlayerMode(PlayerMode.lowLatency);
      await _rain!.setPlayerMode(PlayerMode.lowLatency);
      await _bubble!.setPlayerMode(PlayerMode.lowLatency);
    }
    await _water!.setReleaseMode(ReleaseMode.stop);
    await _star!.setReleaseMode(ReleaseMode.stop);
    await _rain!.setReleaseMode(ReleaseMode.stop);
    await _bubble!.setReleaseMode(ReleaseMode.stop);
    await _water!.setVolume(0.42);
    await _star!.setVolume(0.38);
    await _rain!.setVolume(0.34);
    await _bubble!.setVolume(0.5);
    await _ensureRainNotesLoaded();
    _bubblePopBytes ??= _synthesizeBubblePopWav();
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

  /// Soap Bubbles: hafif, yumuşak "pop" — anında çalsın diye WAV bellekte üretilir.
  Future<void> playBubblePop() async {
    try {
      await warmUp();
      final Uint8List? bytes = _bubblePopBytes;
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      await _bubble!.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Varlık veya platform hatasında sessizce devam et.
    }
  }

  /// Düşen-frekanslı kısa darbe + eksponansiyel zarf → çocuk dostu "tıp" pop.
  ///
  /// 16-bit PCM, mono, 22050 Hz. audioplayers [BytesSource] için tam RIFF/WAV
  /// başlığı yazılır; böylece dosya yolu / asset gerektirmez ve platformdan
  /// bağımsız çalar.
  Uint8List _synthesizeBubblePopWav() {
    const int sampleRate = 22050;
    const double durationSec = 0.11;
    final int numSamples = (sampleRate * durationSec).floor();
    final int dataSize = numSamples * 2;
    final ByteData bd = ByteData(44 + dataSize);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        bd.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    bd.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    writeAscii(36, 'data');
    bd.setUint32(40, dataSize, Endian.little);

    double phase = 0;
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      // Yüksekten alçağa iniyen chirp — sabun balonu "bluup" hissi.
      final double freq = 240 + 1050 * math.exp(-t * 26);
      phase += 2 * math.pi * freq / sampleRate;
      // Hızlı atak (≈8 ms) + eksponansiyel kuyruk.
      final double attack = math.min(1.0, t * 125);
      final double decay = math.exp(-t * 28);
      final double env = attack * decay;
      // Hafif harmonik katkı soft "wet" karakter katar.
      final double s = (math.sin(phase) * 0.85 +
              math.sin(phase * 2.02) * 0.12) *
          env *
          0.78;
      final int iv = (s * 32767).clamp(-32768.0, 32767.0).toInt();
      bd.setInt16(44 + i * 2, iv, Endian.little);
    }

    return bd.buffer.asUint8List();
  }

  Future<void> dispose() async {
    await _water?.dispose();
    await _star?.dispose();
    await _rain?.dispose();
    await _bubble?.dispose();
    _water = null;
    _star = null;
    _rain = null;
    _bubble = null;
    _bubblePopBytes = null;
    for (int i = 0; i < _rainNoteBytes.length; i++) {
      _rainNoteBytes[i] = null;
    }
    _initialized = false;
  }
}
