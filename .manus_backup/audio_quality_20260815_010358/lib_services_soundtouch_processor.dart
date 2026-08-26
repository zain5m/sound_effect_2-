import 'dart:typed_data';

import '../models/pcm_audio_buffer.dart';
import 'soundtouch/pcm_buffer_source.dart';
import 'soundtouch/simple_filter.dart';
import 'soundtouch/sound_touch.dart';

class SoundtouchProcessor {
  static PcmAudioBuffer processBuffer(
    PcmAudioBuffer inputBuffer,
    double tempo,
    double pitchSemitones,
  ) {
    final soundTouch = SoundTouch();
    soundTouch.tempo = tempo;
    soundTouch.pitchSemitones = pitchSemitones;

    final source = PcmBufferSource(inputBuffer);
    final filter = SimpleFilter(source, soundTouch);

    final numChannels = inputBuffer.channels;
    final sampleRate = inputBuffer.sampleRate;
    final estimatedFrames = (inputBuffer.length / tempo).ceil() + sampleRate;

    final interleaved = Float32List(estimatedFrames * numChannels);
    var totalExtracted = 0;
    const chunkSize = 4096;

    while (true) {
      final chunk = Float32List(chunkSize * numChannels);
      final frames = filter.extract(chunk, chunkSize);
      if (frames == 0) break;

      final samplesToCopy = frames * numChannels;
      final offset = totalExtracted * numChannels;
      for (var i = 0; i < samplesToCopy; i++) {
        interleaved[offset + i] = chunk[i];
      }
      totalExtracted += frames;
    }

    final channelData = List<Float32List>.generate(numChannels, (c) {
      final data = Float32List(totalExtracted);
      for (var i = 0; i < totalExtracted; i++) {
        data[i] = interleaved[i * numChannels + c];
      }
      return data;
    });

    return PcmAudioBuffer(
      channels: numChannels,
      sampleRate: sampleRate,
      channelData: channelData,
    );
  }

  static PcmAudioBuffer getProcessedBuffer(
    PcmAudioBuffer buffer,
    double speed,
    int pitchSemitones,
  ) {
    if (speed == 1.0 && pitchSemitones == 0) {
      return buffer;
    }
    return processBuffer(buffer, speed, pitchSemitones.toDouble());
  }
}
