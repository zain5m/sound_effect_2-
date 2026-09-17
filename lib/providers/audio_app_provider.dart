import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sound_effect_2/main.dart';
import 'package:sound_effect_2/providers/ui_event_service.dart';

import '../models/audio_segment.dart';
import '../models/master_settings.dart';
import '../models/pcm_audio_buffer.dart';
import '../models/split_settings.dart';
import '../services/audio_decode_service.dart';
import '../services/export_service.dart';
import '../services/playback_service.dart';
import '../services/silence_detector.dart';

enum PlaybackType { master, segment }

class AudioAppProvider extends ChangeNotifier {
  final AudioDecodeService _decodeService = AudioDecodeService();
  final SilenceDetector _silenceDetector = SilenceDetector();
  final ExportService _exportService = ExportService();
  final PlaybackService playback = PlaybackService();

  PlaybackType currentPlaybackType = PlaybackType.master;

  PcmAudioBuffer? audioBuffer;
  String fileName = '';
  String fileDisplayName = '';
  String fileFormat = '';

  MasterSettings editingSettings = MasterSettings();
  MasterSettings appliedSettings = MasterSettings();

  SplitSettings splitSettings = SplitSettings();

  List<SilenceRange> silenceRanges = [];
  List<SegmentRange> segmentRanges = [];
  List<AudioSegment> segments = [];

  bool isLoading = false;
  String progressMessage = '';
  double progressValue = 0;

  String playerSegmentName = '-';
  int currentSegmentIndex = -1;
  bool isPlayingAll = false;

  double? draggingProgress;
  int _playbackRequest = 0;
  bool _preparingPlayback = false;

  AudioAppProvider() {
    Dev.console(['AudioAppProvider: Constructor initialized']);
    playback.onStateChanged = notifyListeners;
    playback.onComplete = _onPlaybackComplete;
    playback.onError = (error) =>
        _showToast('خطأ في تشغيل الصوت: $error', true);
    Dev.console(['AudioAppProvider: Playback callbacks registered']);
  }

  bool get hasPendingChanges {
    final hasChanges =
        editingSettings.speed != appliedSettings.speed ||
        editingSettings.pitch != appliedSettings.pitch;
    Dev.console([
      'hasPendingChanges',
      'speed: ${editingSettings.speed} vs ${appliedSettings.speed}',
      'pitch: ${editingSettings.pitch} vs ${appliedSettings.pitch}',
      'result: $hasChanges',
    ]);
    return hasChanges;
  }

  Future<void> applyEffects() async {
    appliedSettings = editingSettings.copyWith();
    notifyListeners();
    try {
      await playback.setParameters(
        appliedSettings.speed,
        appliedSettings.pitch,
      );
    } catch (error) {
      _showToast('خطأ في تطبيق التأثيرات: $error', true);
    }
  }

  void resetMasterSettings() {
    Dev.console(['resetMasterSettings: Resetting to defaults']);
    editingSettings = MasterSettings();
    if (playback.supportsRealtime) {
      unawaited(applyEffects());
    } else {
      notifyListeners();
    }
    Dev.console(['resetMasterSettings: Done']);
  }

  void resetSplitSettings() {
    Dev.console(['resetSplitSettings: Resetting split settings']);
    splitSettings = SplitSettings();
    notifyListeners();
    Dev.console(['resetSplitSettings: Done']);
  }

  void _onPlaybackComplete() {
    Dev.console([
      '_onPlaybackComplete: Triggered',
      'isPlayingAll: $isPlayingAll',
      'currentSegmentIndex: $currentSegmentIndex',
      'segmentsCount: ${segments.length}',
    ]);

    if (isPlayingAll && currentSegmentIndex < segments.length - 1) {
      Dev.console(['_onPlaybackComplete: Playing next segment']);
      playSegment(currentSegmentIndex + 1, continueAll: true);
    } else {
      Dev.console(['_onPlaybackComplete: Playback finished']);
      isPlayingAll = false;
      stopPlayback();
    }
  }

  void setSpeed(double speed) {
    Dev.console(['setSpeed: $speed']);
    editingSettings.speed = speed;
    if (playback.supportsRealtime) {
      unawaited(applyEffects());
    } else {
      notifyListeners();
    }
  }

  void setPitch(int pitch) {
    Dev.console(['setPitch: $pitch']);
    editingSettings.pitch = pitch;
    if (playback.supportsRealtime) {
      unawaited(applyEffects());
    } else {
      notifyListeners();
    }
  }

  void setThreshold(double value) {
    Dev.console(['setThreshold: $value']);
    splitSettings.threshold = value;
    notifyListeners();
  }

  void setMinSilence(double value) {
    Dev.console(['setMinSilence: $value']);
    splitSettings.minSilence = value;
    notifyListeners();
  }

  void setWindowMs(double value) {
    Dev.console(['setWindowMs: $value']);
    splitSettings.windowMs = value;
    notifyListeners();
  }

  // ====================== LOAD FILE ======================
  Future<void> resetState() async {
    await stopPlayback();

    currentPlaybackType = PlaybackType.master;

    audioBuffer = null;

    fileName = '';
    fileDisplayName = '';
    fileFormat = '';

    editingSettings = MasterSettings();
    appliedSettings = MasterSettings();
    splitSettings = SplitSettings();

    silenceRanges.clear();
    segmentRanges.clear();
    segments.clear();

    playerSegmentName = '-';
    currentSegmentIndex = -1;
    isPlayingAll = false;

    draggingProgress = null;

    progressMessage = '';
    progressValue = 0;
  }

  Future<void> loadFile(String path, String name, String? mimeType) async {
    await resetState();
    Dev.console([
      'loadFile: Started',
      'path: $path',
      'name: $name',
      'mime: $mimeType',
    ]);

    isLoading = true;
    progressMessage = 'جاري تحميل الملف...';
    progressValue = 0.2;
    notifyListeners();

    try {
      await stopPlayback();
      segments = [];
      segmentRanges = [];
      silenceRanges = [];

      Dev.console(['loadFile: Decoding audio...']);
      progressMessage = 'جاري فك ترميز الصوت...';
      progressValue = 0.5;
      notifyListeners();

      final buffer = await _decodeService.decodeFile(path);
      audioBuffer = buffer;
      fileName = name.replaceAll(RegExp(r'\.[^/.]+$'), '');
      fileDisplayName = name;
      playerSegmentName = 'الملف الكامل';
      fileFormat = mimeType ?? 'audio';

      Dev.console([
        'loadFile: Success',
        'buffer length: ${buffer.length}',
        'fileName: $fileName',
        'duration: ${buffer.duration}',
      ]);

      _showToast(
        '✅ تم تحميل الملف — اضبط التأثيرات ثم اضغط "اكتشاف الصمت"',
        false,
      );
    } catch (e, stack) {
      Dev.console(['loadFile: ERROR', e.toString(), stack.toString()]);
      _showToast('❌ خطأ في قراءة الملف: $e', true);
      audioBuffer = null;
    } finally {
      isLoading = false;
      progressMessage = '';
      progressValue = 0;
      notifyListeners();
      Dev.console(['loadFile: Finished']);
    }
  }

  // ====================== ANALYZE & SPLIT ======================
  Future<void> analyzeAndSplit() async {
    Dev.console(['analyzeAndSplit: Started']);

    if (audioBuffer == null) {
      Dev.console(['analyzeAndSplit: No audio buffer!']);
      _showToast('❌ يرجى رفع ملف صوتي أولاً!', true);
      return;
    }

    isLoading = true;
    progressMessage = 'جاري تحليل الموجة الصوتية...';
    progressValue = 0.3;
    notifyListeners();

    try {
      final buffer = audioBuffer!;
      final settings = splitSettings.copyWith();

      Dev.console([
        'analyzeAndSplit: Starting analysis',
        'threshold: ${settings.threshold}',
        'minSilence: ${settings.minSilence}',
        'windowMs: ${settings.windowMs}',
      ]);

      final result = await Future(
        () => _silenceDetector.analyze(buffer, settings),
      );

      silenceRanges = result.silenceRanges;
      segmentRanges = result.segmentRanges;
      segments = result.segments;

      Dev.console([
        'analyzeAndSplit: Success',
        'silenceRanges: ${silenceRanges.length}',
        'segments: ${segments.length}',
      ]);

      _showToast(
        '✅ تم اكتشاف ${silenceRanges.length} فترة صمت → ${segments.length} مقطع!',
        false,
      );
    } catch (e, stack) {
      Dev.console(['analyzeAndSplit: ERROR', e.toString(), stack.toString()]);
      _showToast('❌ خطأ في التحليل: $e', true);
    } finally {
      isLoading = false;
      progressMessage = '';
      progressValue = 0;
      notifyListeners();
      Dev.console(['analyzeAndSplit: Finished']);
    }
  }

  // ====================== PLAYBACK ======================
  Future<void> playMaster({Duration? seekAfterPlay}) async {
    final buffer = audioBuffer;
    if (buffer == null) return;
    final request = ++_playbackRequest;
    isPlayingAll = false;
    try {
      await playback.stop();
      if (request != _playbackRequest) return;
      isLoading = true;
      _preparingPlayback = true;
      progressMessage = 'جاري تحميل الصوت...';
      currentPlaybackType = PlaybackType.master;
      currentSegmentIndex = -1;
      playerSegmentName = 'الملف الكامل';
      notifyListeners();
      await playback.loadBuffer(
        buffer,
        speed: appliedSettings.speed,
        pitch: appliedSettings.pitch,
      );
      if (request != _playbackRequest) return;
      if (seekAfterPlay != null) await playback.seek(seekAfterPlay);
      if (request != _playbackRequest) return;
      await playback.play();
    } catch (error) {
      if (request == _playbackRequest) {
        _showToast('خطأ في تشغيل الصوت: $error', true);
      }
    } finally {
      if (request == _playbackRequest) {
        _preparingPlayback = false;
        isLoading = false;
        progressMessage = '';
        notifyListeners();
      }
    }
  }

  Future<void> playSegment(
    int idx, {
    bool continueAll = false,
    Duration? seekAfterPlay,
  }) async {
    if (idx < 0 || idx >= segments.length) return;
    final request = ++_playbackRequest;
    final segment = segments[idx];
    if (!continueAll) isPlayingAll = false;
    try {
      await playback.stop();
      if (request != _playbackRequest) return;
      currentPlaybackType = PlaybackType.segment;
      currentSegmentIndex = idx;
      playerSegmentName = 'المقطع ${segment.index}';
      notifyListeners();
      await playback.loadBuffer(
        segment.buffer,
        speed: appliedSettings.speed,
        pitch: appliedSettings.pitch,
      );
      if (request != _playbackRequest) return;
      if (seekAfterPlay != null) await playback.seek(seekAfterPlay);
      if (request != _playbackRequest) return;
      await playback.play();
    } catch (error) {
      if (request == _playbackRequest) {
        isPlayingAll = false;
        _showToast('خطأ في تشغيل المقطع: $error', true);
      }
    } finally {
      if (request == _playbackRequest) {
        _preparingPlayback = false;
        isLoading = false;
        progressMessage = '';
        notifyListeners();
      }
    }
  }

  Future<void> playAllSegments() async {
    Dev.console(['playAllSegments: Started', 'segments: ${segments.length}']);
    if (segments.isEmpty) return;

    if (isPlayingAll) {
      Dev.console(['playAllSegments: Stopping all playback']);
      await stopPlayback();
      return;
    }

    isPlayingAll = true;
    await playSegment(0, continueAll: true);
  }

  Future<void> togglePlayback() async {
    Dev.console(['togglePlayback: Called', 'isPlaying: ${playback.isPlaying}']);
    if (playback.isPlaying) {
      await playback.pause();
    } else if (playback.hasLoadedFile) {
      await playback.resume();
    } else if (currentSegmentIndex >= 0) {
      await playSegment(currentSegmentIndex);
    } else {
      await playMaster();
    }
    notifyListeners();
  }

  Future<void> prevSegment() async {
    Dev.console(['prevSegment: current=$currentSegmentIndex']);
    if (currentSegmentIndex > 0) {
      await playSegment(currentSegmentIndex - 1);
    }
  }

  Future<void> nextSegment() async {
    Dev.console(['nextSegment: current=$currentSegmentIndex']);
    if (currentSegmentIndex < segments.length - 1) {
      await playSegment(currentSegmentIndex + 1);
    }
  }

  Future<void> stopPlayback() async {
    ++_playbackRequest;
    if (_preparingPlayback) {
      _preparingPlayback = false;
      isLoading = false;
      progressMessage = '';
    }
    Dev.console(['stopPlayback: Called']);
    isPlayingAll = false;
    await playback.stop();
    notifyListeners();
    Dev.console(['stopPlayback: Stopped']);
  }

  // ====================== DOWNLOAD ======================
  Future<void> downloadSegment(int idx) async {
    Dev.console(['downloadSegment: idx=$idx']);
    if (idx < 0 || idx >= segments.length) return;

    final seg = segments[idx];
    isLoading = true;
    progressMessage = 'جاري معالجة المقطع ${seg.index}...';
    notifyListeners();

    try {
      final file = await _exportService.exportSegmentMp3(
        seg,
        fileName,
        appliedSettings,
      );
      await _exportService.saveFileToMusic(file);
      _showToast('✅ تم حفظ المقطع ${seg.index} في Music/SoundEffect', false);
    } catch (e, stack) {
      Dev.console(['downloadSegment: ERROR', e.toString(), stack.toString()]);
      _showToast('❌ خطأ في تصدير المقطع', true);
    } finally {
      isLoading = false;
      progressMessage = '';
      notifyListeners();
    }
  }

  Future<void> downloadAll() async {
    Dev.console(['downloadAll: Started', 'segments: ${segments.length}']);
    if (segments.isEmpty) {
      _showToast('❌ لا توجد مقاطع للتحميل', true);
      return;
    }

    isLoading = true;
    progressMessage = 'جاري معالجة المقاطع...';
    notifyListeners();

    try {
      final zipFile = await _exportService.exportAllZip(
        segments,
        fileName,
        appliedSettings,
        (progress, message) {
          progressValue = progress;
          progressMessage = message;
          notifyListeners();
          Dev.console(['downloadAll: Progress $progress - $message']);
        },
      );
      await _exportService.saveFileToMusic(zipFile);
      _showToast(
        '✅ تم حفظ ${segments.length} مقطع في Music/SoundEffect',
        false,
      );
    } catch (e, stack) {
      Dev.console(['downloadAll: ERROR', e.toString(), stack.toString()]);
      _showToast('❌ خطأ في إنشاء ZIP: $e', true);
    } finally {
      isLoading = false;
      progressMessage = '';
      progressValue = 0;
      notifyListeners();
      Dev.console(['downloadAll: Finished']);
    }
  }

  void playAtTime(double time) {
    Dev.console(['playAtTime: $time']);
    for (var i = 0; i < segments.length; i++) {
      if (time >= segments[i].startTime && time <= segments[i].endTime) {
        Dev.console(['playAtTime: Found segment $i']);
        playSegment(i);
        return;
      }
    }
    Dev.console(['playAtTime: No segment found at time $time']);
  }

  void _showToast(String message, bool isError) {
    Dev.console(['_showToast: ${isError ? "ERROR" : "SUCCESS"} - $message']);
    if (isError) {
      UiEventService.instance.showError(message);
    } else {
      UiEventService.instance.showSuccess(message);
    }
  }

  void updateDraggingProgress(double value) {
    draggingProgress = value;
    notifyListeners();
  }

  Future<void> seekTo(double value) async {
    Dev.console(['seekTo: $value']);
    // final duration = playback.duration;
    final duration = displayDuration;
    if (duration <= Duration.zero) return;

    draggingProgress = null;
    final position = Duration(
      milliseconds: (duration.inMilliseconds * value).round(),
    );

    await playback.seek(position);
    // await playback.seek(position);
    notifyListeners();
  }

  // double get playbackProgress {
  //   if (draggingProgress != null) return draggingProgress!;
  //
  //   if (playback.duration.inMilliseconds == 0) return 0;
  //
  //   return (playback.position.inMilliseconds / playback.duration.inMilliseconds)
  //       .clamp(0.0, 1.0);
  // }
  double get playbackProgress {
    if (draggingProgress != null) {
      return draggingProgress!;
    }

    if (displayDuration.inMilliseconds == 0) {
      return 0;
    }

    return (displayPosition.inMilliseconds / displayDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // Duration get originalDuration =>
  //     Duration(milliseconds: ((audioBuffer?.duration ?? 0) * 1000).round());

  Duration get displayDuration {
    if (currentPlaybackType == PlaybackType.master) {
      return Duration(
        milliseconds: ((audioBuffer?.duration ?? 0) * 1000).round(),
      );
    }

    if (currentSegmentIndex >= 0 && currentSegmentIndex < segments.length) {
      return Duration(
        milliseconds: (segments[currentSegmentIndex].buffer.duration * 1000)
            .round(),
      );
    }

    return Duration.zero;
  }

  // Duration get displayPosition {
  //   final milliseconds =
  //       playback.position.inMilliseconds * appliedSettings.speed;
  //
  //   return Duration(milliseconds: milliseconds.round());
  // }
  Duration get displayPosition {
    return playback.position;
  }

  @override
  void dispose() {
    ++_playbackRequest;
    Dev.console(['AudioAppProvider: Disposing...']);
    playback.dispose();
    super.dispose();
    Dev.console(['AudioAppProvider: Disposed']);
  }

  double get absolutePlaybackTime {
    if (currentPlaybackType == PlaybackType.master) {
      return displayPosition.inMilliseconds / 1000;
    }

    if (currentSegmentIndex >= 0) {
      return segments[currentSegmentIndex].startTime +
          displayPosition.inMilliseconds / 1000;
    }

    return 0;
  }
}

String formatTime(double seconds) {
  if (!seconds.isFinite || seconds.isNaN) return '0:00';
  final mins = seconds ~/ 60;
  final secs = (seconds % 60).floor();
  return '$mins:${secs.toString().padLeft(2, '0')}';
}
