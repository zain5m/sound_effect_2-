import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../models/pcm_audio_buffer.dart';

class AudioDecodeService {
  Future<PcmAudioBuffer> decodeFile(String filePath) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/decoded_${DateTime.now().millisecondsSinceEpoch}.pcm';

    final command =
        '-i "$filePath" -f f32le -acodec pcm_f32le -ac 2 -ar 44100 "$outputPath"';
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      throw Exception('فشل فك ترميز الملف: $output');
    }

    final pcmFile = File(outputPath);
    if (!await pcmFile.exists()) {
      throw Exception('لم يتم إنشاء ملف PCM');
    }

    final bytes = await pcmFile.readAsBytes();
    // final floatData = bytes.buffer.asFloat32List();
    final floatData = Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );

    final totalFrames = floatData.length ~/ 2;
    final left = Float32List(totalFrames);
    final right = Float32List(totalFrames);

    for (var i = 0; i < totalFrames; i++) {
      left[i] = floatData[i * 2];
      right[i] = floatData[i * 2 + 1];
    }

    // try {
    //   await pcmFile.delete();
    // } catch (_) {}
    if (await pcmFile.exists()) {
      await pcmFile.delete();
    }
    return PcmAudioBuffer(
      channels: 2,
      sampleRate: 44100,
      channelData: [left, right],
    );
  }
}
