import 'package:flutter/material.dart';

import '../config/glass_theme.dart';
import '../models/beat.dart';
import '../models/public_profile.dart';
import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/beat_service.dart';
import '../services/favorite_service.dart';
import '../services/follow_service.dart';
import '../widgets/global_player_bar.dart';
import 'beat_detail_screen.dart';
import 'media_viewer_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _followService = FollowService.instance;
  final _beatService = BeatService.instance;
  final _audio = AudioPlayerService.instance;
  final _favService = FavoriteService.instance;

  bool _isLoading = true;
  bool _followLoading = false;
  PublicProfile? _profile;
  List<Beat> _beats = [];

  @override
  void initState() {
    super.initState();
    _favService.addListener(_onFavChanged);
    _load();
  }

  @override
  void dispose() {
    _favService.removeListener(_onFavChanged);
    super.dispose();
  }

  void _onFavChanged() {
    if (mounted) setState(() {});
  }

  void _openAvatarPreview() {
    final avatar = _profile?.avatarUrl;
    if (avatar == null || avatar.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaViewerScreen.image(imageUrl: avatar)),
    );
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await Future.wait([
        _followService.getPublicProfile(widget.userId),
        _beatService.getBeatsByProducer(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = result[0] as PublicProfile;
        _beats = result[1] as List<Beat>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки профиля: $e')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _followLoading) return;
    setState(() => _followLoading = true);
    try {
      final res = await _followService.toggleFollow(profile.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          isFollowing: res['isFollowing'] as bool,
          followersCount: res['followersCount'] as int,
        );
        _followLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка подписки: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUserId;
    final canFollow = currentUserId != null && currentUserId > 0;
    final isMe = currentUserId != null && currentUserId == widget.userId;
    final miniPlayerBottom = MediaQuery.of(context).padding.bottom + 2;

    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Профиль пользователя'),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: LG.accent))
              : _profile == null
                  ? Center(child: Text('Профиль не найден', style: LG.font(color: LG.textMuted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: LG.accent,
                      backgroundColor: LG.bgLight,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 98, 16, 210),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(isMe, canFollow),
                            const SizedBox(height: 14),
                            Text('Биты продюсера', style: LG.h3),
                            const SizedBox(height: 2),
                            _beats.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Text(
                                        'Пока нет опубликованных битов',
                                        style: LG.font(color: LG.textMuted),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: _beats.length,
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.78,
                                    ),
                                    itemBuilder: (_, i) {
                                      final beat = _beats[i];
                                      return _ProfileBeatCard(
                                        beat: beat,
                                        onTap: () async {
                                          _audio.setQueue(_beats);
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => BeatDetailScreen(beat: beat)),
                                          );
                                          if (mounted) setState(() {});
                                        },
                                        onPlay: () {
                                          _audio.setQueue(_beats);
                                          _audio.play(beat);
                                        },
                                        onToggleFav: beat.documentId == null
                                            ? null
                                            : () => _favService.toggle(beat.documentId!),
                                        isFavorite: _favService.isFavorite(beat.documentId),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
          Positioned(
            left: 16,
            right: 16,
            bottom: miniPlayerBottom,
            child: const GlobalPlayerBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMe, bool canFollow) {
    final p = _profile!;
    final avatar = p.avatarUrl;
    return GlassPanel(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _openAvatarPreview,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: LG.accent.withValues(alpha: 0.2),
                  backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar == null || avatar.isEmpty
                      ? Icon(Icons.person, color: LG.accent, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName ?? p.username ?? 'Пользователь',
                      style: LG.font(size: 18, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${p.username ?? 'user'}',
                      style: LG.font(size: 13, color: LG.textMuted),
                    ),
                  ],
                ),
              ),
              if (!isMe)
                SizedBox(
                  width: 176,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: (!canFollow || _followLoading) ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !canFollow
                          ? LG.panelFill
                          : (p.isFollowing ? LG.panelFill : LG.accent),
                      foregroundColor: !canFollow
                          ? LG.textMuted
                          : (p.isFollowing ? LG.textPrimary : const Color(0xFF0A0A0F)),
                      side: BorderSide(
                        color: !canFollow
                            ? LG.border
                            : (p.isFollowing ? LG.border : LG.accent.withValues(alpha: 0.7)),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _followLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.isFollowing ? LG.textPrimary : const Color(0xFF0A0A0F),
                            ),
                          )
                        : Text(
                            !canFollow
                                ? 'Войдите'
                                : (p.isFollowing ? 'Вы подписаны' : 'Подписаться'),
                            style: LG.font(
                              weight: FontWeight.w800,
                              size: 14,
                              color: !canFollow
                                  ? LG.textMuted
                                  : (p.isFollowing ? LG.textPrimary : const Color(0xFF0A0A0F)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
            ],
          ),
          if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p.bio!, style: LG.font(color: LG.textSecondary, size: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip('Подписчики', p.followersCount.toString()),
              const SizedBox(width: 8),
              _statChip('Биты', p.beatsCount.toString()),
              const SizedBox(width: 8),
              _statChip('Лайки', p.likesCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: LG.panelFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LG.border),
        ),
        child: Column(
          children: [
            Text(value, style: LG.font(weight: FontWeight.w800, size: 15)),
            const SizedBox(height: 2),
            Text(label, style: LG.font(size: 11, color: LG.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ProfileBeatCard extends StatelessWidget {
  final Beat beat;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback? onToggleFav;
  final bool isFavorite;

  const _ProfileBeatCard({
    required this.beat,
    required this.onTap,
    required this.onPlay,
    required this.onToggleFav,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: beat.coverUrl != null && beat.coverUrl!.isNotEmpty
                          ? Image.network(
                              beat.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: onToggleFav,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? LG.pink : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LG.accentGradient,
                        ),
                        child: const Icon(Icons.play_arrow, color: Color(0xFF0A0A0F), size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(weight: FontWeight.w700, size: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    beat.genreName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(size: 11, color: LG.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: LG.bgLight,
      child: Center(child: Icon(Icons.music_note, color: LG.textMuted, size: 34)),
    );
  }
}
