import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

import '../../config/gemini_config.dart';

/// Mobile/desktop playback via flutter_sound streaming API.
class PcmAudioPlayer {
  FlutterSoundPlayer? _player;
  bool _streaming = false;

  Future<void> init() async {
    if (_player != null) return;
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: GeminiConfig.sampleRate,
      numChannels: GeminiConfig.channels,
      interleaved: false,
      // Larger buffer → fewer underrun clicks on desktop audio devices.
      bufferSize: 16384,
    );
    _streaming = true;
  }

  Future<void> addChunk(Uint8List data) async {
    if (data.isEmpty) return;
    if (!_streaming) await init();
    try {
      _player?.uint8ListSink?.add(data);
    } catch (_) {}
  }

  void clear() {
    _streaming = false;
    try {
      _player?.stopPlayer();
    } catch (_) {}
  }

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
