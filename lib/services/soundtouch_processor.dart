import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

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
    if (Platform.isAndroid) {
      return _processNative(inputBuffer, tempo, pitchSemitones);
    }
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

  static final _library = DynamicLibrary.open('libstretch.so');
  static final _create = _library
      .lookupFunction<
        Pointer<Void> Function(Int32, Int32),
        Pointer<Void> Function(int, int)
      >('stretch_create');
  static final _destroy = _library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('stretch_destroy');
  static final _process = _library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Float>,
          Int32,
          Pointer<Float>,
          Int32,
          Float,
          Float,
          Float,
          Int32,
          Float,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Float>,
          int,
          Pointer<Float>,
          int,
          double,
          double,
          double,
          int,
          double,
        )
      >('stretch_process_ex');

  static PcmAudioBuffer _processNative(
    PcmAudioBuffer input,
    double speed,
    double pitch,
  ) {
    if (!speed.isFinite ||
        speed < 0.25 ||
        speed > 4 ||
        !pitch.isFinite ||
        pitch < -24 ||
        pitch > 24) {
      throw ArgumentError('Invalid pitch or speed');
    }
    if (input.length == 0) return input;
    final outputFrames = (input.length / speed).ceil();
    final processor = _create(input.channels, input.sampleRate);
    if (processor == nullptr) {
      throw StateError('Could not create audio processor');
    }
    Pointer<Float> source = nullptr;
    Pointer<Float> output = nullptr;
    try {
      source = calloc<Float>(input.length * input.channels);
      output = calloc<Float>(outputFrames * input.channels);
      final sourceData = source.asTypedList(input.length * input.channels);
      for (var c = 0; c < input.channels; c++) {
        final data = input.channelData[c];
        for (var i = 0; i < input.length; i++) {
          sourceData[i * input.channels + c] = data[i];
        }
      }
      final status = _process(
        processor,
        source,
        input.length,
        output,
        outputFrames,
        speed,
        pitch,
        0,
        0,
        0,
      );
      if (status != 0) {
        throw StateError('Native audio processing failed ($status)');
      }
      final samples = output.asTypedList(outputFrames * input.channels);
      return PcmAudioBuffer(
        channels: input.channels,
        sampleRate: input.sampleRate,
        channelData: List.generate(input.channels, (c) {
          final data = Float32List(outputFrames);
          for (var i = 0; i < outputFrames; i++) {
            data[i] = samples[i * input.channels + c];
          }
          return data;
        }),
      );
    } finally {
      calloc.free(source);
      calloc.free(output);
      _destroy(processor);
    }
  }
}
