import 'dart:typed_data';

import 'fifo_sample_buffer.dart';
import 'pcm_buffer_source.dart';
import 'sound_touch.dart';

class FilterSupport {
  FilterSupport(this._pipe);

  final SoundTouch _pipe;

  SoundTouch get pipe => _pipe;
  FifoSampleBuffer get inputBuffer => _pipe.inputBuffer;
  FifoSampleBuffer get outputBuffer => _pipe.outputBuffer;

  void fillInputBuffer(int numFrames) {
    throw UnimplementedError('fillInputBuffer() not overridden');
  }

  void fillOutputBuffer(int numFrames) {
    while (outputBuffer.frameCount < numFrames) {
      final numInputFrames = 8192 * 2 - inputBuffer.frameCount;
      fillInputBuffer(numInputFrames);
      if (inputBuffer.frameCount < 8192 * 2) break;
      _pipe.process();
    }
  }

  void clear() => _pipe.clear();
}

class SimpleFilter extends FilterSupport {
  SimpleFilter(this.sourceSound, SoundTouch pipe, [void Function()? callback])
    : super(pipe) {
    this.callback = callback;
    historyBufferSize = 22050;
    _sourcePosition = 0;
    outputBufferPosition = 0;
    _position = 0;
  }

  void Function()? callback;
  PcmBufferSource sourceSound;
  int historyBufferSize = 22050;
  int _sourcePosition = 0;
  int outputBufferPosition = 0;
  int _position = 0;

  int get position => _position;

  set position(int value) {
    if (value > _position) {
      throw RangeError('New position may not be greater than current position');
    }
    final newOutputBufferPosition = outputBufferPosition - (_position - value);
    if (newOutputBufferPosition < 0) {
      throw RangeError('New position falls outside of history buffer');
    }
    outputBufferPosition = newOutputBufferPosition;
    _position = value;
  }

  int get sourcePosition => _sourcePosition;

  set sourcePosition(int value) {
    clear();
    _sourcePosition = value;
  }

  void onEnd() => callback?.call();

  @override
  void fillOutputBuffer(int numFrames) {
    while (outputBuffer.frameCount < numFrames) {
      final previousOutputFrames = outputBuffer.frameCount;
      final previousSourcePosition = _sourcePosition;
      final numInputFrames = 8192 * 2 - inputBuffer.frameCount;
      fillInputBuffer(numInputFrames);
      final gotMoreSource = _sourcePosition > previousSourcePosition;

      if (inputBuffer.frameCount >= 8192 * 2 ||
          (!gotMoreSource && inputBuffer.frameCount > 0)) {
        pipe.process();
      }

      if (outputBuffer.frameCount == previousOutputFrames && !gotMoreSource) {
        break;
      }
    }
  }

  @override
  void fillInputBuffer(int numFrames) {
    final samples = Float32List(numFrames * 2);
    final numFramesExtracted = sourceSound.extract(
      samples,
      numFrames,
      _sourcePosition,
    );
    _sourcePosition += numFramesExtracted;
    inputBuffer.putSamples(samples, 0, numFramesExtracted);
  }

  int extract(Float32List target, int numFrames) {
    fillOutputBuffer(outputBufferPosition + numFrames);
    final numFramesExtracted =
        numFrames < outputBuffer.frameCount - outputBufferPosition
        ? numFrames
        : outputBuffer.frameCount - outputBufferPosition;
    outputBuffer.extract(target, outputBufferPosition, numFramesExtracted);
    final currentFrames = outputBufferPosition + numFramesExtracted;
    outputBufferPosition = currentFrames < historyBufferSize
        ? currentFrames
        : historyBufferSize;
    outputBuffer.receive(
      currentFrames > historyBufferSize ? currentFrames - historyBufferSize : 0,
    );
    _position += numFramesExtracted;
    return numFramesExtracted;
  }

  @override
  void clear() {
    super.clear();
    outputBufferPosition = 0;
  }
}
