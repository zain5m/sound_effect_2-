import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

class PlaybackService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  void Function()? onComplete;
  void Function()? onStateChanged;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool hasLoadedFile = false;

  // Future<void> playFile(File file) async {
  //   await stop();
  //   await _player.setFilePath(file.path);
  //   duration = _player.duration ?? Duration.zero;
  //   _positionSub = positionStream.listen((pos) {
  //     position = pos;
  //     onStateChanged?.call();
  //   });
  //   _stateSub = playerStateStream.listen((state) {
  //     isPlaying = state.playing;
  //     if (state.processingState == ProcessingState.completed) {
  //       isPlaying = false;
  //       onComplete?.call();
  //     }
  //     onStateChanged?.call();
  //   });
  //   await _player.play();
  //   isPlaying = true;
  //   onStateChanged?.call();
  // }
  Future<void> loadFile(File file) async {
    await stop();

    await _player.setFilePath(file.path);

    duration = _player.duration ?? Duration.zero;
    position = Duration.zero;
    hasLoadedFile = true;
    _positionSub = positionStream.listen((pos) {
      position = pos;
      onStateChanged?.call();
    });

    _stateSub = playerStateStream.listen((state) {
      isPlaying = state.playing;

      if (state.processingState == ProcessingState.completed) {
        isPlaying = false;
        onComplete?.call();
      }

      onStateChanged?.call();
    });

    onStateChanged?.call();
  }

  Future<void> play() async {
    if (!hasLoadedFile) return;

    await _player.play();

    isPlaying = true;
    onStateChanged?.call();
  }

  Future<void> playFile(File file) async {
    await loadFile(file);
    await play();
  }

  Future<void> pause() async {
    await _player.pause();
    isPlaying = false;
    onStateChanged?.call();
  }

  Future<void> resume() async {
    await _player.play();
    isPlaying = true;
    onStateChanged?.call();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    _positionSub = null;
    _stateSub = null;
    await _player.stop();
    hasLoadedFile = false;

    isPlaying = false;
    position = Duration.zero;
    onStateChanged?.call();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
