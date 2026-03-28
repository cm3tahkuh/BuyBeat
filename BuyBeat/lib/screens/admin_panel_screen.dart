import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/beat.dart';
import '../services/auth_service.dart';
import '../services/strapi_service.dart';
import '../config/strapi_config.dart';
import '../config/glass_theme.dart';
import 'edit_beat_screen.dart';

/// Админ-панель — доступна admin и super_admin
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _strapi = StrapiService.instance;
  User? _currentUser;
  bool _isLoading = true;

  late TabController _tabController;

  // Данные
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _beats = [];
  bool _isLoadingData = false;

  // Поиск
  String _userSearchQuery = '';
  String _beatSearchQuery = '';

  List<Map<String, dynamic>> get _filteredUsers {
    if (_userSearchQuery.isEmpty) return _users;
    final q = _userSearchQuery.toLowerCase();
    return _users.where((u) {
      final name = (u['username'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final displayName = (u['display_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || displayName.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredBeats {
    if (_beatSearchQuery.isEmpty) return _beats;
    final q = _beatSearchQuery.toLowerCase();
    return _beats.where((b) {
      final title = (b['title'] ?? '').toString().toLowerCase();
      return title.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
        // super_admin видит 3 вкладки (Юзеры, Биты, Статистика)
        // admin видит 2 вкладки (Биты, Статистика)
        final tabCount = user?.isSuperAdmin == true ? 3 : 2;
        _tabController = TabController(length: tabCount, vsync: this);
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      // Загружаем биты
      final beatsResponse = await _strapi.get(
        StrapiConfig.beats,
        queryParams: {'populate': '*', 'pagination[pageSize]': '50'},
      );
      _beats = StrapiService.parseList(beatsResponse);

      // super_admin может управлять юзерами
      if (_currentUser?.isSuperAdmin == true) {
        final usersResponse = await _strapi.get(StrapiConfig.users);
        if (usersResponse is List) {
          _users = List<Map<String, dynamic>>.from(
            usersResponse.map((e) => e as Map<String, dynamic>),
          );
        } else if (usersResponse is Map<String, dynamic>) {
          // на случай если Strapi вернёт обёртку
          final data = usersResponse['data'];
          if (data is List) {
            _users = List<Map<String, dynamic>>.from(
              data.map((e) => e as Map<String, dynamic>),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
    }
    if (mounted) setState(() => _isLoadingData = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(
        body: Center(child: CircularProgressIndicator(color: LG.accent)),
      );
    }

    if (_currentUser == null || !_currentUser!.isAdmin) {
      return GlassScaffold(
        appBar: GlassAppBar(
          title: '',
          showBack: true,
        ),
        body: Center(
          child: Text(
            'Нет доступа',
            style: LG.font(color: LG.textPrimary, size: 18),
          ),
        ),
      );
    }

    final isSuperAdmin = _currentUser!.isSuperAdmin;

    return GlassScaffold(
      appBar: GlassAppBar(
        showBack: true,
        titleWidget: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: LG.accent),
            const SizedBox(width: 8),
            Text(
              'Админ-панель',
              style: LG.font(
                color: LG.textPrimary,
                weight: FontWeight.w700,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSuperAdmin
                    ? Colors.amber.withValues(alpha: 0.2)
                    : LG.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSuperAdmin ? 'SUPER' : 'ADMIN',
                style: LG.font(
                  color: isSuperAdmin ? Colors.amber : LG.accent,
                  size: 10,
                  weight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LG.accent,
          labelColor: LG.textPrimary,
          unselectedLabelColor: LG.textMuted,
          labelStyle: LG.font(weight: FontWeight.w600, size: 13),
          unselectedLabelStyle: LG.font(weight: FontWeight.w500, size: 13),
          tabs: [
            if (isSuperAdmin) const Tab(icon: Icon(Icons.people), text: 'Юзеры'),
            const Tab(icon: Icon(Icons.music_note), text: 'Биты'),
            const Tab(icon: Icon(Icons.bar_chart), text: 'Статистика'),
          ],
        ),
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: LG.accent))
          : SafeArea(
              top: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 96),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    if (isSuperAdmin) _buildUsersTab(),
                    _buildBeatsTab(),
                    _buildStatsTab(),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Вкладка: Юзеры (только super_admin) ──────────────────────────

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: LG.accent,
      child: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LG.radiusS),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: LG.blurLight, sigmaY: LG.blurLight),
                child: TextField(
                  style: LG.font(color: LG.textPrimary, size: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени или email...',
                    hintStyle: LG.font(color: LG.textMuted, size: 14),
                    prefixIcon: Icon(Icons.search, color: LG.textMuted, size: 20),
                    filled: true,
                    fillColor: LG.panelFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LG.radiusS),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _userSearchQuery = v),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      _users.isEmpty ? 'Нет пользователей' : 'Ничего не найдено',
                      style: LG.font(color: LG.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _buildUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final username = user['username'] ?? '—';
    final email = user['email'] ?? '—';
    final appRole = user['app_role'] ?? 'artist';
    final blocked = user['blocked'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        borderRadius: LG.radiusS,
        borderColor: blocked ? LG.red.withValues(alpha: 0.3) : null,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Аватар
            CircleAvatar(
              radius: 22,
              backgroundColor: LG.accent.withValues(alpha: 0.2),
              child: Text(
                username[0].toUpperCase(),
                style: LG.font(
                  color: LG.accent,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Инфо
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: LG.font(
                            color: LG.textPrimary,
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRoleBadge(appRole),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: LG.font(
                      color: LG.textMuted,
                      size: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Действия
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: LG.textMuted),
              color: LG.bgLight,
              onSelected: (action) => _handleUserAction(action, user),
              itemBuilder: (context) => [
                _popupItem('edit_user', 'Редактировать', Icons.edit),
                const PopupMenuDivider(),
                _popupItem('make_admin', 'Назначить админом', Icons.shield),
                _popupItem('make_artist', 'Сделать артистом', Icons.mic),
                _popupItem('make_producer', 'Сделать продюсером', Icons.headphones),
                const PopupMenuDivider(),
                _popupItem(
                  blocked ? 'unblock' : 'block',
                  blocked ? 'Разблокировать' : 'Заблокировать',
                  blocked ? Icons.lock_open : Icons.block,
                  color: blocked ? LG.green : LG.red,
                ),
                _popupItem('delete_user', 'Удалить', Icons.delete_forever, color: LG.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
    String value,
    String text,
    IconData icon, {
    Color? color,
  }) {
    final c = color ?? LG.textSecondary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(text, style: LG.font(color: c, size: 13)),
        ],
      ),
    );
  }

  Future<void> _handleUserAction(String action, Map<String, dynamic> user) async {
    final userId = user['id'];
    if (userId == null) return;

    // Edit user dialog
    if (action == 'edit_user') {
      _showEditUserDialog(user);
      return;
    }

    // Delete user
    if (action == 'delete_user') {
      _deleteUser(user);
      return;
    }

    try {
      Map<String, dynamic> data;
      switch (action) {
        case 'make_admin':
          data = {'app_role': 'admin'};
          break;
        case 'make_artist':
          data = {'app_role': 'artist'};
          break;
        case 'make_producer':
          data = {'app_role': 'producer'};
          break;
        case 'block':
          data = {'blocked': true};
          break;
        case 'unblock':
          data = {'blocked': false};
          break;
        default:
          return;
      }

      await _strapi.put('${StrapiConfig.users}/$userId', body: data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Обновлено', style: LG.font(color: const Color(0xFF0A0A0F), size: 14)),
            backgroundColor: LG.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case 'super_admin':
        color = Colors.amber;
        label = 'SUPER';
        break;
      case 'admin':
        color = LG.red;
        label = 'ADMIN';
        break;
      case 'producer':
        color = LG.cyan;
        label = 'PROD';
        break;
      case 'guest':
        color = LG.textMuted;
        label = 'GUEST';
        break;
      default:
        color = LG.accent;
        label = 'ARTIST';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: LG.font(
          color: color,
          size: 9,
          weight: FontWeight.w800,
        ),
      ),
    );
  }

  // ─── Редактирование пользователя ──────────────────────────────────

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final userId = user['id'];
    final usernameCtrl = TextEditingController(text: user['username'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final displayNameCtrl = TextEditingController(text: user['display_name'] ?? '');
    final bioCtrl = TextEditingController(text: user['bio'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LG.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LG.radiusL)),
        title: Text('Редактировать пользователя',
            style: LG.font(color: LG.textPrimary, weight: FontWeight.w700, size: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(usernameCtrl, 'Имя пользователя', Icons.person),
              const SizedBox(height: 12),
              _dialogField(emailCtrl, 'Email', Icons.email),
              const SizedBox(height: 12),
              _dialogField(displayNameCtrl, 'Отображаемое имя', Icons.badge),
              const SizedBox(height: 12),
              _dialogField(bioCtrl, 'Описание', Icons.notes, maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: LG.font(color: LG.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Сохранить',
                style: LG.font(color: LG.accent, weight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (saved != true) return;

    try {
      final data = <String, dynamic>{};
      if (usernameCtrl.text.trim().isNotEmpty) data['username'] = usernameCtrl.text.trim();
      if (emailCtrl.text.trim().isNotEmpty) data['email'] = emailCtrl.text.trim();
      data['display_name'] = displayNameCtrl.text.trim();
      data['bio'] = bioCtrl.text.trim();

      await _strapi.put('${StrapiConfig.users}/$userId', body: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Пользователь обновлён', style: LG.font(color: const Color(0xFF0A0A0F), size: 14)),
            backgroundColor: LG.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: LG.font(color: LG.textPrimary, size: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: LG.font(color: LG.textMuted, size: 13),
        prefixIcon: Icon(icon, color: LG.textMuted, size: 18),
        filled: true,
        fillColor: LG.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: LG.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: LG.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: LG.accent),
        ),
      ),
    );
  }

  // ─── Удаление пользователя ────────────────────────────────────────

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = user['id'];
    final username = user['username'] ?? 'пользователя';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LG.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LG.radiusL)),
        title: Text('Удалить $username?', style: LG.font(color: LG.textPrimary, weight: FontWeight.w700, size: 16)),
        content: Text(
          'Это действие нельзя отменить. Все данные пользователя будут потеряны.',
          style: LG.font(color: LG.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: LG.font(color: LG.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: LG.font(color: LG.red, weight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _strapi.delete('${StrapiConfig.users}/$userId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Пользователь удалён', style: LG.font(color: const Color(0xFF0A0A0F), size: 14)),
            backgroundColor: LG.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  // ─── Вкладка: Биты (admin + super_admin) ──────────────────────────

  Widget _buildBeatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: LG.accent,
      child: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LG.radiusS),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: LG.blurLight, sigmaY: LG.blurLight),
                child: TextField(
                  style: LG.font(color: LG.textPrimary, size: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию...',
                    hintStyle: LG.font(color: LG.textMuted, size: 14),
                    prefixIcon: Icon(Icons.search, color: LG.textMuted, size: 20),
                    filled: true,
                    fillColor: LG.panelFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LG.radiusS),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _beatSearchQuery = v),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredBeats.isEmpty
                ? Center(
                    child: Text(
                      _beats.isEmpty ? 'Нет битов' : 'Ничего не найдено',
                      style: LG.font(color: LG.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBeats.length,
                    itemBuilder: (context, index) {
                      final beat = _filteredBeats[index];
                      return _buildBeatCard(beat);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeatCard(Map<String, dynamic> beat) {
    final title = beat['title'] ?? 'Без названия';
    final price = beat['price_base']?.toString() ?? beat['price']?.toString() ?? '0';
    final id = beat['id'];
    final playCount = beat['play_count'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        borderRadius: LG.radiusS,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Иконка
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LG.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note, color: Color(0xFF0A0A0F), size: 22),
            ),
            const SizedBox(width: 14),
            // Инфо
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: LG.font(
                      color: LG.textPrimary,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(
                      '\$$price • ID: $id',
                      style: LG.font(color: LG.textMuted, size: 12),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.headphones, size: 12, color: LG.accent),
                    const SizedBox(width: 3),
                    Text(
                      '$playCount',
                      style: LG.font(color: LG.accent, size: 12, weight: FontWeight.w600),
                    ),
                  ]),
                ],
              ),
            ),
            // Редактировать
            IconButton(
              icon: Icon(Icons.edit_outlined, color: LG.accent, size: 20),
              onPressed: () => _editBeat(beat),
            ),
            // Удалить
            IconButton(
              icon: Icon(Icons.delete_outline, color: LG.red, size: 20),
              onPressed: () => _deleteBeat(beat['documentId'] ?? id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBeat(Map<String, dynamic> beatJson) async {
    try {
      final beat = Beat.fromJson(beatJson);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditBeatScreen(beat: beat)),
      );
      if (result == true && mounted) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _deleteBeat(dynamic id) async {
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LG.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LG.radiusL)),
        title: Text('Удалить бит?', style: LG.font(color: LG.textPrimary, weight: FontWeight.w700, size: 16)),
        content: Text(
          'Это действие нельзя отменить.',
          style: LG.font(color: LG.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: LG.font(color: LG.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: LG.font(color: LG.red, weight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _strapi.delete('${StrapiConfig.beats}/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Бит удалён', style: LG.font(color: const Color(0xFF0A0A0F), size: 14)),
            backgroundColor: LG.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  // ─── Вкладка: Статистика ──────────────────────────────────────────

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Карточки статистики
          Row(
            children: [
              if (_currentUser!.isSuperAdmin)
                Expanded(
                  child: _buildStatCard(
                    'Пользователи',
                    _users.length.toString(),
                    Icons.people,
                    LG.blue,
                  ),
                ),
              if (_currentUser!.isSuperAdmin) const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  'Биты',
                  _beats.length.toString(),
                  Icons.music_note,
                  LG.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Артисты',
                  _users.where((u) => u['app_role'] == 'artist').length.toString(),
                  Icons.mic,
                  LG.cyan,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  'Продюсеры',
                  _users.where((u) => u['app_role'] == 'producer').length.toString(),
                  Icons.headphones,
                  LG.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Админы',
                  _users
                      .where((u) =>
                          u['app_role'] == 'admin' || u['app_role'] == 'super_admin')
                      .length
                      .toString(),
                  Icons.shield,
                  LG.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  'Заблокированные',
                  _users.where((u) => u['blocked'] == true).length.toString(),
                  Icons.block,
                  LG.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Прослушивания',
                  _beats.fold<int>(0, (s, b) => s + ((b['play_count'] as int?) ?? 0)).toString(),
                  Icons.headphones,
                  LG.pink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  'Публичных битов',
                  _beats.where((b) => b['visibility'] == 'PUBLIC').length.toString(),
                  Icons.public,
                  LG.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassPanel(
      borderRadius: 14,
      borderColor: color.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: LG.font(
                  color: LG.textPrimary,
                  size: 28,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: LG.font(
              color: LG.textSecondary,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}
