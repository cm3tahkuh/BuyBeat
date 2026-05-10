import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../config/glass_theme.dart';
import '../services/auth_service.dart';
import '../services/audio_player_service.dart';
import '../services/beat_service.dart';
import '../services/strapi_service.dart';
import '../services/follow_service.dart';
import '../models/user.dart';
import '../models/beat.dart';
import '../config/strapi_config.dart';
import 'auth/login_screen.dart';
import 'settings_screen.dart';
import 'admin_panel_screen.dart';
import 'purchase_history_screen.dart';
import 'upload_beat_screen.dart';
import 'beat_detail_screen.dart';
import 'edit_beat_screen.dart';
import 'favorites_screen.dart';
import 'activity_notifications_screen.dart';
import 'my_following_screen.dart';
import 'media_viewer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _beatService = BeatService.instance;
  final _followService = FollowService.instance;
  User? _user;
  List<Beat> _myBeats = [];
  bool _isLoading = true;
  bool _isEditingBio = false;
  final _bioController = TextEditingController();
  int _followersCount = 0;
  int _likesOnBeatsCount = 0;

  @override void initState() { super.initState(); _loadUserData(); }
  @override void dispose() { _bioController.dispose(); super.dispose(); }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      List<Beat> beats = [];
      int followersCount = 0;
      int likesCount = 0;
      if (user != null) { try { beats = await _beatService.getBeatsByProducer(user.id); } catch (_) {} }
      if (user != null) {
        try {
          final profile = await _followService.getPublicProfile(user.id);
          followersCount = profile.followersCount;
          likesCount = profile.likesCount;
        } catch (_) {}
      }
      if (mounted) setState(() { _user = user; _myBeats = beats; _bioController.text = user?.bio ?? ''; _followersCount = followersCount; _likesOnBeatsCount = likesCount; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки профиля: $e'))); }
    }
  }

  Future<void> _saveBio() async {
    if (_user == null) return;
    try {
      await _authService.updateBio(_bioController.text, userId: _user!.id);
      setState(() { _isEditingBio = false; _user = _user!.copyWith(bio: _bioController.text); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Описание профиля обновлено')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e'))); }
  }

  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: _user!.displayName ?? _user!.username ?? '');
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: LG.bgLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Изменить имя', style: LG.font(weight: FontWeight.w700, size: 18)),
      content: TextField(controller: ctrl, autofocus: true, style: LG.font(size: 14),
        decoration: InputDecoration(hintText: 'Отображаемое имя', hintStyle: LG.font(color: LG.textMuted),
          filled: true, fillColor: LG.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LG.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LG.accent)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: LG.font(color: LG.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text('Сохранить', style: LG.font(color: LG.accent, weight: FontWeight.w700))),
      ],
    ));
    if (result == null || result.isEmpty) return;
    try {
      await _authService.updateDisplayName(result, userId: _user!.id);
      _authService.invalidateCache(); await _loadUserData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Имя обновлено')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Загрузка аватара...')));
      final strapi = StrapiService.instance;
      final uploads = await strapi.uploadFileBytes(bytes: file.bytes!, fileName: file.name);
      if (uploads.isEmpty) throw Exception('Файл не загружен');
      final uploadedId = uploads.first['id'];
      await strapi.put('${StrapiConfig.users}/${_user!.id}', body: {'avatar': uploadedId});
      _authService.invalidateCache(); await _loadUserData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Аватар обновлён')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки аватара: $e'))); }
  }

  void _openAvatarPreview() {
    final avatar = _user?.avatarUrl;
    if (avatar == null || avatar.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaViewerScreen.image(imageUrl: avatar)),
    );
  }

  Future<void> _editBeat(Beat beat) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBeatScreen(beat: beat)));
    if (result == true) _loadUserData();
  }

  Future<void> _deleteBeat(Beat beat) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: LG.bgLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Удалить бит?', style: LG.font(weight: FontWeight.w700, size: 18)),
      content: Text('Удалить "${beat.title}"?\nЭто действие нельзя отменить.', style: LG.font(color: LG.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: LG.font(color: LG.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: LG.font(color: LG.red, weight: FontWeight.w700))),
      ],
    ));
    if (confirm != true) return;
    try {
      final docId = beat.documentId;
      if (docId != null) {
        await _beatService.deleteBeatByDocId(docId);
      } else {
        await _beatService.deleteBeat(beat.id);
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бит удалён'))); _loadUserData(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
  }

  void _showStatsDialog() {
    final totalPlays = _myBeats.fold<int>(0, (s, b) => s + (b.playCount ?? 0));
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: LG.bgLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Моя статистика', style: LG.font(weight: FontWeight.w700, size: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _statsRow(Icons.music_note, 'Опубликовано битов', _myBeats.length.toString()),
        const SizedBox(height: 12),
        _statsRow(Icons.visibility, 'Публичных', _myBeats.where((b) => b.visibility == BeatVisibility.public).length.toString()),
        const SizedBox(height: 12),
        _statsRow(Icons.headphones, 'Всего прослушиваний', totalPlays.toString()),
        const SizedBox(height: 12),
        _statsRow(Icons.attach_money, 'Средняя цена',
          _myBeats.isEmpty ? '—' : '\$${(_myBeats.map((b) => b.priceBase).reduce((a, b) => a + b) / _myBeats.length).toStringAsFixed(2)}'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: LG.font(color: LG.accent)))],
    ));
  }

  Widget _statsRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: LG.accent, size: 18), const SizedBox(width: 10),
      Expanded(child: Text(label, style: LG.font(color: LG.textSecondary, size: 13))),
      Text(value, style: LG.font(weight: FontWeight.w700, size: 14)),
    ]);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: LG.bgLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Выход из аккаунта', style: LG.font(weight: FontWeight.w700, size: 18)),
      content: Text('Вы уверены, что хотите выйти?', style: LG.font(color: LG.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Отмена', style: LG.font(color: LG.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Выйти', style: LG.font(color: LG.red, weight: FontWeight.w700))),
      ],
    ));
    if (confirm == true) {
      try {
        await AudioPlayerService.instance.stop();
        await _authService.signOut();
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выхода: $e'))); }
    }
  }

  String _getRoleText(UserRole role) {
    switch (role) { case UserRole.artist: return 'Артист'; case UserRole.producer: return 'Продюсер'; case UserRole.admin: return 'Администратор'; case UserRole.superAdmin: return 'Супер-администратор'; case UserRole.guest: return 'Гость'; }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return GlassScaffold(body: Center(child: CircularProgressIndicator(color: LG.accent)));
    if (_user == null || _user!.isGuest) {
      return GlassScaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline_rounded, size: 80, color: LG.textMuted),
                  const SizedBox(height: 16),
                  Text('Войдите в аккаунт', style: LG.h2),
                  const SizedBox(height: 8),
                  Text('Чтобы получить доступ к профилю,\nвойдите или зарегистрируйтесь', textAlign: TextAlign.center, style: LG.font(color: LG.textSecondary, size: 15)),
                  const SizedBox(height: 28),
                  SizedBox(width: 220, child: GlassButton(text: 'Войти', icon: Icons.login, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => _loadUserData());
                  })),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GlassScaffold(
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final gridCols = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 3 : 2);
        final hPad = isWide ? 20.0 : 14.0;

        final profileCard = GlassPanel(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          borderRadius: 20,
          borderColor: LG.accent.withValues(alpha: 0.3),
          child: Stack(children: [
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActivityNotificationsScreen(),
                  ),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LG.panelFill,
                    border: Border.all(color: LG.border),
                  ),
                  child: Icon(Icons.notifications_none_rounded, color: LG.textPrimary, size: 20),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Avatar
            GestureDetector(onTap: _openAvatarPreview, child: Stack(alignment: Alignment.bottomRight, children: [
              Container(
                width: isWide ? 100 : 80,
                height: isWide ? 100 : 80,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: _user!.avatarUrl != null ? null : LG.accentGradient,
                  image: _user!.avatarUrl != null ? DecorationImage(image: NetworkImage(_user!.avatarUrl!), fit: BoxFit.cover) : null),
                child: _user!.avatarUrl == null ? Icon(Icons.person, size: isWide ? 50 : 40, color: const Color(0xFF0A0A0F)) : null),
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: LG.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF0A0A0F), size: 16)),
              ),
            ])),
            const SizedBox(height: 12),
            GestureDetector(onTap: _editDisplayName, child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(
                _user!.displayName ?? _user!.username ?? 'Без имени',
                style: LG.font(size: isWide ? 20 : 17, weight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )),
              const SizedBox(width: 6), Icon(Icons.edit, size: 14, color: LG.textMuted),
            ])),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: LG.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text(_getRoleText(_user!.appRole), style: LG.font(color: LG.accent, size: 11, weight: FontWeight.w600))),
            if (_user!.email != null) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.email, size: 14, color: LG.textMuted), const SizedBox(width: 6),
                Flexible(child: Text(_user!.email!, style: LG.font(color: LG.textMuted, size: 12), overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildStatItem('Подписчики', _followersCount.toString())),
              Expanded(child: _buildStatItem('Лайки', _likesOnBeatsCount.toString())),
            ]),
            const SizedBox(height: 14),
            // Bio
            GlassPanel(padding: const EdgeInsets.all(14), borderRadius: 12,
              child: _isEditingBio
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(controller: _bioController, maxLines: 4, style: LG.font(size: 13),
                      decoration: InputDecoration(hintText: 'Расскажите о себе...', hintStyle: LG.font(color: LG.textMuted), border: InputBorder.none)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => setState(() { _isEditingBio = false; _bioController.text = _user!.bio ?? ''; }),
                        child: Text('Отмена', style: LG.font(color: LG.textMuted, size: 13))),
                      const SizedBox(width: 6),
                      ElevatedButton(onPressed: _saveBio, style: ElevatedButton.styleFrom(backgroundColor: LG.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Text('Сохранить', style: LG.font(size: 13, weight: FontWeight.w600, color: const Color(0xFF0A0A0F)))),
                    ]),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('О себе', style: LG.font(color: LG.textMuted, size: 12, weight: FontWeight.w600)),
                      GestureDetector(
                        onTap: () => setState(() => _isEditingBio = true),
                        child: Icon(Icons.edit, size: 15, color: LG.accent),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(_user!.bio?.isNotEmpty == true ? _user!.bio! : 'Описание не добавлено',
                      style: LG.font(color: _user!.bio?.isNotEmpty == true ? LG.textSecondary : LG.textMuted, size: 13)),
                  ]),
            ),
            const SizedBox(height: 16),
            Divider(color: LG.border, height: 16),
            // Stats row
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Expanded(child: _buildStatItem('Прослушивания', _myBeats.fold<int>(0, (s, b) => s + (b.playCount ?? 0)).toString())),
              Expanded(child: _buildStatItem('Треки', _myBeats.length.toString())),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: GestureDetector(onTap: _signOut,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LG.red.withValues(alpha: 0.5))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout, color: LG.red, size: 18), const SizedBox(width: 8),
                  Text('Выйти из аккаунта', style: LG.font(color: LG.red, weight: FontWeight.w600, size: 14)),
                ])))),
          ]),
          ]),
        );

        final menuPanel = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _menuBtn(Icons.people_alt_outlined, 'Мои подписки', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFollowingScreen())), color: LG.cyan),
          _menuBtn(Icons.favorite, 'Избранное', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())), color: LG.pink),
          _menuBtn(Icons.bar_chart, 'Статистика', _showStatsDialog),
          _menuBtn(Icons.account_balance_wallet, 'Кошелёк', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()))),
          _menuBtn(Icons.shopping_bag_outlined, 'Мои покупки', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()))),
          if (_user!.isProducer || _user!.isAdmin) _menuBtn(Icons.cloud_upload, 'Загрузить бит',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadBeatScreen())).then((r) { if (r == true) _loadUserData(); }),
            color: LG.green),
          _menuBtn(Icons.settings, 'Настройки', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadUserData())),
          if (_user!.isAdmin) _menuBtn(Icons.admin_panel_settings, 'Админ-панель',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
            color: _user!.isSuperAdmin ? LG.orange : LG.red),
        ]);

        return RefreshIndicator(
          color: LG.accent,
          backgroundColor: LG.bgLight,
          onRefresh: _loadUserData,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: hPad),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top section: wide = Row, narrow = Column
              if (isWide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 4, child: profileCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: menuPanel),
                ])
              else ...[
                profileCard,
                const SizedBox(height: 16),
                menuPanel,
              ],
              if (_user!.isProducer || _user!.isAdmin) ...[
              const SizedBox(height: 32),
              Text('Мои биты', style: LG.h1),
              const SizedBox(height: 14),
              if (_myBeats.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                  Icon(Icons.music_off, color: LG.textMuted, size: 48), const SizedBox(height: 12),
                  Text('У вас пока нет битов', style: LG.font(color: LG.textMuted, size: 16)),
                ])))
              else GridView.builder(
                physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: _myBeats.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
                itemBuilder: (_, i) {
                  final beat = _myBeats[i];
                  return _RealBeatCard(
                    beat: beat,
                    onTap: () async {
                      AudioPlayerService.instance.setQueue(_myBeats);
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => BeatDetailScreen(beat: beat)));
                      _loadUserData(); // всегда обновляем — play_count мог измениться
                    },
                    onEdit: () => _editBeat(beat),
                    onDelete: () => _deleteBeat(beat),
                    onPlay: () {
                      AudioPlayerService.instance.setQueue(_myBeats);
                      AudioPlayerService.instance.play(beat);
                    },
                  );
                }),
              ],              // Bottom padding for floating nav bar
              const SizedBox(height: 120),            ]),
          )),
        ));
      })),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(children: [
      Text(value, style: LG.font(size: 17, weight: FontWeight.w700)),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: LG.font(color: LG.textMuted, size: 11)),
      ),
    ]);
  }

  Widget _menuBtn(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    final c = color ?? LG.accent;
    return GlassPanel(margin: const EdgeInsets.only(bottom: 12), padding: EdgeInsets.zero, borderRadius: 12, borderColor: c.withValues(alpha: 0.2),
      child: ListTile(
        leading: Icon(icon, color: c, size: 22),
        title: Text(title, style: LG.font(weight: FontWeight.w600, size: 15)),
        trailing: Icon(Icons.arrow_forward_ios, color: LG.textMuted, size: 14),
        onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }
}

class _RealBeatCard extends StatefulWidget {
  final Beat beat; final VoidCallback? onTap; final VoidCallback? onEdit; final VoidCallback? onDelete; final VoidCallback? onPlay;
  const _RealBeatCard({required this.beat, this.onTap, this.onEdit, this.onDelete, this.onPlay});
  @override State<_RealBeatCard> createState() => _RealBeatCardState();
}

class _RealBeatCardState extends State<_RealBeatCard> {
  bool isHovered = false;

  void _showContextMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: LG.bgLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
            decoration: BoxDecoration(color: LG.border, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(widget.beat.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: LG.font(weight: FontWeight.w700, size: 16))),
          const SizedBox(height: 8),
          if (widget.onEdit != null)
            ListTile(
              leading: Icon(Icons.edit_outlined, color: LG.accent),
              title: Text('Редактировать', style: LG.font(size: 15)),
              onTap: () { Navigator.pop(ctx); widget.onEdit!(); },
            ),
          if (widget.onDelete != null)
            ListTile(
              leading: Icon(Icons.delete_outline, color: LG.red),
              title: Text('Удалить', style: LG.font(color: LG.red, size: 15)),
              onTap: () { Navigator.pop(ctx); widget.onDelete!(); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beat = widget.beat;
    return GestureDetector(onTap: widget.onTap, onLongPress: _showContextMenu, child: MouseRegion(
      onEnter: (_) => setState(() => isHovered = true), onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        transform: isHovered ? (Matrix4.identity()..scale(1.04)) : Matrix4.identity(),
        decoration: BoxDecoration(color: LG.panelFill, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isHovered ? LG.accent.withValues(alpha: 0.5) : LG.accent.withValues(alpha: 0.1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            Positioned.fill(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: beat.coverUrl != null && beat.coverUrl!.isNotEmpty
                ? Image.network(beat.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: LG.bgLight, child: const Center(child: Icon(Icons.music_note, color: Colors.white38, size: 36))))
                : Container(color: LG.bgLight, child: const Center(child: Icon(Icons.music_note, color: Colors.white38, size: 36))))),
            Positioned.fill(child: AnimatedOpacity(opacity: isHovered ? 1 : 0, duration: const Duration(milliseconds: 200),
              child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (widget.onPlay != null) ...[_hoverButton(Icons.play_arrow_rounded, LG.accent, widget.onPlay!), const SizedBox(height: 10)],
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (widget.onEdit != null) _hoverButton(Icons.edit, LG.accent, widget.onEdit!),
                    const SizedBox(width: 12),
                    if (widget.onDelete != null) _hoverButton(Icons.delete, LG.red, widget.onDelete!),
                  ]),
                ])))),
          ])),
          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(beat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(beat.genreName ?? '—', style: LG.font(color: LG.textMuted, size: 11)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.headphones, size: 11, color: LG.textMuted),
              const SizedBox(width: 3),
              Text('${beat.playCount ?? 0}', style: LG.font(color: LG.textMuted, size: 11)),
              const Spacer(),
              if (beat.priceBase > 0)
                Text('\$${beat.priceBase.toStringAsFixed(2)}', style: LG.font(color: LG.green, size: 12, weight: FontWeight.w700)),
            ]),
          ])),
        ]),
      ),
    ));
  }

  Widget _hoverButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.6))),
      child: Icon(icon, color: color, size: 18)));
  }
}
