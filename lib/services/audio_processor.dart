import '../models/pcm_audio_buffer.dart';
import '../native/speed_processor.dart';

/// Unified audio effects entry point for playback and export.
class AudioProcessor {
  AudioProcessor._();

  /// Length of the fade applied to the edges of a processed buffer.
  static const double _edgeFadeSeconds = 0.004;

  static PcmAudioBuffer getProcessedBuffer(
    PcmAudioBuffer buffer,
    double speed,
    int pitchSemitones, {
    bool preserveFormants = true,
  }) {
    final processed = SpeedProcessor.process(
      buffer,
      speed: speed,
      pitchSemitones: pitchSemitones,
      preserveFormants: preserveFormants,
    );
    if (identical(processed, buffer)) {
      return processed;
    }
    return applyEdgeFade(processed);
  }

  /// Removes the click a non-zero first/last sample produces when a rendered
  /// buffer is played back or concatenated.
  static PcmAudioBuffer applyEdgeFade(
    PcmAudioBuffer buffer, {
    double fadeSeconds = _edgeFadeSeconds,
  }) {
    final fadeFrames = (buffer.sampleRate * fadeSeconds).round();
    if (fadeFrames < 2 || buffer.length < fadeFrames * 2) {
      return buffer;
    }

    for (var channel = 0; channel < buffer.channels; channel++) {
      final samples = buffer.getChannelData(channel);
      for (var frame = 0; frame < fadeFrames; frame++) {
        final gain = frame / fadeFrames;
        samples[frame] *= gain;
        samples[samples.length - 1 - frame] *= gain;
      }
    }
    return buffer;
  }
}
