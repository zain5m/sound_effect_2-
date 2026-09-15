import 'fifo_sample_buffer.dart';

class AbstractFifoSamplePipe {
  AbstractFifoSamplePipe(bool createBuffers) {
    if (createBuffers) {
      _inputBuffer = FifoSampleBuffer();
      _outputBuffer = FifoSampleBuffer();
    }
  }

  FifoSampleBuffer? _inputBuffer;
  FifoSampleBuffer? _outputBuffer;

  FifoSampleBuffer get inputBuffer {
    final buffer = _inputBuffer;
    if (buffer == null) {
      throw StateError('inputBuffer is not assigned');
    }
    return buffer;
  }

  set inputBuffer(FifoSampleBuffer value) => _inputBuffer = value;

  FifoSampleBuffer get outputBuffer {
    final buffer = _outputBuffer;
    if (buffer == null) {
      throw StateError('outputBuffer is not assigned');
    }
    return buffer;
  }

  set outputBuffer(FifoSampleBuffer value) => _outputBuffer = value;

  void clear() {
    _inputBuffer?.clear();
    _outputBuffer?.clear();
  }
}
