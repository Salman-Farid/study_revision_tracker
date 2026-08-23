import 'dart:typed_data';

import '../../config/gemini_config.dart';

class PcmConverter {
  PcmConverter._();

  /// Convert raw 24kHz 16-bit mono PCM bytes to a complete WAV file
  static Uint8List pcmToWav(Uint8List pcm) {
    final sampleRate = GeminiConfig.sampleRate;
    final channels = GeminiConfig.channels;
    final bitDepth = GeminiConfig.bitDepth;
    final byteRate = sampleRate * channels * (bitDepth ~/ 8);
    final blockAlign = channels * (bitDepth ~/ 8);
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);

    // RIFF header
    _setAscii(header, 0, 'RIFF');
    header.setUint32(4, fileSize, Endian.little);
    _setAscii(header, 8, 'WAVE');

    // fmt sub-chunk
    _setAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // sub-chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitDepth, Endian.little);

    // data sub-chunk
    _setAscii(header, 36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    // Combine header + PCM
    final wav = Uint8List(44 + dataSize);
    wav.setAll(0, header.buffer.asUint8List());
    wav.setAll(44, pcm);
    return wav;
  }

  /// Write ASCII string into ByteData at [offset]
  static void _setAscii(ByteData bd, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      bd.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
