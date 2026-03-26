import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import '../config/glass_theme.dart';
import '../models/beat.dart' as models;
import '../services/audio_player_service.dart';
import 'package:just_audio/just_audio.dart';

class GlobalPlayerBar extends StatefulWidget {
  const GlobalPlayerBar({super.key});

  @override
  State<GlobalPlayerBar> createState() => _GlobalPlayerBarState();
}

class _GlobalPlayerBarState extends State<GlobalPlayerBar> {
  final _audio = AudioPlayerService.instance;

  models.Beat? _nowPlaying;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  DateTime _lastPosUpdate = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _playerSub = _audio.playerStateStream.listen((state) {
      final playing = state.playing && state.processingState != ProcessingState.completed;
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          _nowPlaying = _audio.currentBeat;
        });
      }
    });
    _posSub = _audio.positionStream.listen((p) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.difference(_lastPosUpdate).inMilliseconds < 250) return;
      _lastPosUpdate = now;
      setState(() => _position = p);
    });
    _durSub = _audio.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _nowPlaying = _audio.currentBeat;
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  bool get _canPrev => _audio.hasPrev || _audio.repeatMode == RepeatMode.all;
  bool get _canNext => _audio.hasNext || _audio.repeatMode == RepeatMode.all;

  @override
  Widget build(BuildContext context) {
    if (_nowPlaying == null) return const SizedBox.shrink();

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => _openNowPlaying(context),
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -400 && _canNext) _skipTrack(1);
        if (v > 400 && _canPrev) _skipTrack(-1);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101015).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: 0.08)),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: const BoxDecoration(gradient: LG.accentGradient),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _coverImg(44),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _nowPlaying!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LG.font(weight: FontWeight.w700, size: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _subtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LG.font(size: 11, color: LG.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // Prev — dimmed when unavailable
                      IconButton(
                        onPressed: _canPrev ? () => _skipTrack(-1) : null,
                        icon: Icon(Icons.skip_previous_rounded,
                            color: _canPrev ? LG.textSecondary : LG.textSecondary.withValues(alpha: 0.25),
                            size: 22),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      // Play/Pause
                      IconButton(
                        onPressed: () => _audio.playPause(),
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: LG.accent,
                        ),
                        iconSize: 38,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                      // Next — dimmed when unavailable
                      IconButton(
                        onPressed: _canNext ? () => _skipTrack(1) : null,
                        icon: Icon(Icons.skip_next_rounded,
                            color: _canNext ? LG.textSecondary : LG.textSecondary.withValues(alpha: 0.25),
                            size: 22),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      // Close
                      IconButton(
                        onPressed: _closePlayer,
                        icon: Icon(Icons.close, color: LG.textMuted, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (_nowPlaying!.genreName != null && _nowPlaying!.genreName!.isNotEmpty) {
      parts.add(_nowPlaying!.genreName!);
    }
    if (_nowPlaying!.producerName != null && _nowPlaying!.producerName!.isNotEmpty) {
      parts.add(_nowPlaying!.producerName!);
    }
    return parts.join(' · ');
  }

  Widget _coverImg(double s) {
    if (_nowPlaying!.coverUrl != null && _nowPlaying!.coverUrl!.isNotEmpty) {
      return Image.network(
        _nowPlaying!.coverUrl!,
        width: s, height: s, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(s),
      );
    }
    return _placeholder(s);
  }

  Widget _placeholder(double s) => Container(
        width: s, height: s,
        decoration: BoxDecoration(color: LG.bgLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.music_note, color: LG.textMuted, size: s * 0.45),
      );

  void _closePlayer() {
    _audio.stop();
    if (mounted) setState(() => _nowPlaying = null);
  }

  void _skipTrack(int delta) => _audio.skipTrack(delta);

  void _openNowPlaying(BuildContext context) {
    if (_nowPlaying == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NowPlayingSheet(),
    );
  }
}

// ─── Full-screen Now Playing Sheet ───────────────────────────────

class _NowPlayingSheet extends StatefulWidget {
  const _NowPlayingSheet();
  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet> {
  final _audio = AudioPlayerService.instance;

  models.Beat? _beat;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  RepeatMode _repeatMode = RepeatMode.off;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<RepeatMode>? _repeatSub;

  @override
  void initState() {
    super.initState();
    _beat = _audio.currentBeat;
    _isPlaying = _audio.isPlaying;
    _repeatMode = _audio.repeatMode;

    _posSub = _audio.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _audio.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _stateSub = _audio.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s.playing && s.processingState != ProcessingState.completed;
        final fresh = _audio.currentBeat;
        if (fresh != null) _beat = fresh;
      });
    });
    _repeatSub = _audio.repeatModeStream.listen((m) {
      if (mounted) setState(() => _repeatMode = m);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _repeatSub?.cancel();
    super.dispose();
  }

  bool get _canPrev => _audio.hasPrev || _repeatMode == RepeatMode.all;
  bool get _canNext => _audio.hasNext || _repeatMode == RepeatMode.all;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -400 && _canNext) _audio.skipTrack(1);
    if (v > 400 && _canPrev) _audio.skipTrack(-1);
  }

  IconData get _repeatIcon {
    switch (_repeatMode) {
      case RepeatMode.off: return Icons.repeat;
      case RepeatMode.all: return Icons.repeat;
      case RepeatMode.one: return Icons.repeat_one;
    }
  }

  Color get _repeatColor {
    return _repeatMode == RepeatMode.off ? LG.textMuted : LG.accent;
  }

  @override
  Widget build(BuildContext context) {
    final beat = _beat;
    if (beat == null) return const SizedBox.shrink();

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final prevColor = _canPrev ? LG.textSecondary : LG.textSecondary.withValues(alpha: 0.2);
    final nextColor = _canNext ? LG.textSecondary : LG.textSecondary.withValues(alpha: 0.2);

    return GestureDetector(
      onHorizontalDragEnd: _onSwipe,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          // Cover
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: ClipRRect(
              key: ValueKey(beat.id),
              borderRadius: BorderRadius.circular(20),
              child: beat.coverUrl != null && beat.coverUrl!.isNotEmpty
                  ? Image.network(beat.coverUrl!, width: 240, height: 240, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPh())
                  : _coverPh(),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(beat.title, key: ValueKey('${beat.id}_title'), style: LG.h3, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              key: ValueKey('${beat.id}_sub'),
              [
                if (beat.genreName?.isNotEmpty == true) beat.genreName!,
                if (beat.producerName?.isNotEmpty == true) beat.producerName!,
              ].join(' · '),
              style: LG.font(size: 13, color: LG.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          // Progress
          Column(children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: LG.accent,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
                thumbColor: LG.accent,
                overlayColor: LG.accent.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: progress.toDouble(),
                onChanged: (v) => _audio.seek(Duration(milliseconds: (_duration.inMilliseconds * v).round())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_fmt(_position), style: LG.font(size: 11, color: LG.textMuted)),
                Text(_fmt(_duration), style: LG.font(size: 11, color: LG.textMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Controls row with repeat
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Repeat mode toggle
            IconButton(
              onPressed: () => _audio.cycleRepeatMode(),
              icon: Icon(_repeatIcon, color: _repeatColor, size: 24),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            // Prev
            IconButton(
              onPressed: _canPrev ? () => _audio.skipTrack(-1) : null,
              icon: Icon(Icons.skip_previous_rounded, color: prevColor),
              iconSize: 36,
            ),
            const SizedBox(width: 16),
            // Play/Pause
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LG.accentGradient,
                boxShadow: [BoxShadow(color: LG.accent.withValues(alpha: 0.4), blurRadius: 20)],
              ),
              child: IconButton(
                onPressed: () => _audio.playPause(),
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF0A0A0F), size: 32),
              ),
            ),
            const SizedBox(width: 16),
            // Next
            IconButton(
              onPressed: _canNext ? () => _audio.skipTrack(1) : null,
              icon: Icon(Icons.skip_next_rounded, color: nextColor),
              iconSize: 36,
            ),
            // Spacer to balance repeat button
            const SizedBox(width: 48),
          ]),
        ]),
      ),
    );
  }

  Widget _coverPh() => Container(
        width: 240, height: 240,
        decoration: BoxDecoration(color: LG.bgLight, borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.music_note, color: LG.textMuted, size: 80),
      );
}
