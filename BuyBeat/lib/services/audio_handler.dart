import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// AudioHandler для интеграции с системным медиаплеером Android.
/// Обрабатывает MediaSession: уведомление на шторке, экран блокировки,
/// кнопки наушников, кнопки на уведомлении (play/pause/prev/next).
///
/// Паттерн из demo: один AudioPlayer внутри handler,
/// _broadcastState() пушит PlaybackState при каждом событии.
class BuyBeatAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  /// Колбэк для переключения треков (prev/next) — устанавливается из AudioPlayerService.
  void Function(int delta)? onSkipTrack;

  BuyBeatAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Настраиваем audio session (фокус аудио, утихание других приложений)
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Транслируем события just_audio → PlaybackState для MediaSession
    _player.playbackEventStream.listen(_broadcastState);

    // Обновляем длительность в MediaItem когда плеер её узнаёт (нужно для
    // шторки Android — без актуальной длительности перемотка не отображается).
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });

    // Отслеживаем завершение трека
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Сообщаем системе что воспроизведение завершено
        _broadcastState(_player.playbackEvent);
      }
    });
  }

  // ─── Управление воспроизведением ─────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    // Дожидаемся перехода в idle, но с таймаутом чтобы не зависнуть на Realme/ColorOS
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle)
        .timeout(const Duration(seconds: 3), onTimeout: () => playbackState.value);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    onSkipTrack?.call(1);
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipTrack?.call(-1);
  }

  // ─── Обновление метаданных трека для системного плеера ────────────

  /// Устанавливает информацию о текущем треке (название, артист, обложка).
  Future<void> setCurrentTrack({
    required String title,
    required String artist,
    String? artworkUrl,
    Duration? duration,
  }) async {
    final item = MediaItem(
      id: title,
      title: title,
      artist: artist,
      duration: duration,
      artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
    );
    mediaItem.add(item);
  }

  /// Generation counter — incremented on every playUrl call.
  /// Lets us detect and bail out of stale concurrent requests.
  int _playGeneration = 0;

  /// Загружает URL и начинает воспроизведение.
  /// Сначала приостанавливаем старое аудио, чтобы избежать перекрытия на Web.
  /// После загрузки обновляем длительность в MediaItem — без этого шторка
  /// Android не показывает полосу перемотки.
  Future<void> playUrl(String url) async {
    final generation = ++_playGeneration;
    // Stop current playback immediately so old audio goes silent right away.
    await _player.stop();
    if (generation != _playGeneration) return; // superseded by newer call
    final duration = await _player.setUrl(url);
    if (generation != _playGeneration) return; // superseded by newer call
    // Обновляем duration в MediaItem чтобы шторка показала полосу перемотки.
    final current = mediaItem.value;
    if (current != null && duration != null) {
      mediaItem.add(current.copyWith(duration: duration));
    }
    await _player.play();
  }

  // Кастомная кнопка закрытия с иконкой крестика вместо квадрата
  static const _closeControl = MediaControl(
    androidIcon: 'drawable/ic_close',
    label: 'Close',
    action: MediaAction.stop,
  );

  // ─── Трансляция состояния just_audio → MediaSession ──────────────

  /// По паттерну из demo: формируем полный PlaybackState с controls.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        _closeControl,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
