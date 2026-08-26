import 'dart:io';

import '../models/pcm_audio_buffer.dart';
import 'high_quality_audio_processor.dart';

/// High-level speed/pitch processor. Android uses Signalsmith Stretch via FFI.
class SpeedProcessor {
  SpeedProcessor._();

  static bool get isNativeAvailable => Platform.isAndroid;

  static PcmAudioBuffer process(
    PcmAudioBuffer input, {
    required double speed,
    required int pitchSemitones,
  }) {
    if (speed == 1.0 && pitchSemitones == 0) {
      return input;
    }

    if (!isNativeAvailable) {
      throw UnsupportedError(
        'تعديل السرعة والنبرة متاح حالياً على Android فقط عبر محرك Signalsmith.',
      );
    }

    final processed = HighQualityAudioProcessor.tryProcess(
      input,
      speed: speed,
      pitchSemitones: pitchSemitones,
    );
    if (processed == null) {
      throw StateError('تعذر تشغيل محرك Signalsmith للملف الصوتي الحالي.');
    }
    return processed;
  }
}
