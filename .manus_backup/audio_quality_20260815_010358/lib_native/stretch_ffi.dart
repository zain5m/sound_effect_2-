import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart';

class StretchFfi {
  StretchFfi._();

  static int testConnection() {
    return stretchTestConnection();
  }

  static Pointer<Void> create({
    required int channels,
    required int sampleRate,
  }) {
    return stretchCreate(channels, sampleRate);
  }

  static void destroy(Pointer<Void> processor) {
    stretchDestroy(processor);
  }

  static int reset(Pointer<Void> processor) {
    return stretchReset(processor);
  }

  static Float32List process({
    required Pointer<Void> processor,
    required Float32List input,
    required int inputFrames,
    required int outputFrames,
    required double speed,
  }) {
    final inputPtr = calloc<Float>(input.length);
    inputPtr.asTypedList(input.length).setAll(0, input);

    final outputPtr = calloc<Float>(outputFrames * 2);

    final result = stretchProcess(
      processor,
      inputPtr,
      inputFrames,
      outputPtr,
      outputFrames,
      speed,
    );

    if (result != 0) {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
      throw Exception('stretch_process failed: $result');
    }

    final output = Float32List.fromList(
      outputPtr.asTypedList(outputFrames * 2),
    );

    calloc.free(inputPtr);
    calloc.free(outputPtr);

    return output;
  }
}
