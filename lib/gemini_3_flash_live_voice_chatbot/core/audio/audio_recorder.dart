import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../config/gemini_config.dart';

class MicRecorder {
  MicRecorder();

  final _recorder = AudioRecorder();
  final _audioController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _recordSub;

  Stream<Uint8List> get audioStream => _audioController.stream;
  Future<bool> Function() get isRecording => _recorder.isRecording;

  Future<bool> hasPermission() async => _recorder.hasPermission();

  /// Start streaming mic audio as raw 24kHz 16-bit PCM
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

    return true;
  }

  Future<void> stop() async {
    await _recordSub?.cancel();
    _recordSub = null;
    await _recorder.stop();
  }

  void dispose() {
    _recordSub?.cancel();
    _audioController.close();
    _recorder.dispose();
  }
}
