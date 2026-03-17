import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../config/glass_theme.dart';
import 'genre_selection_screen.dart';

/// Экран выбора роли (первый шаг онбординга)
class RoleSelectionScreen extends StatefulWidget {
  final User user;

  const RoleSelectionScreen({super.key, required this.user});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _continue() async {
    if (_selectedRole == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Обновляем роль пользователя
      await _authService.updateUserRole(_selectedRole!);

      if (!mounted) return;

      // Переходим к выбору жанров
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GenreSelectionScreen(
            user: widget.user.copyWith(appRole: _selectedRole!),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        showBack: true,
        title: '',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Прогресс
              Row(
                children: [
                  _buildProgressStep(1, true),
                  Container(width: 8, height: 2, color: LG.textMuted),
                  _buildProgressStep(2, false),
                ],
              ),
              const SizedBox(height: 32),

              // Заголовок
              Text(
                'Выберите вашу роль',
                style: LG.font(size: 32, weight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Это поможет нам настроить приложение под вас',
                style: LG.font(size: 16, color: LG.textSecondary),
              ),
              const SizedBox(height: 48),

              // Выбор роли: Артист
              _buildRoleCard(
                role: UserRole.artist,
                title: 'Артист',
                description: 'Ищу биты для своих треков',
                icon: Icons.mic,
                color: LG.accent,
              ),
              const SizedBox(height: 16),

              // Выбор роли: Продюсер
              _buildRoleCard(
                role: UserRole.producer,
                title: 'Продюсер',
                description: 'Создаю и продаю биты',
                icon: Icons.music_note,
                color: LG.cyan,
              ),
              const Spacer(),

              // Кнопка продолжить
              GlassButton(
                text: 'Продолжить',
                onTap: _selectedRole != null && !_isLoading ? _continue : null,
                isLoading: _isLoading,
                height: 56,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? LG.accent : LG.panelFill,
        border: Border.all(
          color: isActive ? LG.accent : LG.border,
          width: isActive ? 0 : 0.5,
        ),
      ),
      child: Center(
        child: Text(
          '$step',
          style: LG.font(weight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LG.radiusL),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: LG.blurLight, sigmaY: LG.blurLight),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : LG.panelFill,
              borderRadius: BorderRadius.circular(LG.radiusL),
              border: Border.all(
                color: isSelected ? color.withValues(alpha: 0.5) : LG.border,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? color : LG.panelFillLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isSelected ? const Color(0xFF0A0A0F) : Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: LG.font(size: 18, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: LG.font(size: 14, color: LG.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: LG.accent, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
