import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'audio_handler.dart';
import '../models/beat.dart';

enum RepeatMode { off, all, one }

/// Global singleton audio player — ensures only ONE beat plays at a time.
/// Интегрирован с системным медиаплеером Android через audio_service.
/// Если audio_service не инициализирован — работает напрямую через just_audio.
class AudioPlayerService {
  AudioPlayerService._();
  static final AudioPlayerService instance = AudioPlayerService._();

  /// AudioHandler (от audio_service). Может быть null если init не прошёл.
  BuyBeatAudioHandler? _handler;

  /// Fallback-плеер: используется если audio_service не инициализирован.
  final AudioPlayer _fallbackPlayer = AudioPlayer();
  bool _fallbackStreamsSetUp = false;

  /// Текущий AudioPlayer — из handler или fallback.
  AudioPlayer get _player => _handler?.player ?? _fallbackPlayer;

  void _ensureFallbackStreams() {
    if (_fallbackStreamsSetUp) return;
    _fallbackStreamsSetUp = true;
    _fallbackPlayer.playerStateStream.listen((s) => _playerStateCtrl.add(s));
    _fallbackPlayer.positionStream.listen((p) => _posCtrl.add(p));
    _fallbackPlayer.durationStream.listen((d) => _durCtrl.add(d));
    _setupAutoAdvance(_fallbackPlayer);
  }

  /// Установить handler после инициализации audio_service.
  void setHandler(BuyBeatAudioHandler handler) {
    _handler = handler;
    handler.onSkipTrack = (delta) => skipTrack(delta);

    final p = handler.player;
    // Переключаем стримы на handler-плеер
    p.playerStateStream.listen((s) => _playerStateCtrl.add(s));
    p.positionStream.listen((p) => _posCtrl.add(p));
    p.durationStream.listen((d) => _durCtrl.add(d));
    _setupAutoAdvance(p);
    debugPrint('AudioPlayerService: handler set, using audio_service player');
  }

  bool get isInitialized => true; // всегда работает — fallback или handler

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
    _ensureFallbackStreams();
    _currentBeat = beat;
    final url = beat.audioPreviewUrl;
    if (url == null || url.isEmpty) return;

    // Обновляем метаданные для системного плеера (обложка, название, артист)
    if (_handler != null) {
      final artistName = beat.producerName ?? 'BuyBeat';
      await _handler!.setCurrentTrack(
        title: beat.title,
        artist: artistName,
        artworkUrl: beat.coverUrl,
        duration: beat.durationSeconds != null
            ? Duration(seconds: beat.durationSeconds!)
            : null,
      );
    }

    try {
      if (_handler != null) {
        await _handler!.playUrl(url);
      } else {
        await _player.setUrl(url);
        await _player.play();
      }
    } catch (e) {
      debugPrint('AudioPlayerService.play error: $e');
    }
  }

  /// Toggle play/pause for the current beat, or play a new one.
  Future<void> playPause({Beat? beat}) async {
    _ensureFallbackStreams();
    if (beat != null && (_currentBeat == null || beat.id != _currentBeat!.id)) {
      await play(beat);
      return;
    }
    if (_player.playing) {
      if (_handler != null) {
        await _handler!.pause();
      } else {
        await _player.pause();
      }
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
      if (_handler != null) {
        await _handler!.play();
      } else {
        await _player.play();
      }
    }
  }

  Future<void> pause() async {
    if (_handler != null) {
      await _handler!.pause();
    } else {
      await _player.pause();
    }
  }

  Future<void> resume() async {
    if (_handler != null) {
      await _handler!.play();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    if (_handler != null) {
      await _handler!.seek(position);
    } else {
      await _player.seek(position);
    }
  }

  Future<void> stop() async {
    _currentBeat = null;
    if (_handler != null) {
      await _handler!.stop();
    } else {
      await _player.stop();
    }
  }

  void dispose() {
    _player.dispose();
    _playerStateCtrl.close();
    _posCtrl.close();
    _durCtrl.close();
  }
}
