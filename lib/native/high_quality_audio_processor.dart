import 'dart:ffi';

import '../models/pcm_audio_buffer.dart';
import 'stretch_ffi.dart';

/// Android offline DSP backed by Signalsmith Stretch (presetDefault + exact()).
class HighQualityAudioProcessor {
  HighQualityAudioProcessor._();

  static PcmAudioBuffer? tryProcess(
    PcmAudioBuffer input, {
    required double speed,
    required int pitchSemitones,
    bool preserveFormants = true,
  }) {
    if (input.length == 0 || input.channels < 1 || input.channels > 8) {
      return null;
    }
    if (speed <= 0 || speed < 0.25 || speed > 4.0) {
      throw ArgumentError.value(
        speed,
        'speed',
        'السرعة المدعومة هي بين 0.25x و4x.',
      );
    }
    if (pitchSemitones < -24 || pitchSemitones > 24) {
      throw ArgumentError.value(
        pitchSemitones,
        'pitchSemitones',
        'النبرة المدعومة هي بين -24 و+24 نصف نغمة.',
      );
    }

    Pointer<Void>? processor;
    try {
      processor = StretchFfi.create(
        channels: input.channels,
        sampleRate: input.sampleRate,
      );

      final interleaved = input.toInterleaved();
      final outputFrames = (input.length / speed).round().clamp(1, 1 << 30);
      final processed = StretchFfi.process(
        processor: processor,
        input: interleaved,
        inputFrames: input.length,
        outputFrames: outputFrames,
        channels: input.channels,
        speed: speed,
        pitchSemitones: pitchSemitones.toDouble(),
        preserveFormants: preserveFormants,
      );

      return PcmAudioBuffer.fromInterleaved(
        processed,
        input.channels,
        input.sampleRate,
      );
    } finally {
      if (processor != null) {
        StretchFfi.destroy(processor);
      }
    }
  }
}
