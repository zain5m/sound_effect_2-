import 'dart:typed_data';

class PcmAudioBuffer {
  PcmAudioBuffer({
    required this.channels,
    required this.sampleRate,
    required this.channelData,
  });

  final List<Float32List> channelData;
  final int channels;
  final int sampleRate;

  int get length => channelData.isEmpty ? 0 : channelData[0].length;

  double get duration => length / sampleRate;

  Float32List getChannelData(int channel) => channelData[channel];

  PcmAudioBuffer slice(int startSample, int endSample) {
    final clampedEnd = endSample.clamp(0, length);
    final clampedStart = startSample.clamp(0, clampedEnd);
    final sliced = <Float32List>[];
    for (var ch = 0; ch < channels; ch++) {
      sliced.add(
        Float32List.sublistView(
          channelData[ch],
          clampedStart,
          clampedEnd,
        ),
      );
    }
    return PcmAudioBuffer(
      channels: channels,
      sampleRate: sampleRate,
      channelData: sliced,
    );
  }

  PcmAudioBuffer copy() {
    return PcmAudioBuffer(
      channels: channels,
      sampleRate: sampleRate,
      channelData: channelData.map(Float32List.fromList).toList(),
    );
  }
}
