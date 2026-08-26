import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_segment.dart';
import '../models/master_settings.dart';
import '../models/pcm_audio_buffer.dart';
import 'soundtouch_processor.dart';
import 'wav_encoder.dart';

class ExportService {
  Future<File> exportSegmentWav(
    AudioSegment segment,
    String baseName,
    MasterSettings masterSettings,
  ) async {
    final processed = SoundtouchProcessor.getProcessedBuffer(
      segment.buffer,
      masterSettings.speed,
      masterSettings.pitch,
    );
    final wavBytes = WavEncoder.encode(processed);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${baseName}_part${segment.index}.wav');
    await file.writeAsBytes(wavBytes);
    return file;
  }

  Future<File> exportAllZip(
    List<AudioSegment> segments,
    String baseName,
    MasterSettings masterSettings,
    void Function(double progress, String message)? onProgress,
  ) async {
    final archive = Archive();

    for (var i = 0; i < segments.length; i++) {
      onProgress?.call(
        (i + 0.5) / segments.length * 0.5,
        'جاري معالجة المقطع ${i + 1} من ${segments.length}',
      );
      final seg = segments[i];
      final processed = SoundtouchProcessor.getProcessedBuffer(
        seg.buffer,
        masterSettings.speed,
        masterSettings.pitch,
      );
      final wavBytes = WavEncoder.encode(processed);
      archive.addFile(
        ArchiveFile(
          'samples/${baseName}_part${seg.index}.wav',
          wavBytes.length,
          wavBytes,
        ),
      );
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

    final tempDir = await getTemporaryDirectory();
    final zipFile = File('${tempDir.path}/${baseName}_all_segments.zip');
    await zipFile.writeAsBytes(zipBytes);
    onProgress?.call(1.0, 'تم');
    return zipFile;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<File> bufferToTempWav(PcmAudioBuffer buffer, String name) async {
    final wavBytes = WavEncoder.encode(buffer);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$name.wav');
    await file.writeAsBytes(wavBytes);
    return file;
  }
}
