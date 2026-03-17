import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/strapi_config.dart';
import 'strapi_service.dart';

/// Сервис аутентификации через Strapi API
class AuthService {
  final StrapiService _strapi = StrapiService.instance;
  
  User? _cachedUser;
  
  /// Инициализация сервиса
  Future<void> init() async {
    await _strapi.init();
    if (_strapi.isAuthenticated) {
      try {
        _cachedUser = await _fetchCurrentUser();
      } catch (e) {
        print('Ошибка загрузки пользователя: $e');
        await _strapi.clearToken();
      }
    }
  }
  
  /// Получить текущего пользователя
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    
    // Проверяем гостевой режим
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('is_guest') ?? false;
    if (isGuest) {
      _cachedUser = User(
        id: -1,
        username: 'Гость',
        displayName: 'Гость',
        appRole: UserRole.guest,
        isOnboarded: true,
      );
      return _cachedUser;
    }
    
    if (!_strapi.isAuthenticated) return null;
    
    try {
      _cachedUser = await _fetchCurrentUser();
      return _cachedUser;
    } catch (e) {
      print('Ошибка получения пользователя: $e');
      return null;
    }
  }
  
  /// Загрузить текущего пользователя с сервера
  Future<User> _fetchCurrentUser() async {
    final response = await _strapi.get(
      StrapiConfig.usersMe,
      queryParams: {'populate': 'avatar'},
    );
    return User.fromJson(response);
  }
  
  /// Проверка авторизован ли пользователь
  Future<bool> get isAuthenticated async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('is_guest') ?? false;
    return _strapi.isAuthenticated || isGuest;
  }
  
  /// ID текущего пользователя
  int? get currentUserId => _strapi.currentUserId;

  /// Сбросить кэш пользователя (принудительная перезагрузка с сервера)
  void invalidateCache() {
    _cachedUser = null;
  }

  /// Вход по email и паролю
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _strapi.post(
        StrapiConfig.authLogin,
        body: {
          'identifier': email,
          'password': password,
        },
      );
      
      final jwt = response['jwt'] as String;
      final userData = response['user'] as Map<String, dynamic>;
      final userId = userData['id'] as int;
      
      await _strapi.saveToken(jwt, userId);
      _cachedUser = User.fromJson(userData);
      
      // Убираем гостевой режим если был
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_guest');
      
      return _cachedUser!;
    } on StrapiException catch (e) {
      throw Exception('Ошибка входа: ${e.message}');
    }
  }

  /// Регистрация по email и паролю
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? username,
    UserRole appRole = UserRole.artist,
  }) async {
    try {
      final response = await _strapi.post(
        StrapiConfig.authRegister,
        body: {
          'username': username ?? email.split('@').first,
          'email': email,
          'password': password,
        },
      );

      final jwt = response['jwt'] as String;
      final userData = response['user'] as Map<String, dynamic>;
      final userId = userData['id'] as int;

      await _strapi.saveToken(jwt, userId);

      // Сохраняем display_name и app_role сразу после регистрации
      final extraData = <String, dynamic>{'app_role': appRole.name};
      if (displayName != null) extraData['display_name'] = displayName;

      await _strapi.put('${StrapiConfig.users}/$userId', body: extraData);

      _cachedUser = await _fetchCurrentUser();

      // Убираем гостевой режим если был
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_guest');

      return _cachedUser!;
    } on StrapiException catch (e) {
      throw Exception('Ошибка регистрации: ${e.message}');
    }
  }

  /// Вход как гость (локальный режим без сервера)
  Future<User> signInAsGuest() async {
    // Для гостевого режима создаём локального пользователя
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    
    _cachedUser = User(
      id: -1, // Локальный ID для гостя
      username: 'Гость',
      displayName: 'Гость',
      appRole: UserRole.guest,
      isOnboarded: true,
    );
    
    return _cachedUser!;
  }

  /// Выход
  Future<void> signOut() async {
    await _strapi.clearToken();
    _cachedUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest');
  }

  /// Обновить профиль пользователя
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    UserRole? appRole,
    bool? isOnboarded,
  }) async {
    final userId = _strapi.currentUserId;
    if (userId == null) throw Exception('Пользователь не авторизован');

    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (appRole != null) data['app_role'] = appRole.name;
    if (isOnboarded != null) data['is_onboarded'] = isOnboarded;

    if (data.isEmpty) return;

    await _strapi.put('${StrapiConfig.users}/$userId', body: data);

    // Обновляем кэш
    _cachedUser = await _fetchCurrentUser();
  }

  /// Обновить роль пользователя
  Future<void> updateUserRole(UserRole role, {int? userId}) async {
    await updateProfile(appRole: role);
  }

  /// Завершить онбординг
  Future<void> finishOnboarding(Set<int> genreIds, {int? userId}) async {
    await updateProfile(isOnboarded: true);
    // TODO: Сохранить предпочтения жанров в отдельную таблицу если нужно
  }

  /// Обновить описание профиля (bio)
  Future<void> updateBio(String bio, {int? userId}) async {
    await updateProfile(bio: bio);
  }

  /// Обновить имя пользователя
  Future<void> updateDisplayName(String displayName, {int? userId}) async {
    await updateProfile(displayName: displayName);
  }

  /// Удалить аккаунт текущего пользователя
  Future<void> deleteAccount() async {
    final userId = _strapi.currentUserId;
    if (userId == null) throw Exception('Пользователь не авторизован');

    await _strapi.delete('${StrapiConfig.users}/$userId');
    await _strapi.clearToken();
    _cachedUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest');
  }
}

/// Расширение для UserRole
extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.guest:
        return 'guest';
      case UserRole.artist:
        return 'artist';
      case UserRole.producer:
        return 'producer';
      case UserRole.admin:
        return 'admin';
      case UserRole.superAdmin:
        return 'super_admin';
    }
  }
}
