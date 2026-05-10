import 'package:flutter/foundation.dart' show debugPrint;
import '../models/beat.dart';
import '../models/genre.dart';
import '../models/tag.dart';
import '../models/beat_file.dart';
import '../config/strapi_config.dart';
import 'strapi_service.dart';

/// Сервис для работы с битами через Strapi API
class BeatService {
  final StrapiService _strapi = StrapiService.instance;
  
  static BeatService? _instance;
  static BeatService get instance => _instance ??= BeatService._();
  
  BeatService._();

  /// Получить все биты
  Future<List<Beat>> getAllBeats({
    int page = 1,
    int pageSize = 25,
  }) async {
    final response = await _strapi.get(
      StrapiConfig.beats,
      queryParams: {
        'populate[users_permissions_user][fields][0]': 'id',
        'populate[users_permissions_user][fields][1]': 'username',
        'populate[users_permissions_user][fields][2]': 'display_name',
        'populate[genre][fields][0]': 'id',
        'populate[genre][fields][1]': 'name',
        'populate[tags][fields][0]': 'id',
        'populate[tags][fields][1]': 'name',
        'populate[cover][fields][0]': 'url',
        'populate[cover][fields][1]': 'name',
        'populate[audio_preview][fields][0]': 'url',
        'populate[audio_preview][fields][1]': 'name',
        'pagination[page]': page.toString(),
        'pagination[pageSize]': pageSize.toString(),
        'sort': 'createdAt:desc',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => Beat.fromJson(json)).toList();
  }

  /// Получить бит по ID
  Future<Beat?> getBeatById(int id) async {
    try {
      final response = await _strapi.get(
        '${StrapiConfig.beats}/$id',
        queryParams: {
          'populate': '*',
        },
      );
      
      final item = StrapiService.parseItem(response);
      if (item == null) return null;
      return Beat.fromJson(item);
    } on StrapiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Поиск битов по названию
  Future<List<Beat>> searchBeats(String query) async {
    final response = await _strapi.get(
      StrapiConfig.beats,
      queryParams: {
        'populate': '*',
        'filters[title][\$containsi]': query,
        'sort': 'createdAt:desc',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => Beat.fromJson(json)).toList();
  }

  /// Получить биты по продюсеру
  Future<List<Beat>> getBeatsByProducer(int producerId) async {
    final response = await _strapi.get(
      StrapiConfig.beats,
      queryParams: {
        'populate': '*',
        'filters[users_permissions_user][id][\$eq]': producerId.toString(),
        'sort': 'createdAt:desc',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => Beat.fromJson(json)).toList();
  }

  /// Получить биты по жанру
  Future<List<Beat>> getBeatsByGenre(int genreId) async {
    final response = await _strapi.get(
      StrapiConfig.beats,
      queryParams: {
        'populate': '*',
        'filters[genre][id][\$eq]': genreId.toString(),
        'sort': 'createdAt:desc',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => Beat.fromJson(json)).toList();
  }

  /// Фильтрация битов
  Future<List<Beat>> filterBeats({
    int? genreId,
    String? mood,
    int? minBpm,
    int? maxBpm,
    BeatVisibility? visibility,
    List<int>? tagIds,
  }) async {
    final queryParams = <String, String>{
      'populate': '*',
      'sort': 'createdAt:desc',
    };
    
    if (genreId != null) {
      queryParams['filters[genre][id][\$eq]'] = genreId.toString();
    }
    if (mood != null) {
      queryParams['filters[mood][\$eq]'] = mood;
    }
    if (minBpm != null) {
      queryParams['filters[bpm][\$gte]'] = minBpm.toString();
    }
    if (maxBpm != null) {
      queryParams['filters[bpm][\$lte]'] = maxBpm.toString();
    }
    if (visibility != null) {
      final visibilityStr = visibility == BeatVisibility.public ? 'PUBLIC' : 'SOLD_EXCLUSIVE';
      queryParams['filters[visibility][\$eq]'] = visibilityStr;
    }
    if (tagIds != null && tagIds.isNotEmpty) {
      for (var i = 0; i < tagIds.length; i++) {
        queryParams['filters[tags][id][\$in][$i]'] = tagIds[i].toString();
      }
    }
    
    final response = await _strapi.get(StrapiConfig.beats, queryParams: queryParams);
    final items = StrapiService.parseList(response);
    return items.map((json) => Beat.fromJson(json)).toList();
  }

  /// Загрузить биты по списку documentId
  Future<List<Beat>> getBeatsByDocumentIds(List<String> docIds) async {
    if (docIds.isEmpty) return [];
    final queryParams = <String, String>{
      'populate': '*',
      'pagination[pageSize]': '100',
    };
    for (var i = 0; i < docIds.length; i++) {
      queryParams['filters[documentId][\$in][$i]'] = docIds[i];
    }
    final response = await _strapi.get(StrapiConfig.beats, queryParams: queryParams);
    final items = StrapiService.parseList(response);
    return items.map((json) => Beat.fromJson(json)).toList();
  }

  /// Создать новый бит
  Future<Beat> createBeat({
    required String title,
    required int producerId,
    required int genreId,
    required double priceBase,
    int? bpm,
    String? key,
    String? mood,
    int? durationSeconds,
    BeatVisibility visibility = BeatVisibility.public,
    List<int>? tagIds,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'users_permissions_user': producerId,
      'genre': genreId,
      'price_base': priceBase,
      'visibility': visibility == BeatVisibility.public ? 'PUBLIC' : 'SOLD_EXCLUSIVE',
    };
    
    if (bpm != null) data['bpm'] = bpm;
    if (key != null) data['key'] = key;
    if (mood != null) data['mood'] = mood;
    if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
    if (tagIds != null) data['tags'] = tagIds;
    
    final response = await _strapi.post(
      StrapiConfig.beats,
      body: {'data': data},
    );
    
    final item = StrapiService.parseItem(response);
    return Beat.fromJson(item!);
  }

  /// Обновить бит
  Future<Beat> updateBeat(int id, {
    String? title,
    int? genreId,
    double? priceBase,
    int? bpm,
    String? key,
    String? mood,
    int? durationSeconds,
    BeatVisibility? visibility,
    List<int>? tagIds,
    int? coverId,
    bool clearCover = false,
  }) async {
    final data = <String, dynamic>{};
    
    if (title != null) data['title'] = title;
    if (genreId != null) data['genre'] = genreId;
    if (priceBase != null) data['price_base'] = priceBase;
    if (bpm != null) data['bpm'] = bpm;
    if (key != null) data['key'] = key;
    if (mood != null) data['mood'] = mood;
    if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
    if (visibility != null) {
      data['visibility'] = visibility == BeatVisibility.public ? 'PUBLIC' : 'SOLD_EXCLUSIVE';
    }
    if (tagIds != null) data['tags'] = tagIds;
    if (clearCover) {
      data['cover'] = null;
    } else if (coverId != null) {
      data['cover'] = coverId;
    }
    
    final response = await _strapi.put(
      '${StrapiConfig.beats}/$id',
      body: {'data': data},
    );
    
    final item = StrapiService.parseItem(response);
    return Beat.fromJson(item!);
  }

  /// Обновить бит по documentId (Strapi v5)
  Future<Beat> updateBeatByDocId(String documentId, {
    String? title,
    int? genreId,
    double? priceBase,
    int? bpm,
    String? key,
    String? mood,
    int? durationSeconds,
    BeatVisibility? visibility,
    List<int>? tagIds,
    int? coverId,
    bool clearCover = false,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (genreId != null) data['genre'] = genreId;
    if (priceBase != null) data['price_base'] = priceBase;
    if (bpm != null) data['bpm'] = bpm;
    if (key != null) data['key'] = key;
    if (mood != null) data['mood'] = mood;
    if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
    if (visibility != null) data['visibility'] = visibility == BeatVisibility.public ? 'PUBLIC' : 'SOLD_EXCLUSIVE';
    if (tagIds != null) data['tags'] = tagIds;
    if (clearCover) {
      data['cover'] = null;
    } else if (coverId != null) {
      data['cover'] = coverId;
    }

    final response = await _strapi.put(
      '${StrapiConfig.beats}/$documentId',
      body: {'data': data},
    );
    final item = StrapiService.parseItem(response);
    return Beat.fromJson(item!);
  }

  /// Удалить бит
  Future<void> deleteBeat(int id) async {
    await _strapi.delete('${StrapiConfig.beats}/$id');
  }

  /// Удалить бит по documentId (Strapi v5)
  Future<void> deleteBeatByDocId(String documentId) async {
    await _strapi.delete('${StrapiConfig.beats}/$documentId');
  }

  // ============ Жанры ============

  /// Получить все жанры
  Future<List<Genre>> getAllGenres() async {
    final response = await _strapi.get(
      StrapiConfig.genres,
      queryParams: {
        'pagination[pageSize]': '100',
        'sort': 'name:asc',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => Genre.fromJson(json)).toList();
  }

  // ============ Теги ============

  /// Получить все теги
  Future<List<Tag>> getAllTags() async {
    final response = await _strapi.get(
      StrapiConfig.tags,
      queryParams: {
        'pagination[pageSize]': '100',
        'sort': 'name:asc',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => Tag.fromJson(json)).toList();
  }

  /// Создать новый тег
  Future<Tag> createTag(String name) async {
    final response = await _strapi.post(
      StrapiConfig.tags,
      body: {
        'data': {
          'name': name.trim(),
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка создания тега');
    return Tag.fromJson(item);
  }

  // ============ Файлы битов ============

  /// Получить файлы бита
  Future<List<BeatFile>> getBeatFiles(int beatId) async {
    final response = await _strapi.get(
      StrapiConfig.beatFiles,
      queryParams: {
        'filters[beat][id][\$eq]': beatId.toString(),
        'filters[enabled][\$eq]': 'true',
        'populate[audio_file][fields][0]': 'url',
        'populate[audio_file][fields][1]': 'name',
        'populate[audio_file][fields][2]': 'size',
        'populate[beat][fields][0]': 'id',
      },
    );
    
    final items = StrapiService.parseList(response);
    return items.map((json) => BeatFile.fromJson(json)).toList();
  }

  // ============ Прослушивания ============

  /// Зафиксировать прослушивание бита — вызывать один раз при начале воспроизведения.
  /// [documentId] — documentId бита (строковый идентификатор Strapi 5).
  /// Инкремент прослушиваний. Возвращает новое значение play_count или null при ошибке.
  Future<int?> incrementPlayCount(String documentId) async {
    try {
      final res = await _strapi.post(
        '${StrapiConfig.beats}/$documentId/play',
      );
      return (res['play_count'] as num?)?.toInt();
    } catch (e) {
      // Не блокируем воспроизведение при ошибке
      debugPrint('incrementPlayCount error: $e');
      return null;
    }
  }
}

