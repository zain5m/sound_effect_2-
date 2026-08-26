import '../models/pcm_audio_buffer.dart';
import 'audio_processor.dart';

/// Backwards-compatible alias for [AudioProcessor].
@Deprecated('Use AudioProcessor instead')
class NativeAudioProcessor {
  NativeAudioProcessor._();

  static PcmAudioBuffer process(
    PcmAudioBuffer buffer,
    double speed,
    int pitchSemitones,
  ) {
    return AudioProcessor.getProcessedBuffer(buffer, speed, pitchSemitones);
  }
}
