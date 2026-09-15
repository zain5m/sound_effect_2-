// import 'dart:math' as math;
// import 'dart:typed_data';
//
// import 'package:flutter_test/flutter_test.dart';
// import 'package:sound_effect_2/models/master_settings.dart';
// import 'package:sound_effect_2/models/pcm_audio_buffer.dart';
// import 'package:sound_effect_2/native/speed_processor.dart';
// import 'package:sound_effect_2/services/audio_processor.dart';
// import 'package:sound_effect_2/services/resampler.dart';
//
// PcmAudioBuffer _sine({
//   required double frequency,
//   required int frames,
//   int sampleRate = 48000,
//   int channels = 1,
// }) {
//   final channelData = List<Float32List>.generate(channels, (_) {
//     final samples = Float32List(frames);
//     for (var frame = 0; frame < frames; frame++) {
//       samples[frame] = math
//           .sin(2 * math.pi * frequency * frame / sampleRate)
//           .toDouble();
//     }
//     return samples;
//   });
//   return PcmAudioBuffer(
//     channels: channels,
//     sampleRate: sampleRate,
//     channelData: channelData,
//   );
// }
//
// double _rms(Float32List samples, int start, int end) {
//   var sum = 0.0;
//   for (var i = start; i < end; i++) {
//     sum += samples[i] * samples[i];
//   }
//   return math.sqrt(sum / (end - start));
// }
//
// void main() {
//   group('SpeedProcessor.isVarispeed', () {
//     test('matches speed/pitch pairs that describe plain varispeed', () {
//       expect(SpeedProcessor.isVarispeed(2.0, 12), isTrue);
//       expect(SpeedProcessor.isVarispeed(0.5, -12), isTrue);
//       expect(SpeedProcessor.isVarispeed(1.0594630943592953, 1), isTrue);
//     });
//
//     test('rejects independent speed and pitch changes', () {
//       expect(SpeedProcessor.isVarispeed(2.0, 0), isFalse);
//       expect(SpeedProcessor.isVarispeed(1.0, 3), isFalse);
//       expect(SpeedProcessor.isVarispeed(1.2, 12), isFalse);
//     });
//
//     test('rejects a non-positive speed', () {
//       expect(SpeedProcessor.isVarispeed(0, 0), isFalse);
//     });
//   });
//
//   group('SpeedProcessor.process', () {
//     test('returns the input untouched when nothing changes', () {
//       final input = _sine(frequency: 440, frames: 512);
//       expect(
//         identical(
//           SpeedProcessor.process(input, speed: 1.0, pitchSemitones: 0),
//           input,
//         ),
//         isTrue,
//       );
//     });
//
//     test('resamples varispeed combinations without the native engine', () {
//       final input = _sine(frequency: 440, frames: 4800, channels: 2);
//       final output = SpeedProcessor.process(
//         input,
//         speed: 2.0,
//         pitchSemitones: 12,
//       );
//
//       expect(output.channels, 2);
//       expect(output.sampleRate, input.sampleRate);
//       expect(output.length, 2400);
//     });
//   });
//
//   group('VarispeedResampler', () {
//     test('preserves a tone level when slowing down', () {
//       final input = _sine(frequency: 440, frames: 9600);
//       final output = VarispeedResampler.resample(input, 0.5);
//
//       expect(output.length, 19200);
//       final samples = output.getChannelData(0);
//       // Skip the filter ramp-in/out at both edges.
//       expect(_rms(samples, 200, samples.length - 200), closeTo(0.707, 0.01));
//     });
//
//     test('rejects aliasing of content above the new Nyquist', () {
//       // 18 kHz sped up 2x would fold back to 12 kHz without band limiting.
//       final input = _sine(frequency: 18000, frames: 9600);
//       final output = VarispeedResampler.resample(input, 2.0);
//       final samples = output.getChannelData(0);
//
//       expect(output.length, 4800);
//       expect(_rms(samples, 200, samples.length - 200), lessThan(0.05));
//     });
//
//     test('returns the same buffer for a unity ratio', () {
//       final input = _sine(frequency: 440, frames: 128);
//       expect(identical(VarispeedResampler.resample(input, 1.0), input), isTrue);
//     });
//
//     test('throws on an invalid ratio', () {
//       final input = _sine(frequency: 440, frames: 128);
//       expect(
//         () => VarispeedResampler.resample(input, 0),
//         throwsA(isA<ArgumentError>()),
//       );
//     });
//   });
//
//   group('AudioProcessor.applyEdgeFade', () {
//     test('silences the first and last sample', () {
//       final input = _sine(frequency: 440, frames: 4800, channels: 2);
//       final faded = AudioProcessor.applyEdgeFade(input);
//
//       for (var channel = 0; channel < faded.channels; channel++) {
//         final samples = faded.getChannelData(channel);
//         expect(samples.first, 0.0);
//         expect(samples.last, 0.0);
//       }
//     });
//
//     test('leaves the body of the buffer untouched', () {
//       final original = _sine(frequency: 440, frames: 4800);
//       final expected = Float32List.fromList(original.getChannelData(0));
//       final faded = AudioProcessor.applyEdgeFade(original);
//       final samples = faded.getChannelData(0);
//       final fadeFrames = (original.sampleRate * 0.004).round();
//
//       for (
//         var frame = fadeFrames;
//         frame < samples.length - fadeFrames;
//         frame++
//       ) {
//         expect(samples[frame], expected[frame]);
//       }
//     });
//
//     test('skips buffers shorter than two fades', () {
//       final input = PcmAudioBuffer(
//         channels: 1,
//         sampleRate: 48000,
//         channelData: [Float32List.fromList(List<double>.filled(16, 0.5))],
//       );
//       final faded = AudioProcessor.applyEdgeFade(input);
//       expect(faded.getChannelData(0), everyElement(0.5));
//     });
//   });
//
//   group('MasterSettings', () {
//     test('preserves formants by default', () {
//       expect(MasterSettings().preserveFormants, isTrue);
//     });
//
//     test('copyWith overrides only the given fields', () {
//       final settings = MasterSettings(speed: 1.5, pitch: 3);
//       final updated = settings.copyWith(preserveFormants: false);
//
//       expect(updated.speed, 1.5);
//       expect(updated.pitch, 3);
//       expect(updated.preserveFormants, isFalse);
//     });
//   });
// }
