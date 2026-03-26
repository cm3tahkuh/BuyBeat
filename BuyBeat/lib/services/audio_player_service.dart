import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../models/beat.dart';

enum RepeatMode { off, all, one }

/// Global singleton audio player — ensures only ONE beat plays at a time.
class AudioPlayerService {
  AudioPlayerService._();
  static final AudioPlayerService instance = AudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();

  Beat? _currentBeat;
  Beat? get currentBeat => _currentBeat;
  bool get isPlaying => _player.playing && _player.processingState != ProcessingState.completed;

  // Repeat mode
  RepeatMode _repeatMode = RepeatMode.off;
  RepeatMode get repeatMode => _repeatMode;
  final _repeatModeController = StreamController<RepeatMode>.broadcast();
  Stream<RepeatMode> get repeatModeStream => _repeatModeController.stream;

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off: _repeatMode = RepeatMode.all;
      case RepeatMode.all: _repeatMode = RepeatMode.one;
      case RepeatMode.one: _repeatMode = RepeatMode.off;
    }
    if (_repeatMode == RepeatMode.one) {
      _player.setLoopMode(LoopMode.one);
    } else {
      _player.setLoopMode(LoopMode.off);
    }
    _repeatModeController.add(_repeatMode);
  }

  // Queue for prev/next navigation
  List<Beat> _queue = [];
  List<Beat> get queue => List.unmodifiable(_queue);
  void setQueue(List<Beat> beats) => _queue = List.of(beats);

  bool get hasPrev {
    if (_currentBeat == null || _queue.isEmpty) return false;
    final idx = _queue.indexWhere((b) => b.id == _currentBeat!.id);
    return idx > 0;
  }

  bool get hasNext {
    if (_currentBeat == null || _queue.isEmpty) return false;
    final idx = _queue.indexWhere((b) => b.id == _currentBeat!.id);
    return idx >= 0 && idx < _queue.length - 1;
  }

  Future<void> skipTrack(int delta) async {
    if (_currentBeat == null || _queue.isEmpty) return;
    final idx = _queue.indexWhere((b) => b.id == _currentBeat!.id);
    if (idx == -1) return;
    int next = idx + delta;
    if (_repeatMode == RepeatMode.all) {
      next = next % _queue.length;
    } else {
      next = next.clamp(0, _queue.length - 1);
      if (next == idx) return;
    }
    await play(_queue[next]);
  }

  // ─── Streams ──────────────────────────────────────────────────────
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  ProcessingState get processingState => _player.processingState;

  /// Auto-advance (only set up once for the singleton lifetime)
  bool _autoAdvanceSetUp = false;

  Future<void> play(Beat beat) async {
    if (!_autoAdvanceSetUp) {
      _autoAdvanceSetUp = true;
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && _repeatMode != RepeatMode.one) {
          if (hasNext || _repeatMode == RepeatMode.all) {
            skipTrack(1);
          }
        }
      });
    }
    _currentBeat = beat;
    final url = beat.audioPreviewUrl;
    if (url == null || url.isEmpty) return;
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {}
  }

  /// Toggle play/pause for the current beat, or play a new one.
  Future<void> playPause({Beat? beat}) async {
    if (beat != null && (_currentBeat == null || beat.id != _currentBeat!.id)) {
      await play(beat);
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle ||
          _player.processingState == ProcessingState.completed) {
        if (_currentBeat != null) {
          final url = _currentBeat!.audioPreviewUrl;
          if (url != null && url.isNotEmpty) {
            try { await _player.setUrl(url); } catch (_) {}
          }
        }
      }
      await _player.play();
    }
  }

  Future<void> pause() async => await _player.pause();
  Future<void> resume() async => await _player.play();
  Future<void> seek(Duration position) async => await _player.seek(position);

  Future<void> stop() async {
    _currentBeat = null;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
