import 'abstract_fifo_sample_pipe.dart';

class RateTransposer extends AbstractFifoSamplePipe {
  RateTransposer([bool createBuffers = true]) : super(createBuffers) {
    reset();
    _rate = 1;
  }

  double _rate = 1;
  double slopeCount = 0;
  double prevSampleL = 0;
  double prevSampleR = 0;

  set rate(double value) => _rate = value;

  void reset() {
    slopeCount = 0;
    prevSampleL = 0;
    prevSampleR = 0;
  }

  @override
  void clear() {
    super.clear();
    reset();
  }

  RateTransposer clone() {
    final result = RateTransposer();
    result.rate = _rate;
    return result;
  }

  void process() {
    final numFrames = inputBuffer.frameCount;
    outputBuffer.ensureAdditionalCapacity((numFrames / _rate).floor() + 1);
    final numFramesOutput = transpose(numFrames);
    inputBuffer.receive();
    outputBuffer.put(numFramesOutput);
  }

  int transpose([int numFrames = 0]) {
    if (numFrames == 0) return 0;
    final src = inputBuffer.vector;
    final srcOffset = inputBuffer.startIndex;
    final dest = outputBuffer.vector;
    final destOffset = outputBuffer.endIndex;
    var used = 0;
    var i = 0;

    while (slopeCount < 1.0) {
      dest[destOffset + 2 * i] =
          (1.0 - slopeCount) * prevSampleL + slopeCount * src[srcOffset];
      dest[destOffset + 2 * i + 1] =
          (1.0 - slopeCount) * prevSampleR + slopeCount * src[srcOffset + 1];
      i++;
      slopeCount += _rate;
    }
    slopeCount -= 1.0;

    if (numFrames != 1) {
      outer:
      while (true) {
        while (slopeCount > 1.0) {
          slopeCount -= 1.0;
          used++;
          if (used >= numFrames - 1) break outer;
        }
        final srcIndex = srcOffset + 2 * used;
        dest[destOffset + 2 * i] =
            (1.0 - slopeCount) * src[srcIndex] + slopeCount * src[srcIndex + 2];
        dest[destOffset + 2 * i + 1] =
            (1.0 - slopeCount) * src[srcIndex + 1] +
            slopeCount * src[srcIndex + 3];
        i++;
        slopeCount += _rate;
      }
    }

    prevSampleL = src[srcOffset + 2 * numFrames - 2];
    prevSampleR = src[srcOffset + 2 * numFrames - 1];
    return i;
  }
}
