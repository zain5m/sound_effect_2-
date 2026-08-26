import 'dart:io';
import 'dart:math' as math;

import '../models/pcm_audio_buffer.dart';
import '../services/resampler.dart';
import 'high_quality_audio_processor.dart';

/// High-level speed/pitch processor.
///
/// Speed and pitch combinations that are equivalent to plain varispeed playback
/// are resampled (artifact-free on every platform); everything else goes through
/// Signalsmith Stretch via FFI on Android.
class SpeedProcessor {
  SpeedProcessor._();

  /// How far the requested pitch may sit from the varispeed pitch before the
  /// resampling shortcut is rejected. 5 cents is below the audible threshold.
  static const double _varispeedToleranceCents = 5;

  static bool get isNativeAvailable => Platform.isAndroid;

  static bool isVarispeed(double speed, int pitchSemitones) {
    if (speed <= 0) return false;
    final varispeedSemitones = 12 * (math.log(speed) / math.ln2);
    return ((varispeedSemitones - pitchSemitones) * 100).abs() <
        _varispeedToleranceCents;
  }

  static PcmAudioBuffer process(
    PcmAudioBuffer input, {
    required double speed,
    required int pitchSemitones,
    bool preserveFormants = true,
  }) {
    if (speed == 1.0 && pitchSemitones == 0) {
      return input;
    }

    if (isVarispeed(speed, pitchSemitones)) {
      return VarispeedResampler.resample(input, speed);
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
      preserveFormants: preserveFormants,
    );
    if (processed == null) {
      throw StateError('تعذر تشغيل محرك Signalsmith للملف الصوتي الحالي.');
    }
    return processed;
  }
}
