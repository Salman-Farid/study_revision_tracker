// Web playback: PCM16 → float → AudioContext at the context sample rate.
// Longer edge fades + micro-overlap between chunks for smoother speech
// (remaining "beep" is buffer-seam clicks).
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PcmAudioPlayer {
  web.AudioContext? _ctx;
  web.GainNode? _gain;
  double _nextTime = 0;
  bool _streaming = false;
  final List<web.AudioBufferSourceNode> _sources = [];
  Float32List _pending = Float32List(0);
  double _lastSample = 0;

  // ~40ms minimum chunk; ~12ms fade; 6ms overlap so seams are inaudible.
  static const int _minFrames = 2048;
  static const int _fadeFrames = 512;
  static const double _overlapSec = 0.006;

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
    _nextTime = _ctx!.currentTime + 0.08;
    _streaming = true;
  }

  Future<void> addChunk(Uint8List data) async {
    if (data.isEmpty) return;
    if (!_streaming || _ctx == null) await init();
    final ctx = _ctx;
    final gain = _gain;
    if (ctx == null || gain == null) return;

    try {
      final inSamples = data.length ~/ 2;
      if (inSamples == 0) return;
      final raw = Float32List(inSamples);
      final bd = ByteData.sublistView(data);
      for (var i = 0; i < inSamples; i++) {
        raw[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
      }

      final ctxRate = ctx.sampleRate;
      var out = _resample(raw, 24000.0, ctxRate);
      if (out.isEmpty) return;

      // Soft-start from the previous last sample to kill DC steps.
      if (_lastSample != 0 && out.isNotEmpty) {
        out[0] = (out[0] + _lastSample) * 0.5;
      }

      if (out.length < _minFrames) {
        final merged = Float32List(_pending.length + out.length);
        merged.setAll(0, _pending);
        merged.setAll(_pending.length, out);
        _pending = merged;
        if (_pending.length < _minFrames) return;
        out = _pending;
        _pending = Float32List(0);
      } else if (_pending.isNotEmpty) {
        out = _concat(_pending, out);
        _pending = Float32List(0);
      }

      if (out.isNotEmpty) _lastSample = out[out.length - 1];
      _applyEdgeFades(out);

      final buffer = ctx.createBuffer(1, out.length, ctxRate.toInt());
      buffer.copyToChannel(out.toJS, 0);

      final node = ctx.createBufferSource();
      node.buffer = buffer;
      node.connect(gain);

      final now = ctx.currentTime;
      if (_nextTime < now - 0.25) {
        _nextTime = now + 0.04;
      }
      // Start slightly early so the fade-in overlaps the previous fade-out.
      var startAt = _nextTime > now + _overlapSec
          ? _nextTime - _overlapSec
          : now + 0.04;
      if (startAt < now) startAt = now + 0.01;
      node.start(startAt);
      _nextTime = startAt + (out.length / ctxRate);

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
      final i1 = math.min(i0 + 1, input.length - 1);
      final t = srcPos - i0;
      // Smoothstep interpolation — fewer zipper artifacts than linear.
      final s = t * t * (3 - 2 * t);
      out[i] = input[i0] * (1 - s) + input[i1] * s;
    }
    return out;
  }

  Float32List _concat(Float32List a, Float32List b) {
    final out = Float32List(a.length + b.length);
    out.setAll(0, a);
    out.setAll(a.length, b);
    return out;
  }

  void _applyEdgeFades(Float32List samples) {
    final n = samples.length;
    if (n < _fadeFrames * 2) return;
    for (var i = 0; i < _fadeFrames; i++) {
      // Raised-cosine (equal-power-ish) fade — smoother than linear.
      final t = i / _fadeFrames;
      final g = 0.5 - 0.5 * math.cos(math.pi * t);
      samples[i] *= g;
      samples[n - 1 - i] *= g;
    }
  }

  void clear() {
    _streaming = false;
    _pending = Float32List(0);
    _lastSample = 0;
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
