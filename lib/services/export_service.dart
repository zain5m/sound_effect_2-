import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/audio_segment.dart';
import '../models/master_settings.dart';
import '../models/pcm_audio_buffer.dart';
import 'soundtouch_processor.dart';
import 'wav_encoder.dart';

class ExportService {
  Future<File> _wavToMp3(File wavFile) async {
    final outputPath = wavFile.path.replaceAll('.wav', '.mp3');

    final command =
        '-y -i "${wavFile.path}" -codec:a libmp3lame -qscale:a 2 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        await wavFile.delete();
      } catch (_) {}

      return File(outputPath);
    } else {
      final output = await session.getOutput();

      throw Exception('فشل تحويل الملف إلى MP3: $output');
    }
  }

  Future<File> exportSegmentMp3(
    AudioSegment segment,
    String baseName,
    MasterSettings masterSettings,
  ) async {
    final wavBytes = await _renderWav(
      segment.buffer,
      masterSettings.speed,
      masterSettings.pitch,
    );

    final tempDir = await getTemporaryDirectory();

    final wavFile = File(
      '${tempDir.path}/${baseName}_part${segment.index}.wav',
    );

    await wavFile.writeAsBytes(wavBytes);

    return await _wavToMp3(wavFile);
  }

  Future<File> exportAllZip(
    List<AudioSegment> segments,
    String baseName,
    MasterSettings masterSettings,
    void Function(double progress, String message)? onProgress,
  ) async {
    final archive = Archive();
    final tempDir = await getTemporaryDirectory();

    for (var i = 0; i < segments.length; i++) {
      onProgress?.call(
        (i + 0.5) / segments.length * 0.5,
        'جاري معالجة المقطع ${i + 1} من ${segments.length}',
      );

      final seg = segments[i];

      final wavBytes = await _renderWav(
        seg.buffer,
        masterSettings.speed,
        masterSettings.pitch,
      );

      final tempWavFile = File(
        '${tempDir.path}/temp_${seg.index}_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      await tempWavFile.writeAsBytes(wavBytes);

      final mp3File = await _wavToMp3(tempWavFile);
      final mp3Bytes = await mp3File.readAsBytes();

      archive.addFile(
        ArchiveFile(
          'samples/${baseName}_part${seg.index}.mp3',
          mp3Bytes.length,
          mp3Bytes,
        ),
      );

      try {
        await mp3File.delete();
      } catch (_) {}

      onProgress?.call(
        (i + 1) / segments.length * 0.5,
        'جاري معالجة المقطع ${i + 1} من ${segments.length}',
      );
    }

    onProgress?.call(0.75, 'جاري إنشاء ملف ZIP...');

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    if (zipBytes == null) {
      throw Exception('فشل إنشاء ZIP');
    }

    // استخدمنا tempDir الموجود من بداية الدالة
    final zipFile = File('${tempDir.path}/${baseName}_all_segments.zip');

    await zipFile.writeAsBytes(zipBytes);

    onProgress?.call(1.0, 'تم');

    return zipFile;
  }

  Future<String> saveFileToMusic(File tempFile) async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        if (!await Permission.storage.request().isGranted) {
          throw Exception('Storage permission denied');
        }
      } else {
        if (!await Permission.audio.request().isGranted) {
          // Keep existing behavior.
        }
      }

      final musicPath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_MUSIC,
      );

      final appMusicDir = Directory(p.join(musicPath, 'مغير سرعة السامبلر'));

      if (!await appMusicDir.exists()) {
        await appMusicDir.create(recursive: true);
      }

      String fileName = p.basename(tempFile.path);
      String destPath = p.join(appMusicDir.path, fileName);

      int counter = 1;
      final String extension = p.extension(fileName);
      final String nameWithoutExt = p.basenameWithoutExtension(fileName);

      while (await File(destPath).exists()) {
        destPath = p.join(
          appMusicDir.path,
          '${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}$extension',
        );

        if (counter++ > 10) break;
      }

      final savedFile = await tempFile.copy(destPath);

      return savedFile.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();

      final destPath = p.join(directory.path, p.basename(tempFile.path));

      final savedFile = await tempFile.copy(destPath);

      return savedFile.path;
    }
  }

  Future<File> bufferToTempWav(
    PcmAudioBuffer buffer,
    String name, {
    double speed = 1,
    int pitch = 0,
  }) async {
    final wavBytes = await _renderWav(buffer, speed, pitch);

    final tempDir = await getTemporaryDirectory();

    final file = File('${tempDir.path}/$name.wav');

    await file.writeAsBytes(wavBytes);

    return file;
  }
}

Future<Uint8List> _renderWav(PcmAudioBuffer buffer, double speed, int pitch) {
  return Isolate.run(
    () => WavEncoder.encode(
      SoundtouchProcessor.getProcessedBuffer(buffer, speed, pitch),
    ),
  );
}
