import 'dart:typed_data';

import '../models/pcm_audio_buffer.dart';

class WavEncoder {
  static Uint8List encode(PcmAudioBuffer buffer) {
    const format = 1;
    const bitDepth = 16;
    const bytesPerSample = bitDepth ~/ 8;
    final numChannels = buffer.channels;
    final sampleRate = buffer.sampleRate;
    final blockAlign = numChannels * bytesPerSample;
    final dataLength = buffer.length * numChannels * bytesPerSample;
    final totalLength = 44 + dataLength;

    final bytes = Uint8List(totalLength);
    final view = ByteData.sublistView(bytes);

    void writeString(int offset, String string) {
      for (var i = 0; i < string.length; i++) {
        view.setUint8(offset + i, string.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    view.setUint32(4, totalLength - 8, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, format, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * blockAlign, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitDepth, Endian.little);
    writeString(36, 'data');
    view.setUint32(40, dataLength, Endian.little);

    var offset = 44;
    for (var i = 0; i < buffer.length; i++) {
      for (var ch = 0; ch < numChannels; ch++) {
        final sample = buffer.getChannelData(ch)[i].clamp(-1.0, 1.0);
        final intSample = sample < 0
            ? (sample * 0x8000).round()
            : (sample * 0x7FFF).round();
        view.setInt16(offset, intSample, Endian.little);
        offset += 2;
      }
    }

    return bytes;
  }
}
