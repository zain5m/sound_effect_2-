import 'dart:typed_data';

import '../../models/pcm_audio_buffer.dart';

class PcmBufferSource {
  PcmBufferSource(this.buffer);

  final PcmAudioBuffer buffer;
  int _position = 0;

  bool get dualChannel => buffer.channels > 1;
  int get position => _position;
  set position(int value) => _position = value;

  int extract(Float32List target, int numFrames, [int position = 0]) {
    this.position = position;
    final left = buffer.getChannelData(0);
    final right = dualChannel
        ? buffer.getChannelData(1)
        : buffer.getChannelData(0);
    final framesToRead = numFrames < left.length - position
        ? numFrames
        : left.length - position;
    for (var i = 0; i < framesToRead; i++) {
      target[i * 2] = left[i + position];
      target[i * 2 + 1] = right[i + position];
    }
    return framesToRead;
  }
}
