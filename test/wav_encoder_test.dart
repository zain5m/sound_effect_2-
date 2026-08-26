import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_effect_2/models/pcm_audio_buffer.dart';
import 'package:sound_effect_2/services/wav_encoder.dart';

void main() {
  test('exports IEEE float WAV without forcing 16-bit PCM', () {
    final buffer = PcmAudioBuffer(
      channels: 2,
      sampleRate: 48000,
      channelData: [
        Float32List.fromList([0.5, -0.25]),
        Float32List.fromList([-0.5, 0.25]),
      ],
    );

    final bytes = WavEncoder.encode(buffer, normalizePeak: false);
    final view = ByteData.sublistView(bytes);

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(view.getUint16(20, Endian.little), 3);
    expect(view.getUint16(22, Endian.little), 2);
    expect(view.getUint32(24, Endian.little), 48000);
    expect(view.getUint16(34, Endian.little), 32);
    expect(view.getFloat32(44, Endian.little), closeTo(0.5, 1e-6));
    expect(view.getFloat32(48, Endian.little), closeTo(-0.5, 1e-6));
  });
}
