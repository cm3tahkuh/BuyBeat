import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../config/strapi_config.dart';
import 'strapi_service.dart';
import 'auth_service.dart';

/// Сервис избранных битов.
/// Хранит в памяти Set<String> documentId избранных битов,
/// синхронизируется с Strapi при загрузке и при toggle.
class FavoriteService extends ChangeNotifier {
  FavoriteService._();
  static final FavoriteService instance = FavoriteService._();

  final StrapiService _strapi = StrapiService.instance;
  final Set<String> _favoriteDocIds = {};
  bool _loaded = false;

  /// Набор documentId избранных битов (read-only snapshot).
  Set<String> get favoriteDocIds => Set.unmodifiable(_favoriteDocIds);

  /// Загружены ли данные.
  bool get loaded => _loaded;

  /// Находится ли бит в избранном.
  bool isFavorite(String? documentId) {
    if (documentId == null) return false;
    return _favoriteDocIds.contains(documentId);
  }

  /// Загрузить список избранного текущего пользователя.
  /// Должен вызываться после авторизации.
  Future<void> loadFavorites() async {
    final user = await AuthService().getCurrentUser();
    if (user == null || user.isGuest) {
      _favoriteDocIds.clear();
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final res = await _strapi.get('${StrapiConfig.apiUrl}/favorites/my');
      final list = res['data'];
      _favoriteDocIds.clear();
      if (list is List) {
        for (final id in list) {
          if (id is String) _favoriteDocIds.add(id);
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FavoriteService.loadFavorites error: $e');
    }
  }

  /// Переключить избранное (add / remove).
  /// Мгновенно обновляет UI (optimistic), затем синхронизирует с сервером.
  Future<void> toggle(String documentId) async {
    // Optimistic update
    final wasInFavorites = _favoriteDocIds.contains(documentId);
    if (wasInFavorites) {
      _favoriteDocIds.remove(documentId);
    } else {
      _favoriteDocIds.add(documentId);
    }
    notifyListeners();

    try {
      final res = await _strapi.post(
        '${StrapiConfig.apiUrl}/favorites/toggle',
        body: {'beatDocumentId': documentId},
      );
      final favorited = res['favorited'] as bool? ?? !wasInFavorites;
      // Sync with server truth
      if (favorited) {
        _favoriteDocIds.add(documentId);
      } else {
        _favoriteDocIds.remove(documentId);
      }
      notifyListeners();
    } catch (e) {
      // Revert on error
      if (wasInFavorites) {
        _favoriteDocIds.add(documentId);
      } else {
        _favoriteDocIds.remove(documentId);
      }
      notifyListeners();
      debugPrint('FavoriteService.toggle error: $e');
      rethrow;
    }
  }

  /// Очистить кэш при logout.
  void clear() {
    _favoriteDocIds.clear();
    _loaded = false;
    notifyListeners();
  }
}
