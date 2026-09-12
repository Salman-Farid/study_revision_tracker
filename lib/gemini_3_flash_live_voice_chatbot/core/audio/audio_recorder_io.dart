import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../config/gemini_config.dart';

/// Mobile/desktop mic via the `record` package (raw PCM stream).
class MicRecorder {
  MicRecorder();

  final _recorder = AudioRecorder();
  final _audioController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _recordSub;
  bool _active = false;

  Stream<Uint8List> get audioStream => _audioController.stream;

  Future<bool> isRecording() async => _active && await _recorder.isRecording();

  Future<bool> hasPermission() async => _recorder.hasPermission();

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;

    final stream = await _recorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: GeminiConfig.sampleRate,
      numChannels: GeminiConfig.channels,
    ));

    _recordSub = stream.listen((data) {
      _audioController.add(Uint8List.fromList(data));
    });
    _active = true;
    return true;
  }

  Future<void> stop() async {
    _active = false;
    await _recordSub?.cancel();
    _recordSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  void dispose() {
    _active = false;
    _recordSub?.cancel();
    _audioController.close();
    _recorder.dispose();
  }
}
