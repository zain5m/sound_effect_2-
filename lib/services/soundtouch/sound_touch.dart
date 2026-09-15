import 'dart:math' as math;

import 'fifo_sample_buffer.dart';
import 'rate_transposer.dart';
import 'stretch.dart';

bool _testFloatEqual(double a, double b) {
  return (a > b ? a - b : b - a) > 1e-10;
}

class SoundTouch {
  SoundTouch() {
    transposer = RateTransposer(false);
    stretch = Stretch(false);
    _inputBuffer = FifoSampleBuffer();
    _intermediateBuffer = FifoSampleBuffer();
    _outputBuffer = FifoSampleBuffer();
    _rate = 0;
    _tempo = 0;
    virtualPitch = 1.0;
    virtualRate = 1.0;
    virtualTempo = 1.0;
    calculateEffectiveRateAndTempo();
  }

  late RateTransposer transposer;
  late Stretch stretch;
  late FifoSampleBuffer _inputBuffer;
  late FifoSampleBuffer _intermediateBuffer;
  late FifoSampleBuffer _outputBuffer;
  double _rate = 0;
  double _tempo = 0;
  double virtualPitch = 1.0;
  double virtualRate = 1.0;
  double virtualTempo = 1.0;

  void clear() {
    transposer.clear();
    stretch.clear();
  }

  SoundTouch cloneSoundTouch() {
    final result = SoundTouch();
    result.rate = rate;
    result.tempo = tempo;
    return result;
  }

  double get rate => _rate;
  set rate(double value) {
    virtualRate = value;
    calculateEffectiveRateAndTempo();
  }

  set rateChange(double rateChange) {
    _rate = 1.0 + 0.01 * rateChange;
  }

  double get tempo => _tempo;
  set tempo(double value) {
    virtualTempo = value;
    calculateEffectiveRateAndTempo();
  }

  set tempoChange(double tempoChange) {
    tempo = 1.0 + 0.01 * tempoChange;
  }

  set pitch(double value) {
    virtualPitch = value;
    calculateEffectiveRateAndTempo();
  }

  set pitchOctaves(double pitchOctaves) {
    pitch = math.exp(0.69314718056 * pitchOctaves);
  }

  set pitchSemitones(double pitchSemitones) {
    pitchOctaves = pitchSemitones / 12.0;
  }

  FifoSampleBuffer get inputBuffer => _inputBuffer;
  FifoSampleBuffer get outputBuffer => _outputBuffer;

  void calculateEffectiveRateAndTempo() {
    final previousTempo = _tempo;
    final previousRate = _rate;
    _tempo = virtualTempo / virtualPitch;
    _rate = virtualRate * virtualPitch;
    if (_testFloatEqual(_tempo, previousTempo)) stretch.tempo = _tempo;
    if (_testFloatEqual(_rate, previousRate)) transposer.rate = _rate;
    _wireBuffers();
  }

  void _wireBuffers() {
    if (_rate > 1.0) {
      stretch.inputBuffer = _inputBuffer;
      stretch.outputBuffer = _intermediateBuffer;
      transposer.inputBuffer = _intermediateBuffer;
      transposer.outputBuffer = _outputBuffer;
    } else {
      transposer.inputBuffer = _inputBuffer;
      transposer.outputBuffer = _intermediateBuffer;
      stretch.inputBuffer = _intermediateBuffer;
      stretch.outputBuffer = _outputBuffer;
    }
  }

  void process() {
    if (_rate > 1.0) {
      stretch.process();
      transposer.process();
    } else {
      transposer.process();
      stretch.process();
    }
  }
}
