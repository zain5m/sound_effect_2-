import 'dart:async';

class UiEventService {
  UiEventService._();

  static final instance = UiEventService._();
  final _toastController = StreamController<ToastEvent>.broadcast();

  Stream<ToastEvent> get toastStream => _toastController.stream;

  void showSuccess(String message) {
    _toastController.add(ToastEvent(message: message, isError: false));
  }

  void showError(String message) {
    _toastController.add(ToastEvent(message: message, isError: true));
  }

  void dispose() {
    _toastController.close();
  }
}

class ToastEvent {
  final String message;
  final bool isError;

  const ToastEvent({required this.message, required this.isError});
}

// class AudioAppProvider extends ChangeNotifier {
//   final AudioDecodeService _decodeService = AudioDecodeService();
//   final SilenceDetector _silenceDetector = SilenceDetector();
//   final ExportService _exportService = ExportService();
//   final PlaybackService playback = PlaybackService();
//
//   PlaybackType currentPlaybackType = PlaybackType.master;
//
//   PcmAudioBuffer? audioBuffer;
//   String fileName = '';
//   String fileDisplayName = '';
//   String fileFormat = '';
//
//   // MasterSettings masterSettings = MasterSettings();
//   MasterSettings editingSettings = MasterSettings();
//   MasterSettings appliedSettings = MasterSettings();
//
//   SplitSettings splitSettings = SplitSettings();
//
//   List<SilenceRange> silenceRanges = [];
//   List<SegmentRange> segmentRanges = [];
//   List<AudioSegment> segments = [];
//
//   bool isLoading = false;
//   String progressMessage = '';
//   double progressValue = 0;
//
//   // bool showPlayer = false;
//   String playerSegmentName = '-';
//   int currentSegmentIndex = -1;
//   bool isPlayingAll = false;
//
//   // String? toastMessage;
//   // bool toastIsError = false;
//   double? draggingProgress;
//   AudioAppProvider() {
//     Dev.console(['AudioAppProvider: Constructor initialized']);
//     playback.onStateChanged = notifyListeners;
//     playback.onComplete = _onPlaybackComplete;
//     Dev.console(['AudioAppProvider: Playback callbacks registered']);
//   }
//   bool get hasPendingChanges {
//     final hasChanges =
//         editingSettings.speed != appliedSettings.speed ||
//         editingSettings.pitch != appliedSettings.pitch;
//     Dev.console([
//       'hasPendingChanges',
//       'speed: ${editingSettings.speed} vs ${appliedSettings.speed}',
//       'pitch: ${editingSettings.pitch} vs ${appliedSettings.pitch}',
//       'result: $hasChanges',
//     ]);
//     return hasChanges;
//   }
//
//   Future<void> applyEffects() async {
//     appliedSettings = editingSettings.copyWith();
//
//     if (!playback.isPlaying) {
//       notifyListeners();
//       return;
//     }
//
//     final position = playback.position;
//
//     if (currentPlaybackType == PlaybackType.master) {
//       await playMaster(seekAfterPlay: position);
//     } else {
//       await playSegment(currentSegmentIndex, seekAfterPlay: position);
//     }
//   }
//
//   void resetMasterSettings() {
//     editingSettings = MasterSettings();
//     notifyListeners();
//   }
//
//   void resetSplitSettings() {
//     splitSettings = SplitSettings();
//     notifyListeners();
//   }
//
//   void _onPlaybackComplete() {
//     if (isPlayingAll && currentSegmentIndex < segments.length - 1) {
//       playSegment(currentSegmentIndex + 1, continueAll: true);
//     } else {
//       isPlayingAll = false;
//       stopPlayback();
//     }
//   }
//
//   void setSpeed(double speed) {
//     editingSettings.speed = speed;
//     notifyListeners();
//   }
//
//   void setPitch(int pitch) {
//     editingSettings.pitch = pitch;
//     notifyListeners();
//   }
//
//   void setThreshold(double value) {
//     splitSettings.threshold = value;
//     notifyListeners();
//   }
//
//   void setMinSilence(double value) {
//     splitSettings.minSilence = value;
//     notifyListeners();
//   }
//
//   void setWindowMs(double value) {
//     splitSettings.windowMs = value;
//     notifyListeners();
//   }
//
//   Future<void> loadFile(String path, String name, String? mimeType) async {
//     isLoading = true;
//     progressMessage = 'جاري تحميل الملف...';
//     progressValue = 0.2;
//     notifyListeners();
//
//     try {
//       await stopPlayback();
//       segments = [];
//       segmentRanges = [];
//       silenceRanges = [];
//
//       progressMessage = 'جاري فك ترميز الصوت...';
//       progressValue = 0.5;
//       notifyListeners();
//
//       final buffer = await _decodeService.decodeFile(path);
//       audioBuffer = buffer;
//       fileName = name.replaceAll(RegExp(r'\.[^/.]+$'), '');
//       fileDisplayName = name;
//
//       playerSegmentName = 'الملف الكامل';
//       //
//       fileFormat = mimeType ?? 'audio';
//
//       _showToast(
//         '✅ تم تحميل الملف — اضبط التأثيرات ثم اضغط "اكتشاف الصمت"',
//         false,
//       );
//     } catch (e) {
//       _showToast('❌ خطأ في قراءة الملف: $e', true);
//       audioBuffer = null;
//     } finally {
//       isLoading = false;
//       progressMessage = '';
//       progressValue = 0;
//       notifyListeners();
//     }
//   }
//
//   Future<void> analyzeAndSplit() async {
//     if (audioBuffer == null) {
//       _showToast('❌ يرجى رفع ملف صوتي أولاً!', true);
//       return;
//     }
//
//     isLoading = true;
//     progressMessage = 'جاري تحليل الموجة الصوتية...';
//     progressValue = 0.3;
//     notifyListeners();
//
//     try {
//       final buffer = audioBuffer!;
//       final settings = splitSettings.copyWith();
//
//       final result = await Future(
//         () => _silenceDetector.analyze(buffer, settings),
//       );
//
//       silenceRanges = result.silenceRanges;
//       segmentRanges = result.segmentRanges;
//       segments = result.segments;
//
//       _showToast(
//         '✅ تم اكتشاف ${silenceRanges.length} فترة صمت → ${segments.length} مقطع!',
//         false,
//       );
//     } catch (e) {
//       _showToast('❌ خطأ في التحليل: $e', true);
//     } finally {
//       isLoading = false;
//       progressMessage = '';
//       progressValue = 0;
//       notifyListeners();
//     }
//   }
//
//   Future<void> playMaster({Duration? seekAfterPlay}) async {
//     if (audioBuffer == null) return;
//     await stopPlayback();
//
//     isLoading = true;
//     progressMessage = 'جاري تطبيق التأثيرات...';
//     notifyListeners();
//
//     try {
//       final processed = await Future(
//         () => SoundtouchProcessor.getProcessedBuffer(
//           audioBuffer!,
//           appliedSettings.speed,
//           appliedSettings.pitch,
//         ),
//       );
//
//       final file = await _exportService.bufferToTempWav(processed, 'master');
//       currentPlaybackType = PlaybackType.master;
//       currentSegmentIndex = -1;
//       playerSegmentName = 'الملف الكامل';
//       // showPlayer = true;
//       await playback.playFile(file);
//       if (seekAfterPlay != null) {
//         await playback.seek(seekAfterPlay);
//       }
//       notifyListeners();
//     } catch (e) {
//       Dev.console([e]);
//       _showToast('❌ خطأ في المعالجة: $e', true);
//     } finally {
//       isLoading = false;
//       progressMessage = '';
//       notifyListeners();
//     }
//   }
//
//   Future<void> playSegment(
//     int idx, {
//     bool continueAll = false,
//     Duration? seekAfterPlay,
//   }) async {
//     if (idx < 0 || idx >= segments.length) return;
//     if (!continueAll) {
//       await stopPlayback();
//       isPlayingAll = false;
//     }
//
//     try {
//       final seg = segments[idx];
//       final processed = await Future(
//         () => SoundtouchProcessor.getProcessedBuffer(
//           seg.buffer,
//           appliedSettings.speed,
//           appliedSettings.pitch,
//         ),
//       );
//       final file = await _exportService.bufferToTempWav(
//         processed,
//         'seg_${seg.index}',
//       );
//       currentPlaybackType = PlaybackType.segment;
//       currentSegmentIndex = idx;
//       playerSegmentName = 'المقطع ${seg.index}';
//       // showPlayer = true;
//       await playback.playFile(file);
//       if (seekAfterPlay != null) {
//         await playback.seek(seekAfterPlay);
//       }
//       notifyListeners();
//     } catch (e) {
//       _showToast('❌ خطأ في تشغيل المقطع', true);
//     }
//   }
//
//   Future<void> playAllSegments() async {
//     if (segments.isEmpty) return;
//     if (isPlayingAll) {
//       await stopPlayback();
//       return;
//     }
//     isPlayingAll = true;
//     await playSegment(0, continueAll: true);
//   }
//
//   Future<void> togglePlayback() async {
//     if (playback.isPlaying) {
//       await playback.pause();
//     } else if (playback.position > Duration.zero) {
//       await playback.resume();
//     } else if (currentSegmentIndex >= 0) {
//       await playSegment(currentSegmentIndex);
//     } else {
//       await playMaster();
//     }
//     notifyListeners();
//   }
//
//   Future<void> prevSegment() async {
//     if (currentSegmentIndex > 0) {
//       await playSegment(currentSegmentIndex - 1);
//     }
//   }
//
//   Future<void> nextSegment() async {
//     if (currentSegmentIndex < segments.length - 1) {
//       await playSegment(currentSegmentIndex + 1);
//     }
//   }
//
//   Future<void> stopPlayback() async {
//     isPlayingAll = false;
//     // showPlayer = false;
//     await playback.stop();
//     notifyListeners();
//   }
//
//   Future<void> downloadSegment(int idx) async {
//     if (idx < 0 || idx >= segments.length) return;
//     final seg = segments[idx];
//     isLoading = true;
//     progressMessage = 'جاري معالجة المقطع ${seg.index}...';
//     notifyListeners();
//
//     try {
//       final file = await _exportService.exportSegmentWav(
//         seg,
//         fileName,
//         appliedSettings,
//       );
//       await _exportService.shareFile(file);
//       _showToast('💾 تم تحميل المقطع ${seg.index}', false);
//     } catch (e) {
//       _showToast('❌ خطأ في تصدير المقطع', true);
//     } finally {
//       isLoading = false;
//       progressMessage = '';
//       notifyListeners();
//     }
//   }
//
//   Future<void> downloadAll() async {
//     if (segments.isEmpty) {
//       _showToast('❌ لا توجد مقاطع للتحميل', true);
//       return;
//     }
//
//     isLoading = true;
//     progressMessage = 'جاري معالجة المقاطع وتطبيق التأثيرات...';
//     notifyListeners();
//
//     try {
//       final zipFile = await _exportService.exportAllZip(
//         segments,
//         fileName,
//         appliedSettings,
//         (progress, message) {
//           progressValue = progress;
//           progressMessage = message;
//           notifyListeners();
//         },
//       );
//       await _exportService.shareFile(zipFile);
//       _showToast('✅ تم تحميل ${segments.length} مقطع في ملف ZIP', false);
//     } catch (e) {
//       _showToast('❌ خطأ في إنشاء ZIP: $e', true);
//     } finally {
//       isLoading = false;
//       progressMessage = '';
//       progressValue = 0;
//       notifyListeners();
//     }
//   }
//
//   void playAtTime(double time) {
//     for (var i = 0; i < segments.length; i++) {
//       if (time >= segments[i].startTime && time <= segments[i].endTime) {
//         playSegment(i);
//         return;
//       }
//     }
//   }
//
//   // void _showToast(String message, bool isError) {
//   //   toastMessage = message;
//   //   toastIsError = isError;
//   //   notifyListeners();
//   // }
//   void _showToast(String message, bool isError) {
//     if (isError) {
//       UiEventService.instance.showError(message);
//     } else {
//       UiEventService.instance.showSuccess(message);
//     }
//   }
//
//   // void clearToast() {
//   //   toastMessage = null;
//   //   notifyListeners();
//   // }
//
//   void updateDraggingProgress(double value) {
//     draggingProgress = value;
//     notifyListeners();
//   }
//
//   Future<void> seekTo(double value) async {
//     final duration = playback.duration;
//
//     if (duration <= Duration.zero) return;
//
//     draggingProgress = null;
//
//     final position = Duration(
//       milliseconds: (duration.inMilliseconds * value).round(),
//     );
//
//     await playback.seek(position);
//
//     notifyListeners();
//   }
//
//   double get playbackProgress {
//     if (draggingProgress != null) {
//       return draggingProgress!;
//     }
//
//     if (playback.duration.inMilliseconds == 0) {
//       return 0;
//     }
//
//     return (playback.position.inMilliseconds / playback.duration.inMilliseconds)
//         .clamp(0.0, 1.0);
//   }
//
//   @override
//   void dispose() {
//     playback.dispose();
//     super.dispose();
//   }
// }
