import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/pcm_audio_buffer.dart';
import 'audio_decode_service.dart';
import 'export_service.dart';

class PlaybackService {
  static const _native = MethodChannel('sound_effect_2/realtime_audio');
  static const _events = EventChannel('sound_effect_2/realtime_audio/events');
  final _positions = StreamController<Duration>.broadcast();
  final _states = StreamController<PlayerState>.broadcast();
  AudioPlayer? _player;
  StreamSubscription<dynamic>? _nativeSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  Future<void> _operations = Future.value();
  PcmAudioBuffer? _buffer;
  int _generation = 0;
  double _speed = 1;
  int _pitch = 0;
  double _renderSpeed = 1;
  bool _completed = false;
  bool _disposed = false;

  bool isPlaying = false;
  bool hasLoadedFile = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  void Function()? onComplete;
  void Function()? onStateChanged;
  void Function(Object error)? onError;

  bool get supportsRealtime => Platform.isAndroid;
  Stream<Duration> get positionStream => _positions.stream;
  Stream<PlayerState> get playerStateStream => _states.stream;

  PlaybackService() {
    if (supportsRealtime) {
      _nativeSub = _events.receiveBroadcastStream().listen(
        _onNativeState,
        onError: _reportError,
      );
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.catchError((Object _) {});
    return operation;
  }

  bool _isCurrent(int id) => !_disposed && id == _generation;

  void _notify() {
    if (_disposed) return;
    _positions.add(position);
    _states.add(
      PlayerState(
        isPlaying,
        _completed
            ? ProcessingState.completed
            : hasLoadedFile
            ? ProcessingState.ready
            : ProcessingState.idle,
      ),
    );
    onStateChanged?.call();
  }

  void _reportError(Object error) {
    if (_disposed) return;
    isPlaying = false;
    _notify();
    onError?.call(error);
  }

  void _onNativeState(dynamic event) {
    if (event is! Map || !_isCurrent(event['id'] as int)) return;
    final wasCompleted = _completed;
    isPlaying = event['playing'] == true;
    hasLoadedFile = event['loaded'] == true;
    position = Duration(microseconds: event['positionUs'] as int);
    duration = Duration(microseconds: event['durationUs'] as int);
    _completed = event['completed'] == true;
    _notify();
    if (event['error'] != null) {
      onError?.call(StateError(event['error'] as String));
    }
    if (_completed && !wasCompleted) onComplete?.call();
  }

  Future<void> loadBuffer(
    PcmAudioBuffer buffer, {
    required double speed,
    required int pitch,
  }) {
    if (_disposed) return Future.value();
    final id = ++_generation;
    _buffer = buffer;
    _speed = speed;
    _pitch = pitch;
    isPlaying = false;
    hasLoadedFile = false;
    _completed = false;
    position = Duration.zero;
    duration = Duration(microseconds: (buffer.duration * 1000000).round());
    return _enqueue(() async {
      if (!_isCurrent(id)) return;
      if (supportsRealtime) {
        await _native.invokeMethod<void>('load', {
          'id': id,
          'sampleRate': buffer.sampleRate,
          'frames': buffer.length,
          'channels': buffer.channelData
              .map(
                (channel) => Uint8List.view(
                  channel.buffer,
                  channel.offsetInBytes,
                  channel.lengthInBytes,
                ),
              )
              .toList(),
          'speed': _speed,
          'pitch': _pitch,
        });
      } else {
        await _loadFallback(buffer, id, _speed, _pitch);
      }
      if (!_isCurrent(id)) return;
      hasLoadedFile = true;
      _notify();
    });
  }

  Future<void> _loadFallback(
    PcmAudioBuffer buffer,
    int id,
    double speed,
    int pitch,
  ) async {
    final player = _player ??= AudioPlayer();
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await player.stop();
    final file = await ExportService().bufferToTempWav(
      buffer,
      'playback',
      speed: speed,
      pitch: pitch,
    );
    if (!_isCurrent(id)) return;
    await player.setFilePath(file.path);
    if (!_isCurrent(id)) return;
    _renderSpeed = speed;
    _completed = false;
    _positionSub = player.positionStream.listen((value) {
      if (!_isCurrent(id)) return;
      position = Duration(
        microseconds: (value.inMicroseconds * _renderSpeed).round(),
      );
      _notify();
    });
    _stateSub = player.playerStateStream.listen((state) {
      if (!_isCurrent(id)) return;
      final ended = state.processingState == ProcessingState.completed;
      final newlyCompleted = ended && !_completed;
      _completed = ended;
      isPlaying = state.playing && !ended;
      _notify();
      if (newlyCompleted) onComplete?.call();
    });
  }

  Future<void> setParameters(double speed, int pitch) {
    if (_disposed) return Future.value();
    if (!speed.isFinite ||
        speed < 0.5 ||
        speed > 2 ||
        pitch < -12 ||
        pitch > 12) {
      return Future.error(ArgumentError('Invalid pitch or speed'));
    }
    final changed = _speed != speed || _pitch != pitch;
    _speed = speed;
    _pitch = pitch;
    if (supportsRealtime) {
      return _native.invokeMethod<void>('setParameters', {
        'speed': speed,
        'pitch': pitch,
      });
    }
    final buffer = _buffer;
    final id = _generation;
    if (!changed || buffer == null) return Future.value();
    return _enqueue(() async {
      if (!_isCurrent(id)) return;
      final wasPlaying = isPlaying;
      final savedPosition = position;
      await _loadFallback(buffer, id, _speed, _pitch);
      if (!_isCurrent(id)) return;
      await _player!.seek(
        Duration(
          microseconds: (savedPosition.inMicroseconds / _renderSpeed).round(),
        ),
      );
      if (!_isCurrent(id)) return;
      if (wasPlaying) _playFallback(id);
      _notify();
    });
  }

  void _playFallback(int id) {
    unawaited(
      _player!.play().catchError((Object error) {
        if (_isCurrent(id)) _reportError(error);
      }),
    );
  }

  Future<void> loadFile(File file) async {
    final buffer = await AudioDecodeService().decodeFile(file.path);
    await loadBuffer(buffer, speed: _speed, pitch: _pitch);
  }

  Future<void> play() {
    final id = _generation;
    return _enqueue(() async {
      if (!_isCurrent(id) || !hasLoadedFile) return;
      if (supportsRealtime) {
        await _native.invokeMethod<void>('play', {'id': id});
      } else {
        _playFallback(id);
      }
    });
  }

  Future<void> playFile(File file) async {
    await loadFile(file);
    await play();
  }

  Future<void> pause() {
    final id = _generation;
    return _enqueue(() async {
      if (!_isCurrent(id)) return;
      if (supportsRealtime) {
        await _native.invokeMethod<void>('pause', {'id': id});
      } else {
        await _player?.pause();
      }
    });
  }

  Future<void> resume() => play();

  Future<void> seek(Duration value) {
    final id = _generation;
    return _enqueue(() async {
      if (!_isCurrent(id) || !hasLoadedFile) return;
      final micros = value.inMicroseconds.clamp(0, duration.inMicroseconds);
      if (supportsRealtime) {
        await _native.invokeMethod<void>('seek', {
          'id': id,
          'positionUs': micros,
        });
      } else {
        await _player?.seek(
          Duration(microseconds: (micros / _renderSpeed).round()),
        );
      }
    });
  }

  Future<void> stop() {
    if (_disposed) return Future.value();
    final id = ++_generation;
    _buffer = null;
    isPlaying = false;
    hasLoadedFile = false;
    _completed = false;
    position = Duration.zero;
    duration = Duration.zero;
    _notify();
    return _enqueue(() async {
      if (!_isCurrent(id)) return;
      if (supportsRealtime) {
        await _native.invokeMethod<void>('stop', {'id': id});
      } else {
        await _positionSub?.cancel();
        await _stateSub?.cancel();
        await _player?.stop();
      }
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    onComplete = null;
    onStateChanged = null;
    onError = null;
    await _enqueue(() async {
      if (supportsRealtime) {
        await _native.invokeMethod<void>('dispose', {'id': _generation});
      }
      await _nativeSub?.cancel();
      await _positionSub?.cancel();
      await _stateSub?.cancel();
      await _player?.dispose();
      await _positions.close();
      await _states.close();
      _buffer = null;
    });
  }
}
