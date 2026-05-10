import 'package:flutter/material.dart';
import '../config/glass_theme.dart';
import '../models/beat.dart';
import '../services/beat_service.dart';
import '../services/audio_player_service.dart';
import '../services/favorite_service.dart';
import 'beat_detail_screen.dart';

/// Экран «Избранное» — отображает все биты, добавленные пользователем в избранное.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favService = FavoriteService.instance;
  final _beatService = BeatService.instance;
  final _audio = AudioPlayerService.instance;

  List<Beat> _beats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _favService.addListener(_onFavChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    _favService.removeListener(_onFavChanged);
    super.dispose();
  }

  void _onFavChanged() {
    // Если избранное изменилось — перезагружаем, но без индикатора
    _loadFavorites(silent: true);
  }

  Future<void> _loadFavorites({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      if (!_favService.loaded) await _favService.loadFavorites();
      final docIds = _favService.favoriteDocIds;
      if (docIds.isEmpty) {
        if (mounted) setState(() { _beats = []; _isLoading = false; });
        return;
      }
      // Загружаем полные данные битов
      final beats = await _beatService.getBeatsByDocumentIds(docIds.toList());
      if (mounted) setState(() { _beats = beats; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Избранное'),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: LG.accent))
            : RefreshIndicator(
                color: LG.accent,
                backgroundColor: LG.bgLight,
                onRefresh: () => _loadFavorites(),
                child: _beats.isEmpty
                    ? ListView(
                        // Нужен ListView чтобы RefreshIndicator работал
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          Center(child: Icon(Icons.favorite_border, size: 64, color: LG.textMuted)),
                          const SizedBox(height: 16),
                          Center(child: Text('Нет избранных битов', style: LG.font(color: LG.textMuted, size: 16))),
                          const SizedBox(height: 8),
                          Center(child: Text('Нажмите ♥ на бите, чтобы добавить', style: LG.font(color: LG.textMuted, size: 13))),
                        ],
                      )
                    : LayoutBuilder(builder: (context, constraints) {
                        final cols = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 3 : 2);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                          itemCount: _beats.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (_, i) {
                            final beat = _beats[i];
                            return _FavBeatCard(
                              beat: beat,
                              onTap: () async {
                                _audio.setQueue(_beats);
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => BeatDetailScreen(beat: beat)));
                                _loadFavorites();
                              },
                              onPlay: () {
                                _audio.setQueue(_beats);
                                _audio.play(beat);
                              },
                              onToggleFav: () => _favService.toggle(beat.documentId!),
                            );
                          },
                        );
                      }),
              ),
      ),
    );
  }
}

// ─── Favorite Beat Card ─────────────────────────────────────────────────────

class _FavBeatCard extends StatefulWidget {
  final Beat beat;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onToggleFav;
  const _FavBeatCard({required this.beat, required this.onTap, required this.onPlay, required this.onToggleFav});
  @override
  State<_FavBeatCard> createState() => _FavBeatCardState();
}

class _FavBeatCardState extends State<_FavBeatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final beat = widget.beat;
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Stack(children: [
              Positioned.fill(child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: beat.coverUrl != null && beat.coverUrl!.isNotEmpty
                    ? Image.network(beat.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              )),
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
              // Play button
              Positioned(right: 10, bottom: 10, child: GestureDetector(
                onTap: widget.onPlay,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LG.accentGradient,
                    boxShadow: [BoxShadow(color: LG.accent.withValues(alpha: 0.5), blurRadius: 14)],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF0A0A0F), size: 26),
                ),
              )),
              // Heart (remove from favorites)
              Positioned(right: 8, top: 8, child: GestureDetector(
                onTap: widget.onToggleFav,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: Icon(Icons.favorite, color: LG.pink, size: 18),
                ),
              )),
              // Price
              if (beat.priceBase > 0)
                Positioned(left: 10, top: 10, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: LG.green.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('\$${beat.priceBase.toStringAsFixed(0)}', style: LG.font(size: 13, weight: FontWeight.w700, color: const Color(0xFF0A0A0F))),
                )),
            ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(beat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700, size: 14)),
                const SizedBox(height: 3),
                Text('${beat.genreName ?? "—"} · ${beat.producerName ?? "Продюсер"}', maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(size: 12, color: LG.textSecondary)),
                if (beat.playCount != null && beat.playCount! > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.headphones, size: 11, color: LG.textMuted),
                    const SizedBox(width: 3),
                    Text('${beat.playCount}', style: LG.font(size: 11, color: LG.textMuted)),
                  ]),
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
