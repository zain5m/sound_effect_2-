import '../models/pcm_audio_buffer.dart';
import '../native/speed_processor.dart';

/// Unified audio effects entry point for playback and export.
class AudioProcessor {
  AudioProcessor._();

  static PcmAudioBuffer getProcessedBuffer(
    PcmAudioBuffer buffer,
    double speed,
    int pitchSemitones,
  ) {
    return SpeedProcessor.process(
      buffer,
      speed: speed,
      pitchSemitones: pitchSemitones,
    );
  }
}
