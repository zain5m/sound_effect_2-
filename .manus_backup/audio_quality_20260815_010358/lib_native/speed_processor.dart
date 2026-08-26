import  'dart:ffi';
import 'dart:typed_data';

import 'stretch_ffi.dart';

class SpeedProcessor {
  SpeedProcessor._();

  static final Pointer<Void> _processor = StretchFfi.create(
    channels: 2,
    sampleRate: 44100,
  );

  static Float32List process({
    required Float32List input,
    required int inputFrames,
    required double speed,
  }) {
    if (speed == 1.0) {
      return input;
    }

    final outputFrames = (inputFrames / speed).ceil();

    return StretchFfi.process(
      processor: _processor,
      input: input,
      inputFrames: inputFrames,
      outputFrames: outputFrames,
      speed: speed,
    );
  }

  static void dispose() {
    StretchFfi.destroy(_processor);
  }
}
