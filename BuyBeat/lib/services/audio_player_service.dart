import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'audio_handler.dart';
import '../models/beat.dart';

enum RepeatMode { off, all, one }

/// Global singleton audio player — ensures only ONE beat plays at a time.
/// Интегрирован с системным медиаплеером Android через audio_service.
/// Handler гарантированно инициализируется в main() до запуска UI.
class AudioPlayerService {
  AudioPlayerService._();
  static final AudioPlayerService instance = AudioPlayerService._();

  /// AudioHandler (от audio_service). Устанавливается ОБЯЗАТЕЛЬНО в main().
  late BuyBeatAudioHandler _handler;

  /// Текущий AudioPlayer — всегда из handler.
  AudioPlayer get _player => _handler.player;

  /// Установить handler после инициализации audio_service.
  void setHandler(BuyBeatAudioHandler handler) {
    _handler = handler;
    handler.onSkipTrack = (delta) => skipTrack(delta);

    // Подписываемся на стримы handler-плеера
    final p = handler.player;
    p.playerStateStream.listen((s) {
      if (!_playerStateCtrl.isClosed) _playerStateCtrl.add(s);
    });
    p.positionStream.listen((pos) {
      if (!_posCtrl.isClosed) _posCtrl.add(pos);
    });
    p.durationStream.listen((d) {
      if (!_durCtrl.isClosed) _durCtrl.add(d);
    });
    _setupAutoAdvance(p);
    debugPrint('AudioPlayerService: handler set, using audio_service player');
  }

  bool get isInitialized => true;

  Beat? _currentBeat;
  Beat? get currentBeat => _currentBeat;
  bool get isPlaying =>
      _player.playing && _player.processingState != ProcessingState.completed;

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

  // ─── Streams (broadcast — safe to listen before handler is ready) ─
  final _playerStateCtrl = StreamController<PlayerState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();

  Stream<PlayerState> get playerStateStream => _playerStateCtrl.stream;
  Stream<Duration> get positionStream => _posCtrl.stream;
  Stream<Duration?> get durationStream => _durCtrl.stream;

  ProcessingState get processingState => _player.processingState;

  /// Auto-advance listener
  final Set<int> _autoAdvanceIds = {};

  void _setupAutoAdvance(AudioPlayer p) {
    final id = identityHashCode(p);
    if (_autoAdvanceIds.contains(id)) return;
    _autoAdvanceIds.add(id);
    p.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _repeatMode != RepeatMode.one) {
        if (hasNext || _repeatMode == RepeatMode.all) {
          skipTrack(1);
        }
      }
    });
  }

  Future<void> play(Beat beat) async {
    _currentBeat = beat;
    final url = beat.audioPreviewUrl;
    if (url == null || url.isEmpty) return;

    // Обновляем метаданные для системного плеера (обложка, название, артист)
    final artistName = beat.producerName ?? 'BuyBeat';
    await _handler.setCurrentTrack(
      title: beat.title,
      artist: artistName,
      artworkUrl: beat.coverUrl,
      duration: beat.durationSeconds != null
          ? Duration(seconds: beat.durationSeconds!)
          : null,
    );

    try {
      await _handler.playUrl(url);
    } catch (e) {
      debugPrint('AudioPlayerService.play error: $e');
    }
  }

  /// Toggle play/pause for the current beat, or play a new one.
  Future<void> playPause({Beat? beat}) async {
    if (beat != null && (_currentBeat == null || beat.id != _currentBeat!.id)) {
      await play(beat);
      return;
    }
    if (_player.playing) {
      await _handler.pause();
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
      await _handler.play();
    }
  }

  Future<void> pause() async {
    await _handler.pause();
  }

  Future<void> resume() async {
    await _handler.play();
  }

  Future<void> seek(Duration position) async {
    await _handler.seek(position);
  }

  Future<void> stop() async {
    _currentBeat = null;
    await _handler.stop();
  }

  void dispose() {
    _player.dispose();
    _playerStateCtrl.close();
    _posCtrl.close();
    _durCtrl.close();
  }
}
