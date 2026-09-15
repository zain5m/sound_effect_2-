import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/audio_segment.dart';
import '../models/pcm_audio_buffer.dart';
import '../theme/app_theme.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.buffer,
    required this.threshold,
    this.silenceRanges = const [],
    this.segmentRanges = const [],
    this.showSegments = false,
  });

  final PcmAudioBuffer buffer;
  final double threshold;
  final List<SilenceRange> silenceRanges;
  final List<SegmentRange> segmentRanges;
  final bool showSegments;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final data = buffer.getChannelData(0);
    final duration = buffer.duration;
    final samplesPerPixel = math.max(1, (data.length / width).ceil());

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final threshPaint = Paint()
      ..color = AppColors.waveformCursor.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final threshPixel = threshold * centerY;
    _drawDashedLine(
      canvas,
      Offset(0, centerY - threshPixel),
      Offset(width, centerY - threshPixel),
      threshPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(0, centerY + threshPixel),
      Offset(width, centerY + threshPixel),
      threshPaint,
    );
    for (final range in silenceRanges) {
      final x1 = (range.start / duration) * width;
      final x2 = (range.end / duration) * width;
      canvas.drawRect(
        Rect.fromLTRB(x1, 0, x2, height),
        Paint()..color = AppColors.waveformSilence.withValues(alpha: 0.15),
      );
      canvas.drawRect(
        Rect.fromLTWH(x1, 0, 2, height),
        Paint()..color = AppColors.waveformSilence.withValues(alpha: 0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(x2, 0, 2, height),
        Paint()..color = AppColors.waveformSilence.withValues(alpha: 0.5),
      );
    }

    if (showSegments) {
      for (var i = 0; i < segmentRanges.length; i++) {
        final range = segmentRanges[i];
        final x1 = (range.start / duration) * width;
        final x2 = (range.end / duration) * width;
        canvas.drawRect(
          Rect.fromLTRB(x1, 0, x2, height),
          Paint()
            // ..color = AppColors.waveformColor.withValues(
            ..color = AppColors.waveformStart.withValues(
              alpha: 0.04 + (i % 2) * 0.03,
            ),
        );
      }
    }

    for (var i = 0; i < width.toInt(); i++) {
      final start = i * samplesPerPixel;
      final end = math.min(start + samplesPerPixel, data.length);
      var min = 1.0;
      var max = -1.0;
      for (var j = start; j < end; j++) {
        if (data[j] < min) min = data[j];
        if (data[j] > max) max = data[j];
      }
      final pixelTime = (i / width) * duration;
      final isSilent = silenceRanges.any(
        (r) => pixelTime >= r.start && pixelTime <= r.end,
      );
      final yMin = centerY + min * centerY * 0.95;
      final yMax = centerY + max * centerY * 0.95;
      final barHeight = math.max(1.0, yMax - yMin);

      if (isSilent) {
        canvas.drawRect(
          Rect.fromLTWH(i.toDouble(), centerY - 1, 1, 2),
          Paint()..color = AppColors.waveformSilence.withValues(alpha: 0.6),
        );
      } else {
        final t = i / width;
        final barColor = Color.lerp(
          AppColors.waveformStart,
          AppColors.waveformEnd,
          t,
        )!;
        final paint = Paint()..color = barColor;
        canvas.drawRect(Rect.fromLTWH(i.toDouble(), yMin, 1, barHeight), paint);
      }
    }

    canvas.drawLine(
      Offset(0, centerY),
      Offset(width, centerY),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = (distance / (dashWidth + dashSpace)).floor();
    for (var i = 0; i < steps; i++) {
      final t1 = i * (dashWidth + dashSpace) / distance;
      final t2 = (i * (dashWidth + dashSpace) + dashWidth) / distance;
      canvas.drawLine(
        Offset(start.dx + dx * t1, start.dy + dy * t1),
        Offset(start.dx + dx * t2.clamp(0, 1), start.dy + dy * t2.clamp(0, 1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.buffer != buffer ||
        oldDelegate.threshold != threshold ||
        oldDelegate.showSegments != showSegments ||
        oldDelegate.silenceRanges != silenceRanges;
  }
}

class MiniWaveformPainter extends CustomPainter {
  MiniWaveformPainter({
    required this.buffer,
    this.colorStart = AppColors.waveformStart,
    this.colorEnd = AppColors.waveformEnd,
  });

  final PcmAudioBuffer buffer;
  final Color colorStart;
  final Color colorEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final data = buffer.getChannelData(0);
    final samplesPerPixel = math.max(1, (data.length / width).ceil());

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );

    for (var i = 0; i < width.toInt(); i++) {
      final start = i * samplesPerPixel;
      final end = math.min(start + samplesPerPixel, data.length);
      var min = 1.0;
      var max = -1.0;
      for (var j = start; j < end; j++) {
        if (data[j] < min) min = data[j];
        if (data[j] > max) max = data[j];
      }
      final yMin = centerY + min * centerY * 0.9;
      final yMax = centerY + max * centerY * 0.9;
      final t = i / width;
      final barColor = Color.lerp(colorStart, colorEnd, t)!;
      final paint = Paint()..color = barColor;
      canvas.drawRect(
        Rect.fromLTWH(i.toDouble(), yMin, 1, math.max(1.0, yMax - yMin)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MiniWaveformPainter oldDelegate) =>
      oldDelegate.buffer != buffer ||
      oldDelegate.colorStart != colorStart ||
      oldDelegate.colorEnd != colorEnd;
}
