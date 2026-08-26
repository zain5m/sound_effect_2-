import 'dart:math' as math;

import '../models/audio_segment.dart';
import '../models/pcm_audio_buffer.dart';
import '../models/split_settings.dart';

class SilenceAnalysisResult {
  SilenceAnalysisResult({
    required this.silenceRanges,
    required this.segmentRanges,
    required this.segments,
  });

  final List<SilenceRange> silenceRanges;
  final List<SegmentRange> segmentRanges;
  final List<AudioSegment> segments;
}

class SilenceDetector {
  SilenceAnalysisResult analyze(
    PcmAudioBuffer audioBuffer,
    SplitSettings settings,
  ) {
    final ampThreshold = settings.threshold;
    final minSilenceDuration = settings.minSilence;
    final windowMs = settings.windowMs;
    final sampleRate = audioBuffer.sampleRate;
    final data = audioBuffer.getChannelData(0);
    final totalSamples = data.length;
    final windowSamples = (sampleRate * windowMs / 1000).floor();
    final minSilenceSamples = (minSilenceDuration * sampleRate).floor();

    final windowMaxAbs = <double>[];
    final numWindows = (totalSamples / windowSamples).ceil();
    for (var w = 0; w < numWindows; w++) {
      final startIdx = w * windowSamples;
      final endIdx = startIdx + windowSamples < totalSamples
          ? startIdx + windowSamples
          : totalSamples;
      var maxAbs = 0.0;
      for (var i = startIdx; i < endIdx; i++) {
        final abs = data[i].abs();
        if (abs > maxAbs) maxAbs = abs;
      }
      windowMaxAbs.add(maxAbs);
    }

    final isWindowSilent = windowMaxAbs
        .map((maxAbs) => maxAbs < ampThreshold)
        .toList();
    final silenceRanges = <SilenceRange>[];
    var silentStartWindow = -1;

    for (var w = 0; w < numWindows; w++) {
      if (isWindowSilent[w] && silentStartWindow == -1) {
        silentStartWindow = w;
      } else if (!isWindowSilent[w] && silentStartWindow != -1) {
        final silentDurationSamples = (w - silentStartWindow) * windowSamples;
        if (silentDurationSamples >= minSilenceSamples) {
          silenceRanges.add(
            SilenceRange(
              silentStartWindow * windowSamples / sampleRate,
              w * windowSamples / sampleRate,
            ),
          );
        }
        silentStartWindow = -1;
      }
    }

    if (silentStartWindow != -1) {
      final silentDurationSamples =
          (numWindows - silentStartWindow) * windowSamples;
      if (silentDurationSamples >= minSilenceSamples) {
        silenceRanges.add(
          SilenceRange(
            silentStartWindow * windowSamples / sampleRate,
            audioBuffer.duration,
          ),
        );
      }
    }

    final segmentRanges = <SegmentRange>[];
    var currentPos = 0.0;
    for (final range in silenceRanges) {
      if (range.start - currentPos > 0.05) {
        segmentRanges.add(SegmentRange(start: currentPos, end: range.start));
      }
      currentPos = range.end;
    }
    if (currentPos < audioBuffer.duration - 0.05) {
      segmentRanges.add(
        SegmentRange(start: currentPos, end: audioBuffer.duration),
      );
    }

    final segments = <AudioSegment>[];
    for (var i = 0; i < segmentRanges.length; i++) {
      final range = segmentRanges[i];
      final startSample = (range.start * sampleRate).floor();
      final endSample = (range.end * sampleRate).floor() < totalSamples
          ? (range.end * sampleRate).floor()
          : totalSamples;
      final length = endSample - startSample;
      if (length <= 0) continue;

      segments.add(
        AudioSegment(
          index: i + 1,
          buffer: audioBuffer.slice(startSample, endSample),
          startTime: range.start,
          endTime: range.end,
          startSample: startSample,
          endSample: endSample,
        ),
      );
    }

    return SilenceAnalysisResult(
      silenceRanges: silenceRanges,
      segmentRanges: segmentRanges,
      segments: segments,
    );
  }

  SilenceAnalysisResult analyzeV2(PcmAudioBuffer audioBuffer) {
    // =========================
    // Hardcoded Settings
    // =========================

    const double thresholdDb = -45.0;

    // Hysteresis
    const double startThresholdDb = -42.0;
    const double endThresholdDb = -45.0;

    // Analysis
    const int windowMs = 20;
    const int minSilenceMs = 300;

    // Segment cleanup
    const int paddingMs = 80;
    const int minSegmentMs = 100;

    final sampleRate = audioBuffer.sampleRate;

    final left = audioBuffer.getChannelData(0);

    final right = audioBuffer.channels > 1
        ? audioBuffer.getChannelData(1)
        : left;

    final totalSamples = left.length;

    final windowSamples = math.max(1, sampleRate * windowMs ~/ 1000);

    final minSilenceSamples = sampleRate * minSilenceMs ~/ 1000;

    final paddingSamples = sampleRate * paddingMs ~/ 1000;

    final minSegmentSamples = sampleRate * minSegmentMs ~/ 1000;
    // =========================
    // Calculate RMS + dB لكل نافذة
    // =========================

    final windowDb = <double>[];

    final numWindows = (totalSamples / windowSamples).ceil();

    for (var w = 0; w < numWindows; w++) {
      final start = w * windowSamples;
      final end = math.min(start + windowSamples, totalSamples);

      double sumSquares = 0;

      for (var i = start; i < end; i++) {
        final mono = (left[i] + right[i]) * 0.5;
        sumSquares += mono * mono;
      }

      final count = end - start;

      final rms = count == 0 ? 0.0 : math.sqrt(sumSquares / count);

      final db = rms <= 1e-12 ? -120.0 : 20 * math.log(rms) / math.ln10;

      windowDb.add(db);
    }

    // =========================
    // Hysteresis Detection
    // =========================

    final isWindowSilent = List<bool>.filled(numWindows, false);

    bool silent = true;

    for (var i = 0; i < numWindows; i++) {
      final db = windowDb[i];

      if (silent) {
        if (db > startThresholdDb) {
          silent = false;
        }
      } else {
        if (db < endThresholdDb) {
          silent = true;
        }
      }

      isWindowSilent[i] = silent;
    }

    // =========================
    // Merge silent windows
    // =========================

    final silenceRanges = <SilenceRange>[];

    int? silenceStart;

    for (var i = 0; i < numWindows; i++) {
      if (isWindowSilent[i]) {
        silenceStart ??= i;
      } else {
        if (silenceStart != null) {
          final samples = (i - silenceStart) * windowSamples;

          if (samples >= minSilenceSamples) {
            silenceRanges.add(
              SilenceRange(
                silenceStart * windowSamples / sampleRate,
                i * windowSamples / sampleRate,
              ),
            );
          }

          silenceStart = null;
        }
      }
    }

    if (silenceStart != null) {
      final samples = (numWindows - silenceStart) * windowSamples;

      if (samples >= minSilenceSamples) {
        silenceRanges.add(
          SilenceRange(
            silenceStart * windowSamples / sampleRate,
            audioBuffer.duration,
          ),
        );
      }
    }
    // =========================
    // Build segment ranges
    // =========================

    const double paddingSeconds = paddingMs / 1000.0;

    final segmentRanges = <SegmentRange>[];

    double currentStart = 0;

    for (final silence in silenceRanges) {
      final silenceLength = silence.end - silence.start;

      final usablePadding = math.min(paddingSeconds, silenceLength * 0.45);

      final segmentEnd = silence.start + usablePadding;

      if (segmentEnd > currentStart) {
        segmentRanges.add(SegmentRange(start: currentStart, end: segmentEnd));
      }

      currentStart = silence.end - usablePadding;
    }

    if (currentStart < audioBuffer.duration) {
      segmentRanges.add(
        SegmentRange(start: currentStart, end: audioBuffer.duration),
      );
    }

    // =========================
    // Merge overlapping segments
    // =========================

    final merged = <SegmentRange>[];

    for (final seg in segmentRanges) {
      if (merged.isEmpty) {
        merged.add(seg);
        continue;
      }

      final last = merged.last;

      if (seg.start <= last.end) {
        merged[merged.length - 1] = SegmentRange(
          start: last.start,
          end: math.max(last.end, seg.end),
        );
      } else {
        merged.add(seg);
      }
    }

    segmentRanges
      ..clear()
      ..addAll(merged);

    // =========================
    // Remove very short segments
    // =========================

    segmentRanges.removeWhere(
      (segment) => (segment.end - segment.start) < (minSegmentMs / 1000.0),
    );
    // // =========================
    // // Build segment ranges
    // // =========================
    //
    // final segmentRanges = <SegmentRange>[];
    //
    // double currentStart = 0;
    //
    // for (final silence in silenceRanges) {
    //   var end = silence.start;
    //
    //   end += paddingMs / 1000.0;
    //
    //   if (end > audioBuffer.duration) {
    //     end = audioBuffer.duration;
    //   }
    //
    //   if (end > currentStart) {
    //     segmentRanges.add(SegmentRange(start: currentStart, end: end));
    //   }
    //
    //   currentStart = silence.end - paddingMs / 1000.0;
    //
    //   if (currentStart < 0) {
    //     currentStart = 0;
    //   }
    // }
    //
    // if (currentStart < audioBuffer.duration) {
    //   segmentRanges.add(
    //     SegmentRange(start: currentStart, end: audioBuffer.duration),
    //   );
    // }
    //
    // // =========================
    // // Remove very short segments
    // // =========================
    //
    // segmentRanges.removeWhere(
    //   (segment) => (segment.end - segment.start) < (minSegmentMs / 1000.0),
    // );

    // =========================
    // Build AudioSegments
    // =========================

    final segments = <AudioSegment>[];

    for (var i = 0; i < segmentRanges.length; i++) {
      final range = segmentRanges[i];

      int startSample = (range.start * sampleRate).round();

      int endSample = (range.end * sampleRate).round();

      startSample = math.max(0, startSample);

      endSample = math.min(totalSamples, endSample);

      if (endSample <= startSample) {
        continue;
      }

      segments.add(
        AudioSegment(
          index: i + 1,
          buffer: audioBuffer.slice(startSample, endSample),
          startTime: startSample / sampleRate,
          endTime: endSample / sampleRate,
          startSample: startSample,
          endSample: endSample,
        ),
      );
    }

    return SilenceAnalysisResult(
      silenceRanges: silenceRanges,
      segmentRanges: segmentRanges,
      segments: segments,
    );
  }
}
