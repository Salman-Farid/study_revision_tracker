// Web playback: PCM16 → float → AudioContext at the *context* sample rate.
// Gapless scheduling + tiny edge fades — eliminates the "beep beep" clicks
// from discontinuous buffer starts on Chrome/Safari/Firefox.
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PcmAudioPlayer {
  web.AudioContext? _ctx;
  web.GainNode? _gain;
  double _nextTime = 0;
  bool _streaming = false;
  final List<web.AudioBufferSourceNode> _sources = [];
  Float32List _pending = Float32List(0);
  static const int _minFrames = 480; // ~10ms @ 48k — avoid tiny click buffers
  static const int _fadeFrames = 64;

  Future<void> init() async {
    if (_streaming && _ctx != null) return;
    _ctx ??= web.AudioContext();
    try {
      await _ctx!.resume().toDart;
    } catch (_) {}
    _gain ??= _ctx!.createGain();
    _gain!.gain.value = 1;
    try {
      _gain!.connect(_ctx!.destination);
    } catch (_) {}
    _nextTime = _ctx!.currentTime + 0.05;
    _streaming = true;
  }

  Future<void> addChunk(Uint8List data) async {
    if (data.isEmpty) return;
    if (!_streaming || _ctx == null) await init();
    final ctx = _ctx;
    final gain = _gain;
    if (ctx == null || gain == null) return;

    try {
      // Decode PCM16 → float at Gemini's 24 kHz.
      final inSamples = data.length ~/ 2;
      if (inSamples == 0) return;
      final src = Float32List(inSamples);
      final bd = ByteData.sublistView(data);
      for (var i = 0; i < inSamples; i++) {
        src[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
      }

      // Resample 24 kHz → AudioContext rate (usually 48 kHz).
      final ctxRate = ctx.sampleRate;
      final out = _resample(src, 24000.0, ctxRate);
      if (out.isEmpty) return;

      // Skip micro-chunks that only add clicks.
      if (out.length < _minFrames) {
        final merged = Float32List(_pending.length + out.length);
        merged.setAll(0, _pending);
        merged.setAll(_pending.length, out);
        _pending = merged;
        if (_pending.length < _minFrames) return;
      }

      final play = _pending.isEmpty ? out : _concat(_pending, out);
      _pending = Float32List(0);

      _applyEdgeFades(play);

      final buffer = ctx.createBuffer(1, play.length, ctxRate.toInt());
      buffer.copyToChannel(play.toJS, 0);

      final node = ctx.createBufferSource();
      node.buffer = buffer;
      node.connect(gain);

      final now = ctx.currentTime;
      // If we fell more than 200ms behind, restart the timeline cleanly.
      if (_nextTime < now - 0.2) {
        _nextTime = now + 0.03;
      }
      final startAt = _nextTime > now ? _nextTime : now + 0.03;
      node.start(startAt);
      _nextTime = startAt + (play.length / ctxRate);

      final srcNode = node;
      _sources.add(srcNode);
      srcNode.onended = ((web.Event _) {
        _sources.remove(srcNode);
      }).toJS;
    } catch (_) {}
  }

  Float32List _resample(Float32List input, double fromRate, double toRate) {
    if ((fromRate - toRate).abs() < 1 || input.isEmpty) return input;
    final ratio = fromRate / toRate;
    final outLen = (input.length / ratio).floor();
    if (outLen <= 0) return Float32List(0);
    final out = Float32List(outLen);
    for (var i = 0; i < outLen; i++) {
      final srcPos = i * ratio;
      final i0 = srcPos.floor();
      final i1 = (i0 + 1 < input.length) ? i0 + 1 : i0;
      final t = srcPos - i0;
      out[i] = input[i0] * (1 - t) + input[i1] * t;
    }
    return out;
  }

  Float32List _concat(Float32List a, Float32List b) {
    final out = Float32List(a.length + b.length);
    out.setAll(0, a);
    out.setAll(a.length, b);
    return out;
  }

  /// Short linear fades kill the square-wave "beep" at buffer seams.
  void _applyEdgeFades(Float32List samples) {
    final n = samples.length;
    if (n < _fadeFrames * 2) return;
    for (var i = 0; i < _fadeFrames; i++) {
      final g = i / _fadeFrames;
      samples[i] *= g;
      samples[n - 1 - i] *= g;
    }
  }

  void clear() {
    _streaming = false;
    _pending = Float32List(0);
    for (final s in List.of(_sources)) {
      try {
        s.stop();
      } catch (_) {}
    }
    _sources.clear();
    _nextTime = 0;
  }

  Future<void> dispose() async {
    clear();
    try {
      _gain?.disconnect();
    } catch (_) {}
    _gain = null;
    try {
      await _ctx?.close().toDart;
    } catch (_) {}
    _ctx = null;
  }
}
