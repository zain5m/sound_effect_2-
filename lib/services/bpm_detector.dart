import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/pcm_audio_buffer.dart';

class BpmDetector {
  Future<int?> detect(PcmAudioBuffer buffer) async {
    if (buffer.sampleRate <= 0 || buffer.channelData.isEmpty) return null;

    final length = math.min(buffer.length, buffer.sampleRate * 90);
    if ((length - 512) ~/ 512 < 8) return null;

    // Copy only the analysis window, not a view retaining the entire file.
    final left = Float32List.fromList(
      Float32List.sublistView(buffer.getChannelData(0), 0, length),
    );
    final right = buffer.channels > 1
        ? Float32List.fromList(
            Float32List.sublistView(buffer.getChannelData(1), 0, length),
          )
        : null;
    return _detectInBackground(left, right, buffer.sampleRate);
  }
}

// Keep the isolate closure separate so it cannot capture the full PCM buffer.
Future<int?> _detectInBackground(
  Float32List left,
  Float32List? right,
  int sampleRate,
) {
  return Isolate.run(() => _detectBpm(left, right, sampleRate));
}

int? _detectBpm(Float32List left, Float32List? right, int sampleRate) {
  final mono = right == null ? left : Float32List(left.length);
  if (right != null) {
    for (var i = 0; i < mono.length; i++) {
      mono[i] = (left[i] + right[i]) * 0.5;
    }
  }

  const hop = 512;
  final frames = (mono.length - hop) ~/ hop;
  if (frames < 8) return null;

  final envelope = Float32List(frames);
  for (var i = 0; i < frames; i++) {
    var sum = 0.0;
    final start = i * hop;
    for (var j = 0; j < hop; j++) {
      final sample = mono[start + j];
      sum += sample * sample;
    }
    envelope[i] = math.sqrt(sum / hop);
  }

  final novelty = Float32List(frames);
  for (var i = 1; i < frames; i++) {
    final difference = envelope[i] - envelope[i - 1];
    novelty[i] = difference > 0 ? difference : 0;
  }

  final frameRate = sampleRate / hop;
  final lagMin = math.max(1, (frameRate * 60 / 200).floor());
  final lagMax = math.min(frames - 1, (frameRate * 60 / 60).ceil());
  var bestLag = lagMin;
  var bestValue = double.negativeInfinity;
  for (var lag = lagMin; lag <= lagMax; lag++) {
    var sum = 0.0;
    for (var i = 0; i + lag < frames; i++) {
      sum += novelty[i] * novelty[i + lag];
    }
    if (sum > bestValue) {
      bestValue = sum;
      bestLag = lag;
    }
  }
  if (!bestValue.isFinite || bestValue <= 0) return null;

  var bpm = 60 * frameRate / bestLag;
  while (bpm < 70) {
    bpm *= 2;
  }
  while (bpm > 180) {
    bpm /= 2;
  }
  return bpm.round();
}
