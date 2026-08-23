import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

import '../../config/gemini_config.dart';

/// Streams raw PCM16 audio from Gemini Live to the device speaker.
///
/// Uses flutter_sound's streaming API: startPlayerFromStream opens the
/// audio output once, then uint8ListSink pushes chunks in real-time.
/// No stop/start cycle per chunk — continuous playback.
class PcmAudioPlayer {
  FlutterSoundPlayer? _player;
  bool _streaming = false;

  /// Open the audio output stream once. Call before addChunk.
  Future<void> init() async {
    if (_player != null) return;
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: GeminiConfig.sampleRate,
      numChannels: GeminiConfig.channels,
      interleaved: false,
      bufferSize: 8192,
    );
    _streaming = true;
  }

  /// Push a PCM16 chunk into the audio output stream.
  /// Safe to call from any isolate / stream listener.
  Future<void> addChunk(Uint8List data) async {
    if (data.isEmpty) return;
    if (!_streaming) await init();
    try {
      _player?.uint8ListSink?.add(data);
    } catch (_) {
      // Audio is non-critical — continue without crashing
    }
  }

  /// Flush any buffered audio and stop playback.
  void clear() {
    _streaming = false;
    try {
      _player?.stopPlayer();
    } catch (_) {}
  }

  /// Release all resources.
  Future<void> dispose() async {
    _streaming = false;
    if (_player != null) {
      try {
        await _player!.stopPlayer();
        await _player!.closePlayer();
      } catch (_) {}
      _player = null;
    }
  }
}
