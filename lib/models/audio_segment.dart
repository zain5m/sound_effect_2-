import 'pcm_audio_buffer.dart';

class SegmentRange {
  const SegmentRange({required this.start, required this.end});

  final double start;
  final double end;
}

class SilenceRange {
  const SilenceRange(this.start, this.end);

  final double start;
  final double end;
}

class AudioSegment {
  AudioSegment({
    required this.index,
    required this.buffer,
    required this.startTime,
    required this.endTime,
    required this.startSample,
    required this.endSample,
  });

  final int index;
  final PcmAudioBuffer buffer;
  final double startTime;
  final double endTime;
  final int startSample;
  final int endSample;

  double get duration => endTime - startTime;
}
