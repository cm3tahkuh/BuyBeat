import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../config/glass_theme.dart';
import '../models/beat.dart';
import '../models/beat_file.dart';
import '../services/audio_player_service.dart';
import '../services/beat_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../services/favorite_service.dart';
import 'cart_screen.dart';
import 'edit_beat_screen.dart';
import 'user_profile_screen.dart';

const _moodRu = {
  'aggressive': 'Агрессивный', 'calm': 'Спокойный', 'dark': 'Тёмный',
  'energetic': 'Энергичный', 'happy': 'Весёлый', 'melancholic': 'Меланхоличный',
  'romantic': 'Романтичный', 'sad': 'Грустный', 'uplifting': 'Воодушевляющий',
  'chill': 'Чилл',
};
String _translateMood(String m) => _moodRu[m.toLowerCase()] ?? m;

class BeatDetailScreen extends StatefulWidget {
  final Beat beat;
  final void Function(int producerId, String producerName)? onMessageProducer;
  const BeatDetailScreen({super.key, required this.beat, this.onMessageProducer});
  @override
  State<BeatDetailScreen> createState() => _BeatDetailScreenState();
}

class _BeatDetailScreenState extends State<BeatDetailScreen> {
  final _audio = AudioPlayerService.instance;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  List<BeatFile> _beatFiles = [];
  bool _loadingFiles = true;
  bool _isOwnBeat = false;
  Set<int> _purchasedBeatFileIds = {};
  late Beat _beat = widget.beat;
  Beat get beat => _beat;
  bool _wasEdited = false;
  bool _playTracked = false; // фиксируем прослушивание только один раз за сессию
  final _favService = FavoriteService.instance;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  DateTime _lastPosUpdate = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _stateSub = _audio.playerStateStream.listen((s) {
      if (!mounted) return;
      final nowPlaying = _audio.currentBeat?.id == beat.id;
      final isActuallyPlaying = nowPlaying && s.playing && s.processingState != ProcessingState.completed;
      setState(() => _isPlaying = isActuallyPlaying);
      // Фиксируем прослушивание один раз при начале воспроизведения
      if (isActuallyPlaying && !_playTracked && beat.documentId != null) {
        _playTracked = true;
        BeatService.instance.incrementPlayCount(beat.documentId!).then((newCount) {
          if (newCount != null && mounted) {
            setState(() => _beat = _beat.copyWith(playCount: newCount));
          }
        });
      }
    });
    _posSub = _audio.positionStream.listen((p) {
      if (!mounted || _audio.currentBeat?.id != beat.id) return;
      // Throttle to max 4fps to avoid overwhelming the main thread
      final now = DateTime.now();
      if (now.difference(_lastPosUpdate).inMilliseconds < 250) return;
      _lastPosUpdate = now;
      setState(() => _position = p);
    });
    _durSub = _audio.durationStream.listen((d) {
      if (mounted && _audio.currentBeat?.id == beat.id) setState(() => _duration = d);
    });
    _loadBeatFiles();
    _checkOwnership();
    _loadPurchasedIds();
    _favService.addListener(_onFavChanged);
  }

  void _onFavChanged() {
    if (mounted) setState(() {});
  }

  void _checkOwnership() {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId != null && beat.producerId == currentUserId) {
      setState(() => _isOwnBeat = true);
    }
  }

  Future<void> _loadPurchasedIds() async {
    try {
      final ids = await PurchaseService.instance.getMyPurchasedBeatFileIds();
      if (mounted) setState(() => _purchasedBeatFileIds = ids);
    } catch (_) {}
  }

  Future<void> _loadBeatFiles() async {
    try {
      final files = await BeatService.instance.getBeatFiles(beat.id);
      if (mounted) setState(() { _beatFiles = files; _loadingFiles = false; });
    } catch (_) { if (mounted) setState(() => _loadingFiles = false); }
  }

  Future<void> _playPause() async {
    _audio.playPause(beat: beat);
  }

  void _openProducerProfile() {
    final pid = beat.producerId;
    if (pid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: pid),
      ),
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _favService.removeListener(_onFavChanged);
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _editBeat() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditBeatScreen(beat: beat)),
    );
    if (result == true && mounted) {
      _wasEdited = true;
      // Перезагружаем бит с сервера, чтобы теги и другие данные обновились
      try {
        final fresh = await BeatService.instance.getBeatById(beat.id);
        if (fresh != null && mounted) {
          setState(() => _beat = fresh);
          _loadBeatFiles(); // перезагрузить файлы тоже
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteBeat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LG.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить бит?', style: LG.font(weight: FontWeight.w700, size: 18)),
        content: Text('Удалить "${beat.title}"?\nЭто действие нельзя отменить.', style: LG.font(color: LG.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: LG.font(color: LG.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: LG.font(color: LG.red, weight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final docId = beat.documentId;
      if (docId != null) {
        await BeatService.instance.deleteBeatByDocId(docId);
      } else {
        await BeatService.instance.deleteBeat(beat.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Бит "${beat.title}" удалён')),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _wasEdited ? 'updated' : null);
      },
      child: GlassScaffold(
      appBar: GlassAppBar(
        title: 'Детали бита',
        actions: [
          if (beat.documentId != null)
            IconButton(
              icon: Icon(
                _favService.isFavorite(beat.documentId) ? Icons.favorite : Icons.favorite_border,
                color: _favService.isFavorite(beat.documentId) ? LG.pink : LG.textSecondary,
              ),
              onPressed: () => _favService.toggle(beat.documentId!),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            const SizedBox(height: 60),
            // Cover
            Stack(children: [
              AspectRatio(aspectRatio: 16 / 9, child: beat.coverUrl != null && beat.coverUrl!.isNotEmpty
                ? Image.network(beat.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: LG.bgLight, child: Center(child: Icon(Icons.music_note, color: LG.textMuted, size: 64))))
                : Container(color: LG.bgLight, child: Center(child: Icon(Icons.music_note, color: LG.textMuted, size: 64)))),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, LG.bg], stops: const [0.5, 1.0])))),
            ]),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              Text(beat.title, style: LG.h1),
              const SizedBox(height: 6),
              GestureDetector(onTap: _openProducerProfile, child: Text('by ${beat.producerName ?? "Продюсер"}', style: LG.font(size: 15, color: LG.cyan, weight: FontWeight.w600))),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (beat.genreName != null) _chip(beat.genreName!, Icons.album, LG.accent),
                if (beat.bpm != null) _chip('${beat.bpm} BPM', Icons.speed, LG.orange),
                if (beat.key != null) _chip(beat.key!, Icons.piano, LG.cyan),
                if (beat.mood != null) _chip(_translateMood(beat.mood!), Icons.mood, LG.pink),
                _chip('${beat.playCount ?? 0} прослуш.', Icons.headphones, LG.textMuted),
              ]),
              if (beat.tagNames.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 6, children: beat.tagNames.map((t) => GlassChip(label: '#$t')).toList()),
              ],
              const SizedBox(height: 24),
              _buildPlayer(),
              const SizedBox(height: 24),
              _buildPrice(),
              const SizedBox(height: 24),
              _buildFiles(),
              const SizedBox(height: 16),
              _buildProducerProfileCard(),
              const SizedBox(height: 40),
            ])),
          ]),
        ),
      ),
    ),
    );
  }

  Widget _buildPlayer() {
    return GlassPanel(padding: const EdgeInsets.all(14), borderRadius: 18, blur: LG.blurLight, child: Column(children: [
      Row(children: [
        GestureDetector(onTap: _playPause, child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LG.accentGradient),
          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF0A0A0F), size: 28),
        )),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(beat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Превью', style: LG.font(size: 12, color: LG.textMuted)),
        ])),
        Text(_fmt(_position), style: LG.font(size: 12, color: LG.textMuted)),
        Text(' / ', style: LG.font(size: 12, color: LG.textMuted)),
        Text(_fmt(_duration ?? Duration.zero), style: LG.font(size: 12, color: LG.textMuted)),
      ]),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: LG.accent, inactiveTrackColor: Colors.white12, thumbColor: LG.accent, overlayColor: LG.accent.withValues(alpha: 0.15)),
        child: Slider(min: 0, max: (_duration?.inMilliseconds.toDouble() ?? 1), value: _position.inMilliseconds.toDouble().clamp(0, _duration?.inMilliseconds.toDouble() ?? 1), onChanged: (v) => _audio.seek(Duration(milliseconds: v.toInt()))),
      ),
    ]));
  }

  Widget _buildPrice() {
    final cart = CartService.instance;
    return GlassPanel(padding: const EdgeInsets.all(18), borderRadius: 18, blur: LG.blurLight, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('\$${beat.priceBase.toStringAsFixed(2)}', style: LG.font(size: 32, weight: FontWeight.w800, color: LG.green)),
        const Spacer(),
        Text(_isOwnBeat ? 'Ваш бит' : 'Базовая цена', style: LG.font(size: 13, color: _isOwnBeat ? LG.accent : LG.textMuted)),
      ]),
      const SizedBox(height: 16),
      if (_isOwnBeat)
        Row(children: [
          Expanded(
            child: GlassButton(
              text: 'Редактировать',
              icon: Icons.edit_outlined,
              onTap: _editBeat,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _deleteBeat,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(LG.radiusM),
                  border: Border.all(color: LG.red.withValues(alpha: 0.7)),
                  color: LG.red.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline, color: LG.red, size: 18),
                    const SizedBox(width: 8),
                    Text('Удалить', style: LG.font(weight: FontWeight.w700, color: LG.red)),
                  ]),
                ),
              ),
            ),
          ),
        ])
      else
        Row(children: [
          Expanded(child: GlassButton(text: cart.isEmpty ? 'Корзина' : 'Корзина (${cart.itemCount})', icon: Icons.shopping_cart, onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
          if (mounted) setState(() {});
        })),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () {
              final pid = beat.producerId; final pname = beat.producerName ?? 'Producer';
              if (pid != null && widget.onMessageProducer != null) { Navigator.pop(context); widget.onMessageProducer!(pid, pname); }
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(LG.radiusM), border: Border.all(color: LG.cyan)),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, color: LG.cyan, size: 18), const SizedBox(width: 8),
                Text('Написать', style: LG.font(weight: FontWeight.w700, color: LG.cyan)),
              ])),
            ),
          )),
        ]),
    ]));
  }

  Widget _buildFiles() {
    if (_loadingFiles) return Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: LG.accent)));
    if (_beatFiles.isEmpty) return const SizedBox.shrink();
    final cart = CartService.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Доступные форматы', style: LG.h3),
      const SizedBox(height: 12),
      ..._beatFiles.map((f) {
        final inCart = cart.contains(beat.id, f.id);
        final alreadyPurchased = _purchasedBeatFileIds.contains(f.id);
        return GlassPanel(
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: 14, borderColor: alreadyPurchased ? LG.green.withValues(alpha: 0.5) : (inCart ? LG.accent.withValues(alpha: 0.5) : null),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: LG.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(f.fileType.name.toUpperCase(), style: LG.font(color: LG.accent, weight: FontWeight.w700, size: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.licenseType == LicenseType.exclusive ? 'Эксклюзив' : 'Лицензия', style: LG.font(weight: FontWeight.w600)),
              if (f.price > 0) Text('\$${f.price.toStringAsFixed(2)}', style: LG.font(size: 13, color: LG.green)),
            ])),
            if (alreadyPurchased)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: LG.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, color: LG.green, size: 16),
                  const SizedBox(width: 4),
                  Text('Куплено', style: LG.font(color: LG.green, weight: FontWeight.w700, size: 12)),
                ]),
              )
            else if (f.enabled)
              GestureDetector(
                onTap: () {
                  if (inCart) cart.removeItem('${beat.id}_${f.id}'); else cart.addItem(beat, f);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(inCart ? 'Удалено из корзины' : 'Добавлено в корзину!'), duration: const Duration(seconds: 1)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: inCart ? LG.accent : LG.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(inCart ? Icons.check : Icons.add_shopping_cart, color: inCart ? const Color(0xFF0A0A0F) : LG.accent, size: 16),
                    const SizedBox(width: 4),
                    Text(inCart ? 'В корзине' : 'В корзину', style: LG.font(color: inCart ? const Color(0xFF0A0A0F) : LG.accent, weight: FontWeight.w700, size: 12)),
                  ]),
                ),
              )
            else Icon(Icons.block, color: LG.textMuted, size: 20),
          ]),
        );
      }),
    ]);
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color), const SizedBox(width: 6),
        Text(label, style: LG.font(color: color, weight: FontWeight.w600, size: 13)),
      ]),
    );
  }

  Widget _buildProducerProfileCard() {
    final producerName = beat.producerName ?? 'Продюсер';
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LG.accent.withValues(alpha: 0.18),
            ),
            child: Icon(Icons.person, color: LG.accent, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Профиль продюсера', style: LG.font(size: 12, color: LG.textMuted)),
                const SizedBox(height: 2),
                Text(
                  producerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LG.font(size: 15, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openProducerProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LG.cyan),
              ),
              child: Text('Открыть', style: LG.font(color: LG.cyan, weight: FontWeight.w700, size: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
