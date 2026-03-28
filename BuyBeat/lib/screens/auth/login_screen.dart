import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/glass_theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';

/// Экран входа — Liquid Glass
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  UserRole _selectedRole = UserRole.artist;
  String? _error;

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSignUp && _selectedRole == UserRole.guest) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        appRole: _selectedRole,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LG.accentGradient,
                      boxShadow: [
                        BoxShadow(color: LG.accent.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.music_note_rounded, size: 40, color: Color(0xFF0A0A0F)),
                  ),
                  const SizedBox(height: 20),
                  Text('BuyBeat', style: LG.h1),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUp ? 'Создать аккаунт' : 'Добро пожаловать',
                    style: LG.font(size: 15, color: LG.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Form card
                  GlassPanel(
                    padding: const EdgeInsets.all(24),
                    borderRadius: LG.radiusXL,
                    blur: LG.blurMedium,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tabs
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: LG.panelFill,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(children: [
                              _tabButton('Вход', !_isSignUp),
                              _tabButton('Регистрация', _isSignUp),
                            ]),
                          ),
                          const SizedBox(height: 24),

                          if (_isSignUp) ...[
                            GlassTextField(controller: _nameController, label: 'Имя', prefixIcon: Icons.person_rounded),
                            const SizedBox(height: 16),
                            Text('Я являюсь', style: LG.label),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _roleCard('Артист', Icons.mic, UserRole.artist)),
                              const SizedBox(width: 12),
                              Expanded(child: _roleCard('Продюсер', Icons.headphones, UserRole.producer)),
                            ]),
                            const SizedBox(height: 16),
                          ],

                          GlassTextField(
                            controller: _emailController, label: 'Email', prefixIcon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите email';
                              if (!v.contains('@')) return 'Некорректный email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          GlassTextField(
                            controller: _passwordController, label: 'Пароль', prefixIcon: Icons.lock_rounded,
                            obscure: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите пароль';
                              if (_isSignUp && v.length < 6) return 'Минимум 6 символов';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          GlassButton(
                            text: _isSignUp ? 'Зарегистрироваться' : 'Войти',
                            onTap: _isSignUp ? _signUpWithEmail : _signInWithEmail,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      borderRadius: LG.radiusS,
                      borderColor: LG.red.withValues(alpha: 0.4),
                      fill: LG.red.withValues(alpha: 0.08),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: LG.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: LG.font(size: 13, color: LG.red))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _isSignUp = label == 'Регистрация'; _error = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? LG.accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label, style: LG.font(size: 14, weight: FontWeight.w600, color: active ? LG.accent : LG.textMuted)),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(String label, IconData icon, UserRole role) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? LG.accent.withValues(alpha: 0.12) : LG.panelFill,
          borderRadius: BorderRadius.circular(LG.radiusS),
          border: Border.all(
            color: selected ? LG.accent.withValues(alpha: 0.5) : LG.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? LG.accent : LG.textMuted, size: 26),
          const SizedBox(height: 6),
          Text(label, style: LG.font(size: 13, weight: FontWeight.w600, color: selected ? LG.accent : LG.textSecondary)),
        ]),
      ),
    );
  }
}
