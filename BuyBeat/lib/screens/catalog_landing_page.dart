import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/glass_theme.dart';
import '../services/beat_service.dart';
import '../services/audio_player_service.dart';
import '../models/beat.dart' as models;
import '../models/genre.dart';
import '../models/tag.dart';
import 'beat_detail_screen.dart';
import 'package:just_audio/just_audio.dart';

IconData _genreIcon(String name) {
  switch (name.toLowerCase()) {
    case 'trap': return FontAwesomeIcons.fireFlameCurved;
    case 'drill': return FontAwesomeIcons.bolt;
    case 'lo-fi': case 'lofi': return FontAwesomeIcons.mugHot;
    case 'boom bap': return FontAwesomeIcons.recordVinyl;
    case 'r&b': case 'rnb': return FontAwesomeIcons.heart;
    case 'afrobeats': return FontAwesomeIcons.globe;
    case 'opium': return FontAwesomeIcons.star;
    case 'pop': return FontAwesomeIcons.music;
    case 'rock': return FontAwesomeIcons.guitar;
    case 'hip-hop': case 'hip hop': return FontAwesomeIcons.headphones;
    default: return FontAwesomeIcons.compactDisc;
  }
}

/// Маппинг настроения: ключ (eng для фильтрации) -> отображение (рус)
const Map<String, String> _moodMap = {
  'aggressive': 'Агрессивный',
  'calm': 'Спокойный',
  'dark': 'Тёмный',
  'energetic': 'Энергичный',
  'happy': 'Весёлый',
  'melancholic': 'Меланхоличный',
  'romantic': 'Романтичный',
  'sad': 'Грустный',
  'uplifting': 'Воодушевляющий',
  'chill': 'Чилл',
};

class CatalogLandingPage extends StatefulWidget {
  final void Function(int producerId, String producerName)? onMessageProducer;
  const CatalogLandingPage({super.key, this.onMessageProducer});
  @override
  State<CatalogLandingPage> createState() => _CatalogLandingPageState();
}

class _CatalogLandingPageState extends State<CatalogLandingPage> {
  final _audio = AudioPlayerService.instance;
  final _beatService = BeatService.instance;
  List<models.Beat> _beats = [];
  List<Genre> _genres = [];
  List<Tag> _tags = [];
  bool _isLoading = true;
  String? selectedGenre;
  String? selectedMood;
  RangeValues bpm = const RangeValues(10, 400);
  final Set<String> _selectedTags = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Player state from global service
  models.Beat? _nowPlaying;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerSub;

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
    _loadData();
  }

  Future<void> _loadData() async {
    // Грузим параллельно — каждый запрос независимо
    final results = await Future.wait([
      _beatService.getAllBeats().catchError((_) => <models.Beat>[]),
      _beatService.getAllGenres().catchError((_) => <Genre>[]),
      _beatService.getAllTags().catchError((_) => <Tag>[]),
    ]);
    if (mounted) {
      setState(() {
        _beats = results[0] as List<models.Beat>;
        _genres = results[1] as List<Genre>;
        _tags = results[2] as List<Tag>;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _playBeat(models.Beat b) {
    _audio.play(b);
    _syncQueue();
  }

  void _skipTrack(int delta) {
    if (_nowPlaying == null) return;
    final filtered = _applyFilters();
    final idx = filtered.indexWhere((b) => b.id == _nowPlaying!.id);
    if (idx == -1) return;
    final newIdx = (idx + delta).clamp(0, filtered.length - 1);
    if (newIdx == idx) return;
    _playBeat(filtered[newIdx]);
  }

  void _syncQueue() => _audio.setQueue(_applyFilters());

  List<models.Beat> _applyFilters() {
    return _beats.where((b) {
      final byGenre = selectedGenre == null || b.genreName == selectedGenre;
      final byMood = selectedMood == null || (b.mood?.toLowerCase() == selectedMood?.toLowerCase());
      final byBpm = b.bpm == null || (b.bpm! >= bpm.start && b.bpm! <= bpm.end);
      final q = _searchQuery.trim().toLowerCase();
      final bySearch = q.isEmpty || [
        b.title,
        b.genreName,
        b.producerName,
        b.mood,
        b.key,
        b.bpm?.toString(),
        ...b.tagNames,
      ].any((field) => field != null && field.toLowerCase().contains(q));
      final byTag = _selectedTags.isEmpty ||
          _selectedTags.any((t) => b.tagNames.map((n) => n.toLowerCase()).contains(t.toLowerCase()));
      return byGenre && byMood && byBpm && bySearch && byTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        showBack: false,
        titleWidget: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LG.accentGradient,
              boxShadow: [BoxShadow(color: LG.accent.withValues(alpha: 0.3), blurRadius: 12)],
            ),
            child: const Icon(Icons.music_note, color: Color(0xFF0A0A0F), size: 18),
          ),
          const SizedBox(width: 12),
          Text('BuyBeats', style: LG.h3),
        ]),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: RefreshIndicator(
            color: LG.accent,
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 210),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 24),
                    Text('Жанры', style: LG.h2),
                    const SizedBox(height: 14),
                    _buildGenres(),
                    const SizedBox(height: 22),
                    if (_tags.isNotEmpty) ...[
                      Text('Популярные теги', style: LG.h3),
                      const SizedBox(height: 10),
                      _buildTags(),
                      const SizedBox(height: 22),
                    ],
                    _buildFilters(),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: LG.accent)))
                    else if (_applyFilters().isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('Нет битов', style: LG.font(size: 16, color: LG.textMuted))))
                    else
                      _buildBeatGrid(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildHero() {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      borderRadius: LG.radiusXL,
      blur: LG.blurMedium,
      borderColor: LG.accent.withValues(alpha: 0.15),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
            shaderCallback: (bounds) => LG.accentGradient.createShader(bounds),
            child: Text('Твой Выбор', style: LG.h1.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Text('Открой трендовые биты, лучших продюсеров и точные фильтры.', style: LG.font(size: 15, color: LG.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: LG.body,
            onChanged: (v) => setState(() { _searchQuery = v; _syncQueue(); }),
            decoration: InputDecoration(
              hintText: 'Поиск по тегам, настроению, тональности, BPM...',
              prefixIcon: Icon(Icons.search, color: LG.textMuted),
              suffixIcon: _searchQuery.isNotEmpty ? GestureDetector(
                onTap: () => setState(() { _searchController.clear(); _searchQuery = ''; _syncQueue(); }),
                child: Icon(Icons.close, color: LG.textMuted, size: 20),
              ) : null,
            ),
          ),
        ])),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LG.accentGradient,
            boxShadow: [
              BoxShadow(color: LG.accent.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.graphic_eq, size: 48, color: Color(0xFF0A0A0F)),
        ),
      ]),
    );
  }

  Widget _buildGenres() {
    if (_genres.isEmpty) return SizedBox(height: 108, child: Center(child: Text('Загрузка жанров...', style: LG.bodyS)));
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: _genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final g = _genres[i];
          final sel = selectedGenre == g.name;
          return GestureDetector(
            onTap: () => setState(() { selectedGenre = selectedGenre == g.name ? null : g.name; _syncQueue(); }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GlassPanel(
                padding: const EdgeInsets.all(14),
                borderRadius: LG.radiusL,
                borderColor: sel ? LG.accent.withValues(alpha: 0.6) : null,
                fill: sel ? LG.accent.withValues(alpha: 0.12) : null,
                child: SizedBox(width: 130, child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: sel ? LG.accent.withValues(alpha: 0.2) : LG.panelFillLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_genreIcon(g.name), size: 20, color: sel ? LG.accent : Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700, color: sel ? LG.accent : Colors.white))),
                ])),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _tags.map((tag) {
        final sel = _selectedTags.contains(tag.name);
        return GlassChip(
          label: '#${tag.name}',
          selected: sel,
          onTap: () => setState(() {
            if (sel) { _selectedTags.remove(tag.name); } else { _selectedTags.add(tag.name); }
            _syncQueue();
          }),
        );
      }).toList(),
    );
  }

  Widget _buildFilters() {
    final bool hasActiveFilter = selectedGenre != null || selectedMood != null || bpm.start > 10 || bpm.end < 400 || _selectedTags.isNotEmpty;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: LG.radiusM,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Фильтры', style: LG.label),
              const Spacer(),
              if (hasActiveFilter)
                GestureDetector(
                  onTap: () => setState(() { selectedGenre = null; selectedMood = null; bpm = const RangeValues(10, 400); _selectedTags.clear(); _syncQueue(); }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: LG.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.restart_alt, color: LG.red, size: 14),
                      const SizedBox(width: 4),
                      Text('Сбросить', style: LG.font(color: LG.red, weight: FontWeight.w600, size: 12)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _glassDropdown(
                  'Жанр',
                  selectedGenre,
                  _genres.map((g) => g.name).toList(),
                  _genres.map((g) => g.name).toList(),
                  (v) => setState(() { selectedGenre = v; _syncQueue(); }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _glassDropdown(
                  'Настроение',
                  selectedMood,
                  _moodMap.keys.toList(),
                  _moodMap.values.toList(),
                  (v) => setState(() { selectedMood = v; _syncQueue(); }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('BPM', style: LG.label),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: LG.accent,
                  inactiveTrackColor: LG.panelFill,
                  thumbColor: LG.accent,
                  overlayColor: LG.accent.withValues(alpha: 0.15),
                  trackHeight: 3,
                ),
                child: RangeSlider(divisions: 39, min: 10, max: 400, values: bpm, onChanged: (v) => setState(() { bpm = v; _syncQueue(); })),
              ),
            ),
            const SizedBox(width: 6),
            Text('${bpm.start.toInt()}–${bpm.end.toInt()}', style: LG.bodyS),
          ]),
        ],
      ),
    );
  }

  Widget _glassDropdown(String label, String? value, List<String> values, List<String> displayLabels, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: LG.panelFill, borderRadius: BorderRadius.circular(LG.radiusS), border: Border.all(color: LG.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(label, style: LG.bodyS), value: value,
          dropdownColor: LG.bgLight,
          isExpanded: true,
          style: LG.body,
          onChanged: onChanged,
          items: List.generate(values.length, (i) => DropdownMenuItem(
            value: values[i],
            child: Text(displayLabels[i]),
          )),
        ),
      ),
    );
  }

  Widget _buildBeatGrid() {
    final filtered = _applyFilters();
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1200 ? 4 : w >= 900 ? 3 : w >= 600 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.82),
      itemBuilder: (_, i) {
        final b = filtered[i];
        final isCurrent = _nowPlaying?.id == b.id;
        return RepaintBoundary(child: _BeatCard(
          beat: b,
          isCurrentlyPlaying: isCurrent && _isPlaying,
          onPlay: () => _playBeat(b),
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => BeatDetailScreen(beat: b, onMessageProducer: widget.onMessageProducer)));
            if (result == 'updated' || result == 'deleted') _loadData();
          },
        ));
      },
    );
  }
}

// ─── Beat Card ──────────────────────────────────────────────────────────────

class _BeatCard extends StatefulWidget {
  final models.Beat beat;
  final VoidCallback onPlay;
  final VoidCallback? onTap;
  final bool isCurrentlyPlaying;
  const _BeatCard({required this.beat, required this.onPlay, this.onTap, this.isCurrentlyPlaying = false});
  @override
  State<_BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<_BeatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: GlassPanel(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          borderColor: widget.isCurrentlyPlaying ? LG.accent.withValues(alpha: 0.5) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Stack(children: [
              Positioned.fill(child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: widget.beat.coverUrl != null && widget.beat.coverUrl!.isNotEmpty
                    ? Image.network(widget.beat.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              )),
              // Gradient overlay for readability
              Positioned.fill(child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              )),
              Positioned(right: 10, bottom: 10, child: GestureDetector(
                onTap: widget.onPlay,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LG.accentGradient,
                    boxShadow: [BoxShadow(color: LG.accent.withValues(alpha: 0.5), blurRadius: 14)],
                  ),
                  child: Icon(
                    widget.isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: const Color(0xFF0A0A0F), size: 26,
                  ),
                ),
              )),
              if (widget.beat.priceBase > 0)
                Positioned(left: 10, top: 10, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: LG.green.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('\$${widget.beat.priceBase.toStringAsFixed(0)}', style: LG.font(size: 13, weight: FontWeight.w700, color: const Color(0xFF0A0A0F))),
                )),
            ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.beat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700, size: 14)),
                const SizedBox(height: 3),
                Text('${widget.beat.genreName ?? "—"} · ${widget.beat.producerName ?? "Unknown"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(size: 12, color: LG.textSecondary)),
                if (widget.beat.bpm != null || widget.beat.key != null) ...[
                  const SizedBox(height: 4),
                  Text([if (widget.beat.bpm != null) '${widget.beat.bpm} BPM', if (widget.beat.key != null) widget.beat.key!].join(' · '), style: LG.font(size: 11, color: LG.textMuted)),
                ],
                if (widget.beat.tagNames.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: -8, children: widget.beat.tagNames.take(3).map((t) => Chip(
                    label: Text('#$t', style: LG.font(size: 10)), visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: LG.panelFill, side: BorderSide.none,
                  )).toList()),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(color: LG.bgLight, child: Center(child: Icon(Icons.music_note, color: LG.textMuted, size: 48)));
}

