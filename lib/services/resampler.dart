import 'dart:math' as math;
import 'dart:typed_data';

import '../models/pcm_audio_buffer.dart';

/// Band-limited varispeed resampler (windowed-sinc, polyphase table).
///
/// Playing a buffer back at a different rate changes duration and pitch by the
/// same factor. When the requested speed/pitch pair matches that relationship
/// this is a bit-transparent alternative to phase-vocoder time stretching: it
/// has no smearing, no phasiness and no transient doubling.
class VarispeedResampler {
  VarispeedResampler._();

  /// Half the number of taps of the prototype filter at full bandwidth.
  static const int _halfTaps = 16;

  /// Sub-sample resolution of the polyphase table.
  static const int _phaseCount = 512;

  /// Kaiser window beta, ~-90 dB stopband.
  static const double _kaiserBeta = 8.6;

  /// Ratio of input frames consumed per output frame.
  ///
  /// `ratio > 1` shortens the buffer and raises the pitch.
  static PcmAudioBuffer resample(PcmAudioBuffer input, double ratio) {
    if (!ratio.isFinite || ratio <= 0) {
      throw ArgumentError.value(
        ratio,
        'ratio',
        'نسبة إعادة التشكيل غير صالحة.',
      );
    }
    if (ratio == 1.0 || input.length == 0) {
      return input;
    }

    // Speeding up folds content above the new Nyquist back into the audible
    // band, so the interpolation filter doubles as an anti-aliasing filter.
    final cutoff = ratio > 1 ? 0.98 / ratio : 1.0;
    final table = _PolyphaseTable.build(cutoff);

    final outputFrames = math.max(1, (input.length / ratio).round());
    final channelData = List<Float32List>.generate(input.channels, (channel) {
      final source = input.getChannelData(channel);
      final output = Float32List(outputFrames);
      final sourceLength = source.length;

      for (var frame = 0; frame < outputFrames; frame++) {
        final position = frame * ratio;
        final baseIndex = position.floor();
        final fraction = position - baseIndex;

        final phasePosition = fraction * _phaseCount;
        final phase = phasePosition.floor();
        final phaseBlend = phasePosition - phase;
        final lowRow = table.row(phase);
        final highRow = table.row(phase + 1);

        var sum = 0.0;
        for (var tap = 0; tap < table.tapCount; tap++) {
          final sourceIndex = baseIndex + tap - table.tapsPerSide + 1;
          if (sourceIndex < 0) continue;
          if (sourceIndex >= sourceLength) break;
          final weight =
              lowRow[tap] + (highRow[tap] - lowRow[tap]) * phaseBlend;
          sum += source[sourceIndex] * weight;
        }
        output[frame] = sum;
      }
      return output;
    });

    return PcmAudioBuffer(
      channels: input.channels,
      sampleRate: input.sampleRate,
      channelData: channelData,
    );
  }
}

class _PolyphaseTable {
  _PolyphaseTable._(this.tapsPerSide, this._rows);

  final int tapsPerSide;
  final List<Float64List> _rows;

  int get tapCount => tapsPerSide * 2;

  Float64List row(int phase) =>
      _rows[phase < 0 ? 0 : (phase >= _rows.length ? _rows.length - 1 : phase)];

  /// Builds `phaseCount + 1` filter rows; the extra row lets callers blend
  /// linearly between neighbouring phases.
  static _PolyphaseTable build(double cutoff) {
    final tapsPerSide = (VarispeedResampler._halfTaps / cutoff).ceil();
    final rows = <Float64List>[];
    for (var phase = 0; phase <= VarispeedResampler._phaseCount; phase++) {
      final fraction = phase / VarispeedResampler._phaseCount;
      final row = Float64List(tapsPerSide * 2);
      var sum = 0.0;
      for (var tap = 0; tap < row.length; tap++) {
        // Distance from the interpolation point to this input sample.
        final t = (tap - tapsPerSide + 1) - fraction;
        final window = _kaiserWindow(t / tapsPerSide);
        final value = cutoff * _sinc(cutoff * t) * window;
        row[tap] = value;
        sum += value;
      }
      if (sum != 0) {
        for (var tap = 0; tap < row.length; tap++) {
          row[tap] /= sum;
        }
      }
      rows.add(row);
    }
    return _PolyphaseTable._(tapsPerSide, rows);
  }

  static double _sinc(double x) {
    if (x == 0) return 1.0;
    final piX = math.pi * x;
    return math.sin(piX) / piX;
  }

  static double _kaiserWindow(double normalized) {
    if (normalized <= -1 || normalized >= 1) return 0.0;
    final argument =
        VarispeedResampler._kaiserBeta * math.sqrt(1 - normalized * normalized);
    return _besselI0(argument) / _besselI0(VarispeedResampler._kaiserBeta);
  }

  static double _besselI0(double x) {
    var sum = 1.0;
    var term = 1.0;
    for (var i = 1; i < 32; i++) {
      term *= (x / (2 * i)) * (x / (2 * i));
      sum += term;
      if (term < sum * 1e-12) break;
    }
    return sum;
  }
}
