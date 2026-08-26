import 'dart:typed_data';

import '../models/pcm_audio_buffer.dart';

/// Writes IEEE-float WAV so the DSP result is not quantized to 16-bit during export.
class WavEncoder {
  static Uint8List encode(PcmAudioBuffer buffer, {bool normalizePeak = true}) {
    const formatCode = 3; // WAVE_FORMAT_IEEE_FLOAT
    const bitDepth = 32;
    const bytesPerSample = bitDepth ~/ 8;

    final numChannels = buffer.channels;
    final sampleRate = buffer.sampleRate;
    final blockAlign = numChannels * bytesPerSample;
    final dataLength = buffer.length * blockAlign;
    final totalLength = 44 + dataLength;

    var gain = 1.0;
    if (normalizePeak) {
      var peak = 0.0;
      for (var frame = 0; frame < buffer.length; frame++) {
        for (var channel = 0; channel < numChannels; channel++) {
          final value = buffer.getChannelData(channel)[frame].abs();
          if (value > peak) peak = value;
        }
      }
      // Leave a small ceiling to avoid inter-sample clipping in consumers.
      if (peak > 0.999) gain = 0.999 / peak;
    }

    final bytes = Uint8List(totalLength);
    final view = ByteData.sublistView(bytes);

    void writeString(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        view.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeString(0, 'RIFF');
    view.setUint32(4, totalLength - 8, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, formatCode, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * blockAlign, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitDepth, Endian.little);
    writeString(36, 'data');
    view.setUint32(40, dataLength, Endian.little);

    var offset = 44;
    for (var frame = 0; frame < buffer.length; frame++) {
      for (var channel = 0; channel < numChannels; channel++) {
        final sample = buffer.getChannelData(channel)[frame] * gain;
        view.setFloat32(offset, sample, Endian.little);
        offset += bytesPerSample;
      }
    }

    return bytes;
  }
}
