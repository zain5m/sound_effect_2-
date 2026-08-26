import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart';

class StretchFfi {
  StretchFfi._();

  /// Above this frequency the spectrum is shifted instead of scaled, which is
  /// what keeps transposed audio from sounding smeared.
  static const double defaultTonalityLimitHz = 8000;

  static int testConnection() => stretchTestConnection();

  static Pointer<Void> create({
    required int channels,
    required int sampleRate,
  }) {
    final processor = stretchCreate(channels, sampleRate);
    if (processor == nullptr) {
      throw StateError('تعذر إنشاء معالج الصوت Native.');
    }
    return processor;
  }

  static void destroy(Pointer<Void> processor) {
    if (processor != nullptr) {
      stretchDestroy(processor);
    }
  }

  static void reset(Pointer<Void> processor) {
    final result = stretchReset(processor);
    if (result != 0) {
      throw StateError('فشل إعادة تهيئة معالج الصوت Native: $result');
    }
  }

  static Float32List process({
    required Pointer<Void> processor,
    required Float32List input,
    required int inputFrames,
    required int outputFrames,
    required int channels,
    required double speed,
    required double pitchSemitones,
    double tonalityLimitHz = defaultTonalityLimitHz,
    bool preserveFormants = true,
    double formantBaseHz = 0,
  }) {
    if (input.length != inputFrames * channels) {
      throw ArgumentError.value(
        input.length,
        'input',
        'حجم PCM لا يطابق عدد القنوات والإطارات.',
      );
    }

    final inputPtr = calloc<Float>(input.length);
    final outputPtr = calloc<Float>(outputFrames * channels);
    try {
      inputPtr.asTypedList(input.length).setAll(0, input);
      final result = stretchProcessEx(
        processor,
        inputPtr,
        inputFrames,
        outputPtr,
        outputFrames,
        speed,
        pitchSemitones,
        tonalityLimitHz,
        preserveFormants ? 1 : 0,
        formantBaseHz,
      );
      if (result != 0) {
        throw StateError('فشلت معالجة الصوت Native: $result');
      }
      return Float32List.fromList(
        outputPtr.asTypedList(outputFrames * channels),
      );
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
    }
  }
}
