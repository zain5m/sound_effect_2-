import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_effect_2/models/pcm_audio_buffer.dart';
import 'package:sound_effect_2/native/speed_processor.dart';
import 'package:sound_effect_2/native/stretch_ffi.dart';

void main() {
  group('PcmAudioBuffer interleave', () {
    test('round-trips stereo samples', () {
      final buffer = PcmAudioBuffer(
        channels: 2,
        sampleRate: 44100,
        channelData: [
          Float32List.fromList([0.0, 0.5, 1.0]),
          Float32List.fromList([1.0, 0.5, 0.0]),
        ],
      );

      final interleaved = buffer.toInterleaved();
      expect(interleaved, [0.0, 1.0, 0.5, 0.5, 1.0, 0.0]);

      final restored = PcmAudioBuffer.fromInterleaved(interleaved, 2, 44100);
      expect(restored.length, 3);
      expect(restored.getChannelData(0), buffer.getChannelData(0));
      expect(restored.getChannelData(1), buffer.getChannelData(1));
    });
  });

  group('SpeedProcessor', () {
    test('speed 1.0 returns same buffer reference', () {
      final buffer = PcmAudioBuffer(
        channels: 2,
        sampleRate: 44100,
        channelData: [
          Float32List.fromList([0.1, 0.2]),
          Float32List.fromList([0.3, 0.4]),
        ],
      );

      expect(
        identical(
          SpeedProcessor.process(buffer, speed: 1.0, pitchSemitones: 0),
          buffer,
        ),
        isTrue,
      );
    });

    test('speed 2.0 shortens buffer on Android', () {
      if (!Platform.isAndroid) return;
      final frames = 1024;
      final left = Float32List(frames);
      final right = Float32List(frames);
      for (var i = 0; i < frames; i++) {
        left[i] = (i / frames) * 0.8;
        right[i] = ((frames - i) / frames) * 0.8;
      }

      final input = PcmAudioBuffer(
        channels: 2,
        sampleRate: 44100,
        channelData: [left, right],
      );

      final output = SpeedProcessor.process(
        input,
        speed: 2.0,
        pitchSemitones: 0,
      );

      expect(output.length, closeTo(frames ~/ 2, 8));
    });
  });

  group('StretchFfi Android', () {
    test('testConnection returns project signature', () {
      if (!Platform.isAndroid) return;

      expect(StretchFfi.testConnection(), 20260815);
    });

    test('processes a short stereo buffer at 2x speed', () {
      if (!Platform.isAndroid) return;

      final processor = StretchFfi.create(channels: 2, sampleRate: 44100);
      try {
        const inputFrames = 4096;
        const channels = 2;
        const speed = 2.0;
        final outputFrames = inputFrames ~/ speed;
        final input = Float32List(inputFrames * channels);
        for (var frame = 0; frame < inputFrames; frame++) {
          final sample = (frame / inputFrames) * 0.5;
          input[frame * channels] = sample;
          input[frame * channels + 1] = sample;
        }

        final output = StretchFfi.process(
          processor: processor,
          input: input,
          inputFrames: inputFrames,
          outputFrames: outputFrames,
          channels: channels,
          speed: speed,
          pitchSemitones: 0,
        );

        expect(output.length, outputFrames * channels);
      } finally {
        StretchFfi.destroy(processor);
      }
    });
  });
}
