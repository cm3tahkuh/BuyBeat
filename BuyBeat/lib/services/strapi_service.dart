import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/strapi_config.dart';

/// Базовый сервис для работы со Strapi REST API
class StrapiService {
  static const String _tokenKey = 'strapi_jwt_token';
  static const String _userIdKey = 'strapi_user_id';
  static const Duration _kTimeout = Duration(seconds: 12);
  
  static StrapiService? _instance;
  static StrapiService get instance => _instance ??= StrapiService._();
  
  StrapiService._();
  
  String? _token;
  int? _userId;
  
  /// Инициализация сервиса — загрузка токена из хранилища
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getInt(_userIdKey);
  }
  
  /// Сохранение токена после логина
  Future<void> saveToken(String token, int userId) async {
    _token = token;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, userId);
  }
  
  /// Очистка токена при выходе
  Future<void> clearToken() async {
    _token = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
  
  /// Проверка авторизации
  bool get isAuthenticated => _token != null;
  
  /// ID текущего пользователя
  int? get currentUserId => _userId;
  
  /// Заголовки для запросов
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
  
  /// GET запрос — возвращает dynamic (может быть Map или List)
  Future<dynamic> get(
    String url, {
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse(url);
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    
    final response = await http.get(uri, headers: _headers).timeout(_kTimeout);
    return _handleResponseDynamic(response);
  }
  
  /// POST запрос
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_kTimeout);
    return _handleResponse(response);
  }
  
  /// PUT запрос
  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.put(
      Uri.parse(url),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_kTimeout);
    return _handleResponse(response);
  }
  
  /// DELETE запрос
  Future<Map<String, dynamic>> delete(String url) async {
    final response = await http.delete(
      Uri.parse(url),
      headers: _headers,
    ).timeout(_kTimeout);
    return _handleResponse(response);
  }

  /// Загрузка файла (multipart) — возвращает список загруженных файлов
  /// Strapi Upload API: POST /api/upload
  Future<List<Map<String, dynamic>>> uploadFile({
    required String filePath,
    required String fileName,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('${StrapiConfig.apiUrl}/upload'));

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'files',
        filePath,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(minutes: 3));
    final responseBody = await streamedResponse.stream.bytesToString().timeout(const Duration(minutes: 3));
    final decoded = jsonDecode(responseBody);

    if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => e as Map<String, dynamic>),
        );
      }
      return [];
    }

    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = error?['message'] ?? 'Ошибка загрузки файла';
      throw StrapiException(message, streamedResponse.statusCode);
    }
    throw StrapiException('Ошибка загрузки файла', streamedResponse.statusCode);
  }

  /// Загрузка файла из bytes (для web)
  Future<List<Map<String, dynamic>>> uploadFileBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${StrapiConfig.apiUrl}/upload'),
    );

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(minutes: 3));
    final responseBody = await streamedResponse.stream.bytesToString().timeout(const Duration(minutes: 3));
    final decoded = jsonDecode(responseBody);

    if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => e as Map<String, dynamic>),
        );
      }
      return [];
    }

    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = error?['message'] ?? 'Ошибка загрузки файла';
      throw StrapiException(message, streamedResponse.statusCode);
    }
    throw StrapiException('Ошибка загрузки файла', streamedResponse.statusCode);
  }
  
  /// Обработка ответа — возвращает dynamic (Map или List)
  dynamic _handleResponseDynamic(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body);
    }

    if (response.body.isEmpty) {
      throw StrapiException('Ошибка ${response.statusCode}', response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>?;
      final message = error?['message'] ?? 'Неизвестная ошибка';
      throw StrapiException(message, response.statusCode);
    }
    throw StrapiException('Неизвестная ошибка', response.statusCode);
  }

  /// Обработка ответа
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.body.isEmpty) {
      throw StrapiException('Ошибка ${response.statusCode}', response.statusCode);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final error = body['error'] as Map<String, dynamic>?;
    final message = error?['message'] ?? 'Неизвестная ошибка';
    throw StrapiException(message, response.statusCode);
  }
  
  /// Парсинг Strapi response с data wrapper
  /// Strapi v5 возвращает { data: { id, name, ... } } (плоский)
  /// Strapi v4 возвращает { data: { id, attributes: {...} } }
  static Map<String, dynamic>? parseItem(dynamic response) {
    if (response == null) return null;
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data == null) return null;
      
      if (data is Map<String, dynamic>) {
        return _flattenStrapiItem(data);
      }
      // Если нет обёртки data — возвращаем сам объект
      return response;
    }
    return null;
  }
  
  /// Парсинг списка из Strapi response
  static List<Map<String, dynamic>> parseList(dynamic response) {
    if (response == null) return [];
    
    // Если response сам является List (например /api/users)
    if (response is List) {
      return List<Map<String, dynamic>>.from(
        response.map((e) => e as Map<String, dynamic>),
      );
    }
    
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data == null) return [];
      
      if (data is List) {
        return data
            .map((item) => _flattenStrapiItem(item as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }
  
  /// Преобразование Strapi формата в плоский объект
  /// Strapi v4: { id, attributes: {...} } → { id, ...attributes }
  /// Strapi v5: { id, name, ... } → возвращает как есть
  static Map<String, dynamic> _flattenStrapiItem(Map<String, dynamic> item) {
    final id = item['id'];
    final attributes = item['attributes'] as Map<String, dynamic>?;
    
    // Strapi v5 — нет attributes, объект уже плоский
    if (attributes == null) {
      return item;
    }
    
    // Strapi v4 — разворачиваем attributes
    final result = <String, dynamic>{'id': id};
    
    for (final entry in attributes.entries) {
      final value = entry.value;
      
      // Обработка вложенных связей (relation)
      if (value is Map<String, dynamic> && value.containsKey('data')) {
        final nestedData = value['data'];
        if (nestedData is Map<String, dynamic>) {
          result[entry.key] = _flattenStrapiItem(nestedData);
        } else if (nestedData is List) {
          result[entry.key] = nestedData
              .map((i) => _flattenStrapiItem(i as Map<String, dynamic>))
              .toList();
        } else {
          result[entry.key] = null;
        }
      } else {
        result[entry.key] = value;
      }
    }
    
    return result;
  }
}

/// Исключение Strapi API
class StrapiException implements Exception {
  final String message;
  final int statusCode;
  
  StrapiException(this.message, this.statusCode);
  
  @override
  String toString() => 'StrapiException: $message (status: $statusCode)';
}
