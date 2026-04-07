import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/genre.dart';
import '../../services/auth_service.dart';
import '../../services/beat_service.dart';
import '../../config/glass_theme.dart';

/// Экран выбора жанров (второй шаг онбординга)
class GenreSelectionScreen extends StatefulWidget {
  final User user;

  const GenreSelectionScreen({super.key, required this.user});

  @override
  State<GenreSelectionScreen> createState() => _GenreSelectionScreenState();
}

class _GenreSelectionScreenState extends State<GenreSelectionScreen> {
  final _authService = AuthService();
  final _beatService = BeatService.instance;
  List<Genre> _genres = [];
  Set<int> _selectedGenres = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      // Загружаем жанры из Strapi
      final genres = await _beatService.getAllGenres();
      setState(() {
        _genres = genres;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки жанров: $e')),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один жанр')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Сохраняем предпочтения жанров и завершаем онбординг
      await _authService.finishOnboarding(_selectedGenres);

      if (!mounted) return;

      // Переходим в приложение
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
      setState(() {
        _isSaving = false;
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
                  Container(width: 8, height: 2, color: LG.accent),
                  _buildProgressStep(2, true),
                ],
              ),
              const SizedBox(height: 32),

              // Заголовок
              Text(
                'Выберите интересующие жанры',
                style: LG.font(size: 32, weight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Мы будем показывать вам биты по выбранным жанрам',
                style: LG.font(size: 16, color: LG.textSecondary),
              ),
              const SizedBox(height: 32),

              // Список жанров
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: LG.accent))
                    : _genres.isEmpty
                        ? Center(
                            child: Text(
                              'Жанры не найдены.\nПроверьте подключение к серверу.',
                              textAlign: TextAlign.center,
                              style: LG.font(color: LG.textSecondary, size: 16),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.5,
                            ),
                            itemCount: _genres.length,
                            itemBuilder: (context, index) {
                              final genre = _genres[index];
                              final isSelected = _selectedGenres.contains(genre.id);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedGenres.remove(genre.id);
                                    } else {
                                      _selectedGenres.add(genre.id);
                                    }
                                  });
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(LG.radiusM),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: LG.blurLight, sigmaY: LG.blurLight),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? LG.accent.withValues(alpha: 0.15)
                                            : LG.panelFill,
                                        borderRadius: BorderRadius.circular(LG.radiusM),
                                        border: Border.all(
                                          color: isSelected
                                              ? LG.accent.withValues(alpha: 0.5)
                                              : LG.border,
                                          width: isSelected ? 1.5 : 0.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              genre.name,
                                              style: LG.font(
                                                size: 16,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              const SizedBox(height: 24),

              // Кнопка завершить
              GlassButton(
                text: 'Завершить',
                onTap: _selectedGenres.isNotEmpty && !_isSaving
                    ? _finishOnboarding
                    : null,
                isLoading: _isSaving,
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
}
