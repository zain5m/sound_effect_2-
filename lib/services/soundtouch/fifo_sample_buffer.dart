import 'dart:typed_data';

class FifoSampleBuffer {
  Float32List _vector = Float32List(0);
  int _position = 0;
  int _frameCount = 0;

  Float32List get vector => _vector;
  int get position => _position;
  int get startIndex => _position * 2;
  int get frameCount => _frameCount;
  int get endIndex => (_position + _frameCount) * 2;

  void clear() {
    _vector.fillRange(0, _vector.length, 0);
    _position = 0;
    _frameCount = 0;
  }

  void put(int numFrames) {
    _frameCount += numFrames;
  }

  void putSamples(Float32List samples, [int position = 0, int numFrames = -1]) {
    final sourceOffset = position * 2;
    if (numFrames < 0) {
      numFrames = (samples.length - sourceOffset) ~/ 2;
    }
    final numSamples = numFrames * 2;
    ensureCapacity(numFrames + _frameCount);
    final destOffset = endIndex;
    _vector.setRange(
      destOffset,
      destOffset + numSamples,
      samples,
      sourceOffset,
    );
    _frameCount += numFrames;
  }

  void putBuffer(
    FifoSampleBuffer buffer, [
    int position = 0,
    int numFrames = -1,
  ]) {
    if (numFrames < 0) numFrames = buffer.frameCount - position;
    putSamples(buffer.vector, buffer.position + position, numFrames);
  }

  void receive([int numFrames = -1]) {
    if (numFrames < 0 || numFrames > _frameCount) numFrames = frameCount;
    _frameCount -= numFrames;
    _position += numFrames;
  }

  void receiveSamples(Float32List output, [int numFrames = 0]) {
    final numSamples = numFrames * 2;
    final sourceOffset = startIndex;
    output.setRange(0, numSamples, _vector, sourceOffset);
    receive(numFrames);
  }

  void extract(Float32List output, [int position = 0, int numFrames = 0]) {
    final sourceOffset = startIndex + position * 2;
    final numSamples = numFrames * 2;
    output.setRange(0, numSamples, _vector, sourceOffset);
  }

  void ensureCapacity([int numFrames = 0]) {
    final minLength = numFrames * 2;
    if (_vector.length < minLength) {
      final newVector = Float32List(minLength);
      newVector.setRange(0, endIndex - startIndex, _vector, startIndex);
      _vector = newVector;
      _position = 0;
    } else {
      rewind();
    }
  }

  void ensureAdditionalCapacity([int numFrames = 0]) {
    ensureCapacity(_frameCount + numFrames);
  }

  void rewind() {
    if (_position > 0) {
      _vector.setRange(0, endIndex - startIndex, _vector, startIndex);
      _position = 0;
    }
  }
}
