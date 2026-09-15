import 'dart:typed_data';

import 'abstract_fifo_sample_pipe.dart';

const _scanOffsets = [
  [
    124,
    186,
    248,
    310,
    372,
    434,
    496,
    558,
    620,
    682,
    744,
    806,
    868,
    930,
    992,
    1054,
    1116,
    1178,
    1240,
    1302,
    1364,
    1426,
    1488,
    0,
  ],
  [
    -100,
    -75,
    -50,
    -25,
    25,
    50,
    75,
    100,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ],
  [
    -20,
    -15,
    -10,
    -5,
    5,
    10,
    15,
    20,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ],
  [-4, -3, -2, -1, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
];

const _autoSeqK = (50.0 - 125.0) / (4.0 - 0.25);
const _autoSeqC = 125.0 - _autoSeqK * 0.25;
const _autoSeekK = (15.0 - 25.0) / (4.0 - 0.25);
const _autoSeekC = 25.0 - _autoSeekK * 0.25;

class Stretch extends AbstractFifoSamplePipe {
  Stretch([bool createBuffers = true]) : super(createBuffers) {
    _quickSeek = true;
    midBufferDirty = false;
    midBuffer = null;
    overlapLength = 0;
    autoSeqSetting = true;
    autoSeekSetting = true;
    _tempo = 1;
    setParameters(44100, 0, 0, 8);
  }

  bool _quickSeek = true;
  bool midBufferDirty = false;
  Float32List? midBuffer;
  late Float32List refMidBuffer;
  int overlapLength = 0;
  bool autoSeqSetting = true;
  bool autoSeekSetting = true;
  double _tempo = 1;
  int sampleRate = 44100;
  double overlapMs = 8;
  double sequenceMs = 0;
  double seekWindowMs = 0;
  int seekWindowLength = 0;
  int seekLength = 0;
  double nominalSkip = 0;
  double skipFract = 0;
  int sampleReq = 0;

  @override
  void clear() {
    super.clear();
    clearMidBuffer();
  }

  void clearMidBuffer() {
    midBufferDirty = false;
    midBuffer = null;
    refMidBuffer.fillRange(0, refMidBuffer.length, 0);
    skipFract = 0;
  }

  void setParameters(
    int sampleRate,
    double sequenceMs,
    double seekWindowMs,
    double overlapMs,
  ) {
    if (sampleRate > 0) this.sampleRate = sampleRate;
    if (overlapMs > 0) this.overlapMs = overlapMs;
    if (sequenceMs > 0) {
      this.sequenceMs = sequenceMs;
      autoSeqSetting = false;
    } else {
      autoSeqSetting = true;
    }
    if (seekWindowMs > 0) {
      this.seekWindowMs = seekWindowMs;
      autoSeekSetting = false;
    } else {
      autoSeekSetting = true;
    }
    calculateSequenceParameters();
    calculateOverlapLength(this.overlapMs);
    tempo = _tempo;
  }

  set tempo(double newTempo) {
    _tempo = newTempo;
    calculateSequenceParameters();
    nominalSkip = _tempo * (seekWindowLength - overlapLength);
    skipFract = 0;
    final intskip = (nominalSkip + 0.5).floor();
    sampleReq =
        [
          intskip + overlapLength,
          seekWindowLength,
        ].reduce((a, b) => a > b ? a : b) +
        seekLength;
  }

  double get tempo => _tempo;

  int get inputChunkSize => sampleReq;

  int get outputChunkSize =>
      overlapLength +
      (seekWindowLength - 2 * overlapLength).clamp(0, seekWindowLength);

  void calculateOverlapLength([double overlapInMsec = 0]) {
    var newOvl = sampleRate * overlapInMsec / 1000;
    if (newOvl < 16) newOvl = 16;
    newOvl -= newOvl % 8;
    overlapLength = newOvl.floor();
    refMidBuffer = Float32List(overlapLength * 2);
    midBuffer = Float32List(overlapLength * 2);
  }

  double checkLimits(double x, double mi, double ma) {
    if (x < mi) return mi;
    if (x > ma) return ma;
    return x;
  }

  void calculateSequenceParameters() {
    if (autoSeqSetting) {
      var seq = _autoSeqC + _autoSeqK * _tempo;
      seq = checkLimits(seq, 50.0, 125.0);
      sequenceMs = (seq + 0.5).floorToDouble();
    }
    if (autoSeekSetting) {
      var seek = _autoSeekC + _autoSeekK * _tempo;
      seek = checkLimits(seek, 15.0, 25.0);
      seekWindowMs = (seek + 0.5).floorToDouble();
    }
    seekWindowLength = (sampleRate * sequenceMs / 1000).floor();
    seekLength = (sampleRate * seekWindowMs / 1000).floor();
  }

  set quickSeek(bool enable) => _quickSeek = enable;

  Stretch cloneStretch() {
    final result = Stretch();
    result.tempo = _tempo;
    result.setParameters(sampleRate, sequenceMs, seekWindowMs, overlapMs);
    return result;
  }

  int seekBestOverlapPosition() {
    return _quickSeek
        ? seekBestOverlapPositionStereoQuick()
        : seekBestOverlapPositionStereo();
  }

  int seekBestOverlapPositionStereo() {
    var bestOffset = 0;
    var bestCorrelation = double.negativeInfinity;
    preCalculateCorrelationReferenceStereo();
    for (var i = 0; i < seekLength; i++) {
      final correlation = calculateCrossCorrelationStereo(2 * i, refMidBuffer);
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestOffset = i;
      }
    }
    return bestOffset;
  }

  int seekBestOverlapPositionStereoQuick() {
    var bestOffset = 0;
    var bestCorrelation = double.negativeInfinity;
    var correlationOffset = 0;
    preCalculateCorrelationReferenceStereo();
    for (var scanCount = 0; scanCount < 4; scanCount++) {
      var j = 0;
      while (_scanOffsets[scanCount][j] != 0) {
        final tempOffset = correlationOffset + _scanOffsets[scanCount][j];
        if (tempOffset >= seekLength) break;
        final correlation = calculateCrossCorrelationStereo(
          2 * tempOffset,
          refMidBuffer,
        );
        if (correlation > bestCorrelation) {
          bestCorrelation = correlation;
          bestOffset = tempOffset;
        }
        j++;
      }
      correlationOffset = bestOffset;
    }
    return bestOffset;
  }

  void preCalculateCorrelationReferenceStereo() {
    final mid = midBuffer!;
    for (var i = 0; i < overlapLength; i++) {
      final temp = i * (overlapLength - i);
      final context = i * 2;
      refMidBuffer[context] = mid[context] * temp;
      refMidBuffer[context + 1] = mid[context + 1] * temp;
    }
  }

  double calculateCrossCorrelationStereo(
    int mixingPosition,
    Float32List compare,
  ) {
    final mixing = inputBuffer.vector;
    mixingPosition += inputBuffer.startIndex;
    var correlation = 0.0;
    final calcLength = 2 * overlapLength;
    for (var i = 2; i < calcLength; i += 2) {
      final mixingOffset = i + mixingPosition;
      correlation +=
          mixing[mixingOffset] * compare[i] +
          mixing[mixingOffset + 1] * compare[i + 1];
    }
    return correlation;
  }

  void overlap(int overlapPosition) => overlapStereo(2 * overlapPosition);

  void overlapStereo(int inputPosition) {
    final input = inputBuffer.vector;
    inputPosition += inputBuffer.startIndex;
    final output = outputBuffer.vector;
    final outputPosition = outputBuffer.endIndex;
    final frameScale = 1 / overlapLength;
    final mid = midBuffer!;

    for (var i = 0; i < overlapLength; i++) {
      final tempFrame = (overlapLength - i) * frameScale;
      final fi = i * frameScale;
      final context = 2 * i;
      final inputOffset = context + inputPosition;
      final outputOffset = context + outputPosition;
      output[outputOffset] = input[inputOffset] * fi + mid[context] * tempFrame;
      output[outputOffset + 1] =
          input[inputOffset + 1] * fi + mid[context + 1] * tempFrame;
    }
  }

  void process() {
    if (midBuffer == null) {
      if (inputBuffer.frameCount < overlapLength) return;
      midBuffer = Float32List(overlapLength * 2);
      inputBuffer.receiveSamples(midBuffer!, overlapLength);
    }

    while (inputBuffer.frameCount >= sampleReq) {
      final offset = seekBestOverlapPosition();
      outputBuffer.ensureAdditionalCapacity(overlapLength);
      overlap(offset);
      outputBuffer.put(overlapLength);
      final temp = seekWindowLength - 2 * overlapLength;
      if (temp > 0) {
        outputBuffer.putBuffer(inputBuffer, offset + overlapLength, temp);
      }
      final start =
          inputBuffer.startIndex +
          2 * (offset + seekWindowLength - overlapLength);
      midBuffer!.setRange(0, 2 * overlapLength, inputBuffer.vector, start);
      skipFract += nominalSkip;
      final overlapSkip = skipFract.floor();
      skipFract -= overlapSkip;
      inputBuffer.receive(overlapSkip);
    }
  }
}
