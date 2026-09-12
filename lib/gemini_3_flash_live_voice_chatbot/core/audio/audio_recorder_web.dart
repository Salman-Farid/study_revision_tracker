// Web mic: getUserMedia + AudioContext + ScriptProcessor → PCM16 @ 24 kHz.
// Browser capture runs at the AudioContext rate (44.1/48 kHz); we resample
// down to Gemini Live's 24 kHz mono PCM16.
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../config/gemini_config.dart';

class MicRecorder {
  MicRecorder();

  final _audioController = StreamController<Uint8List>.broadcast();
  web.MediaStream? _stream;
  web.AudioContext? _ctx;
  web.ScriptProcessorNode? _processor;
  web.MediaStreamAudioSourceNode? _source;
  web.MediaStreamAudioDestinationNode? _sink;
  JSFunction? _listener;
  bool _active = false;
  double _ctxRate = 48000;
  Float32List _carry = Float32List(0);

  Stream<Uint8List> get audioStream => _audioController.stream;

  Future<bool> isRecording() async => _active;

  Future<bool> hasPermission() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      final tracks = stream.getTracks().toDart;
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> start() async {
    if (_active) return true;
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      _stream = stream;

      final ctx = web.AudioContext();
      _ctx = ctx;
      _ctxRate = ctx.sampleRate;
      try {
        await ctx.resume().toDart;
      } catch (_) {}

      _source = ctx.createMediaStreamSource(stream);
      _processor = ctx.createScriptProcessor(4096, 1, 1);
      // Sink into a silent MediaStreamDestination — never ctx.destination.
      // Connecting mic → speakers (even at gain 0) can produce beeps/feedback.
      _sink = ctx.createMediaStreamDestination();

      void onProcess(web.Event event) {
        if (!_active) return;
        try {
          final e = event as web.AudioProcessingEvent;
          final floats = e.inputBuffer.getChannelData(0).toDart;
          if (floats.isEmpty) return;
          final pcm = _toPcm16At24k(floats);
          if (pcm.isNotEmpty) _audioController.add(pcm);
        } catch (_) {}
      }

      _listener = onProcess.toJS;
      _processor!.addEventListener('audioprocess', _listener as web.EventListener);

      _source!.connect(_processor!);
      _processor!.connect(_sink!);

      _active = true;
      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  /// Resample context-rate float samples → 24 kHz PCM16 bytes.
  Uint8List _toPcm16At24k(Float32List input) {
    final target = GeminiConfig.sampleRate.toDouble();
    Float32List samples;
    if ((_ctxRate - target).abs() < 1) {
      samples = input;
    } else {
      final ratio = _ctxRate / target;
      // Fold leftover fractional samples into the next chunk.
      final all = Float32List(_carry.length + input.length);
      all.setAll(0, _carry);
      all.setAll(_carry.length, input);
      final outLen = (all.length / ratio).floor();
      samples = Float32List(outLen);
      for (var i = 0; i < outLen; i++) {
        final src = i * ratio;
        final i0 = src.floor();
        final i1 = (i0 + 1 < all.length) ? i0 + 1 : i0;
        final t = src - i0;
        samples[i] = all[i0] * (1 - t) + all[i1] * t;
      }
      final consumed = (outLen * ratio).floor();
      final left = all.length - consumed;
      _carry = left > 0 ? Float32List.sublistView(all, consumed) : Float32List(0);
    }
    if (samples.isEmpty) return Uint8List(0);
    final out = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      var s = samples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      out.setInt16(i * 2, (s * 32767).round(), Endian.little);
    }
    return out.buffer.asUint8List();
  }

  Future<void> stop() async {
    _active = false;
    try {
      if (_processor != null && _listener != null) {
        _processor!.removeEventListener('audioprocess', _listener as web.EventListener);
      }
      _processor?.disconnect();
      _source?.disconnect();
      _sink?.disconnect();
    } catch (_) {}
    _listener = null;
    _processor = null;
    _source = null;
    _sink = null;
    _carry = Float32List(0);
    try {
      final tracks = _stream?.getTracks().toDart;
      if (tracks != null) {
        for (var i = 0; i < tracks.length; i++) {
          tracks[i].stop();
        }
      }
    } catch (_) {}
    _stream = null;
    try {
      await _ctx?.close().toDart;
    } catch (_) {}
    _ctx = null;
  }

  void dispose() {
    unawaited(stop());
    if (!_audioController.isClosed) _audioController.close();
  }
}
