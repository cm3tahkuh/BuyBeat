import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/glass_theme.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  User? _user;
  bool _isLoading = true;
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSaving = false;

  @override void initState() { super.initState(); _loadUser(); }
  @override void dispose() { _displayNameController.dispose(); _usernameController.dispose(); _bioController.dispose(); super.dispose(); }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) setState(() { _user = user; _displayNameController.text = user?.displayName ?? ''; _usernameController.text = user?.username ?? ''; _bioController.text = user?.bio ?? ''; _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(displayName: _displayNameController.text.trim(), bio: _bioController.text.trim());
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль сохранён'))); await _loadUser(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Настройки'),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: LG.accent))
        : SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 100, 20, 40), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('Профиль', Icons.person, [
              _field('Отображаемое имя', _displayNameController, hint: 'Как вас видят другие'),
              const SizedBox(height: 16),
              _field('Имя пользователя', _usernameController, hint: 'username', enabled: false),
              const SizedBox(height: 16),
              _field('О себе', _bioController, hint: 'Расскажите о себе...', maxLines: 4),
              const SizedBox(height: 16),
              _infoRow('Email', _user?.email ?? '—', Icons.email),
              const SizedBox(height: 8),
              _infoRow('Роль', _getRoleText(_user!.appRole), Icons.badge),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: GlassButton(text: 'Сохранить изменения', icon: Icons.save, isLoading: _isSaving, onTap: _isSaving ? null : _saveProfile)),
            ]),
            const SizedBox(height: 24),
            _section('Аккаунт', Icons.security, [
              _actionTile(Icons.lock_outline, 'Сменить пароль', 'Изменить текущий пароль', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скоро будет доступно')))),
              Divider(color: LG.border),
              _actionTile(Icons.delete_outline, 'Удалить аккаунт', 'Безвозвратное удаление', _confirmDeleteAccount, color: LG.red),
            ]),
            const SizedBox(height: 24),
            _section('О приложении', Icons.info_outline, [
              _infoRow('Версия', '1.0.0', Icons.update),
              const SizedBox(height: 8),
              _infoRow('Сборка', '1', Icons.build_circle_outlined),
            ]),
          ]),
        ))),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: LG.bgLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Удалить аккаунт?', style: LG.font(weight: FontWeight.w700, size: 18)),
      content: Text('Это действие нельзя отменить.\nВсе ваши данные будут удалены безвозвратно.', style: LG.font(color: LG.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: LG.font(color: LG.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: LG.font(color: LG.red, weight: FontWeight.w700))),
      ],
    ));
    if (confirm != true) return;
    try {
      await _authService.deleteAccount();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e'))); }
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return GlassPanel(padding: const EdgeInsets.all(20), borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: LG.accent, size: 20), const SizedBox(width: 8), Text(title, style: LG.font(size: 16, weight: FontWeight.w700))]),
        const SizedBox(height: 16),
        ...children,
      ]));
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: LG.font(color: LG.textSecondary, size: 13, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, maxLines: maxLines, enabled: enabled,
        style: LG.font(color: enabled ? Colors.white : Colors.white38, size: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: LG.font(color: LG.textMuted),
          filled: true, fillColor: LG.bg.withValues(alpha: 0.5), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LG.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LG.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LG.accent)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: LG.border.withValues(alpha: 0.3))))),
    ]);
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: LG.textMuted), const SizedBox(width: 10),
      Text('$label:', style: LG.font(color: LG.textMuted, size: 13)), const SizedBox(width: 8),
      Flexible(child: Text(value, style: LG.font(color: LG.textSecondary, size: 13, weight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _actionTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c.withValues(alpha: 0.7), size: 22),
      title: Text(title, style: LG.font(color: c, size: 14, weight: FontWeight.w600)),
      subtitle: Text(subtitle, style: LG.font(color: c.withValues(alpha: 0.5), size: 12)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: c.withValues(alpha: 0.3)),
      onTap: onTap, contentPadding: EdgeInsets.zero,
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) { case UserRole.artist: return 'Артист'; case UserRole.producer: return 'Продюсер'; case UserRole.admin: return 'Администратор'; case UserRole.superAdmin: return 'Супер-администратор'; case UserRole.guest: return 'Гость'; }
  }
}
