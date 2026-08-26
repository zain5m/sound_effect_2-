import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pcm_audio_buffer.dart';

class AudioDecodeService {
  Future<PcmAudioBuffer> decodeFile(String filePath) async {
    final probeSession = await FFprobeKit.getMediaInformation(filePath);
    final mediaInformation = probeSession.getMediaInformation();
    if (mediaInformation == null) {
      throw Exception('تعذر قراءة معلومات الملف الصوتي.');
    }

    final audioStreams = mediaInformation
        .getStreams()
        .where((stream) => stream.getType() == 'audio')
        .toList(growable: false);
    if (audioStreams.isEmpty) {
      throw Exception('لا يحتوي الملف على مسار صوتي قابل للمعالجة.');
    }

    final stream = audioStreams.first;
    final sampleRate = int.tryParse(stream.getSampleRate() ?? '');
    final channelProperty = stream.getAllProperties()?['channels'];
    final channels = channelProperty is num
        ? channelProperty.toInt()
        : int.tryParse('$channelProperty');
    if (sampleRate == null ||
        sampleRate < 8000 ||
        channels == null ||
        channels < 1) {
      throw Exception('مواصفات الملف الصوتي غير مدعومة.');
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/decoded_${DateTime.now().microsecondsSinceEpoch}.f32le';
    final streamIndex = stream.getIndex();
    if (streamIndex == null) {
      throw Exception('تعذر تحديد مسار الصوت في الملف.');
    }

    try {
      // Keep the source sample rate and channel count; only the internal PCM
      // representation is converted to float32 for the DSP stage.
      final command =
          '-y -i "$filePath" -map 0:$streamIndex -vn -sn -dn -f f32le -acodec pcm_f32le "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        throw Exception('فشل فك ترميز الملف: $output');
      }

      final pcmFile = File(outputPath);
      if (!await pcmFile.exists()) {
        throw Exception('لم يتم إنشاء ملف PCM.');
      }

      final bytes = await pcmFile.readAsBytes();
      if (bytes.lengthInBytes % (Float32List.bytesPerElement * channels) != 0) {
        throw Exception('بيانات PCM الناتجة غير سليمة.');
      }

      final interleaved = Float32List.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes ~/ Float32List.bytesPerElement,
      );
      final frames = interleaved.length ~/ channels;
      final channelData = List<Float32List>.generate(channels, (channel) {
        final data = Float32List(frames);
        for (var frame = 0; frame < frames; frame++) {
          data[frame] = interleaved[frame * channels + channel];
        }
        return data;
      });

      return PcmAudioBuffer(
        channels: channels,
        sampleRate: sampleRate,
        channelData: channelData,
      );
    } finally {
      final pcmFile = File(outputPath);
      if (await pcmFile.exists()) {
        await pcmFile.delete();
      }
    }
  }
}
