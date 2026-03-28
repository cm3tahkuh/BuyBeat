import '../models/chat.dart';
import '../models/message.dart';
import '../config/strapi_config.dart';
import 'strapi_service.dart';
import 'auth_service.dart';

/// Сервис для работы с чатами и сообщениями через Strapi API
class ChatService {
  final StrapiService _strapi = StrapiService.instance;

  static ChatService? _instance;
  static ChatService get instance => _instance ??= ChatService._();

  ChatService._();

  /// Общие параметры populate для одного сообщения (Strapi 5 media-safe)
  static const _msgPopulate = <String, String>{
    'populate[users_permissions_user][populate]': 'avatar',
    'populate[file_attachment][fields][0]': 'url',
    'populate[file_attachment][fields][1]': 'name',
    'populate[file_attachment][fields][2]': 'mime',
    'populate[file_attachment][fields][3]': 'size',
    'populate[chat][fields][0]': 'id',
    'populate[chat][fields][1]': 'documentId',
    'populate[reply_to][populate][users_permissions_user][fields][0]': 'id',
    'populate[reply_to][populate][users_permissions_user][fields][1]': 'username',
    'populate[reply_to][populate][users_permissions_user][fields][2]': 'display_name',
    'populate[reply_to][fields][0]': 'id',
    'populate[reply_to][fields][1]': 'documentId',
    'populate[reply_to][fields][2]': 'text',
    'populate[reply_to][fields][3]': 'type',
  };

  // ============ ЧАТЫ ============

  /// Получить все чаты текущего пользователя
  Future<List<Chat>> getMyChats() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return [];

    final response = await _strapi.get(
      StrapiConfig.chats,
      queryParams: {
        'populate[users_permissions_users][populate]': 'avatar',
        'populate[messages][fields][0]': 'text',
        'populate[messages][fields][1]': 'type',
        'populate[messages][fields][2]': 'createdAt',
        'populate[messages][populate][file_attachment][fields][0]': 'mime',
        'populate[messages][populate][file_attachment][fields][1]': 'name',
        'filters[users_permissions_users][id][\$eq]': user.id.toString(),
        'sort': 'updatedAt:desc',
        'pagination[pageSize]': '100',
      },
    );

    final items = StrapiService.parseList(response);
    return items.map((json) => Chat.fromJson(json)).toList();
  }

  /// Получить чат по documentId (для навигации из уведомления)
  Future<Chat?> getChatByDocumentId(String documentId) async {
    try {
      print('🔔 getChatByDocumentId: fetching $documentId ...');
      final response = await _strapi.get(
        StrapiConfig.chats,
        queryParams: {
          'filters[documentId][\$eq]': documentId,
          'populate[users_permissions_users][populate]': 'avatar',
          'populate[messages][fields][0]': 'text',
          'populate[messages][fields][1]': 'type',
          'populate[messages][fields][2]': 'createdAt',
          'populate[messages][populate][file_attachment][fields][0]': 'mime',
          'populate[messages][populate][file_attachment][fields][1]': 'name',
          'pagination[pageSize]': '1',
        },
      );
      final items = StrapiService.parseList(response);
      print('🔔 getChatByDocumentId: got ${items.length} items');
      if (items.isEmpty) return null;
      return Chat.fromJson(items.first);
    } catch (e) {
      print('🔔 getChatByDocumentId error: $e');
      return null;
    }
  }

  // Мьютекс для предотвращения параллельного создания чатов
  static Future<Chat>? _pendingCreate;

  /// Получить или создать чат между текущим пользователем и другим
  Future<Chat> getOrCreateChat(int otherUserId) async {
    // Если уже идёт создание — ждём его результат
    if (_pendingCreate != null) {
      try { return await _pendingCreate!; } catch (_) {}
    }
    final completer = _pendingCreate = _getOrCreateChatImpl(otherUserId);
    try {
      return await completer;
    } finally {
      if (_pendingCreate == completer) _pendingCreate = null;
    }
  }

  Future<Chat> _getOrCreateChatImpl(int otherUserId) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    // Ищем ВСЕ чаты текущего пользователя и фильтруем на клиенте
    final response = await _strapi.get(
      StrapiConfig.chats,
      queryParams: {
        'populate[users_permissions_users][fields][0]': 'id',
        'populate[users_permissions_users][fields][1]': 'username',
        'populate[users_permissions_users][fields][2]': 'display_name',
        'populate[users_permissions_users][populate]': 'avatar',
        'filters[users_permissions_users][id][\$eq]': user.id.toString(),
        'pagination[pageSize]': '200',
      },
    );

    final items = StrapiService.parseList(response);
    for (final json in items) {
      final chat = Chat.fromJson(json);
      // Проверяем на клиенте что оба пользователя — участники
      if (chat.participants != null) {
        final ids = chat.participants!
            .where((p) => p is Map<String, dynamic>)
            .map((p) => (p as Map<String, dynamic>)['id'] as int)
            .toSet();
        if (ids.contains(otherUserId) && ids.contains(user.id)) {
          return chat;
        }
      }
    }

    // Получаем информацию о собеседнике ДО создания чата
    Map<String, dynamic> otherUserInfo = {'id': otherUserId};
    try {
      final userResp = await _strapi.get('${StrapiConfig.users}/$otherUserId');
      if (userResp is Map<String, dynamic>) {
        otherUserInfo = {
          'id': userResp['id'] ?? otherUserId,
          'username': userResp['username'],
          'display_name': userResp['display_name'],
        };
      }
    } catch (_) {}

    // Создаём новый чат
    final createResponse = await _strapi.post(
      StrapiConfig.chats,
      body: {
        'data': {
          'users_permissions_users': [user.id, otherUserId],
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    // Перечитываем с populate чтобы получить participants
    final newItem = StrapiService.parseItem(createResponse);
    if (newItem == null) throw Exception('Ошибка создания чата');
    final chatId = newItem['id'] as int;
    final chatDocId = newItem['documentId'] as String?;

    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.chats}/${chatDocId ?? chatId}',
        queryParams: {
          'populate[users_permissions_users][populate]': 'avatar',
          'populate[users_permissions_users][fields][0]': 'id',
          'populate[users_permissions_users][fields][1]': 'username',
          'populate[users_permissions_users][fields][2]': 'display_name',
        },
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) return Chat.fromJson(freshItem);
    } catch (_) {}

    return Chat(
      id: chatId,
      documentId: chatDocId,
      participants: [
        {'id': user.id, 'username': user.username, 'display_name': user.displayName},
        otherUserInfo,
      ],
      messages: [],
    );
  }

  // ============ СООБЩЕНИЯ ============

  /// Получить сообщения чата (по documentId чата)
  Future<List<Message>> getChatMessages(String chatDocumentId, {int page = 1, int pageSize = 50}) async {
    final response = await _strapi.get(
      StrapiConfig.messages,
      queryParams: {
        ..._msgPopulate,
        'filters[chat][documentId][\$eq]': chatDocumentId,
        'sort': 'createdAt:asc',
        'pagination[page]': page.toString(),
        'pagination[pageSize]': pageSize.toString(),
      },
    );

    final items = StrapiService.parseList(response);
    return items.map((json) => Message.fromJson(json)).toList();
  }

  /// Отправить текстовое сообщение
  Future<Message> sendMessage({
    required String chatDocumentId,
    required String text,
    String? replyToDocumentId,
  }) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final response = await _strapi.post(
      StrapiConfig.messages,
      body: {
        'data': {
          'chat': chatDocumentId,
          'users_permissions_user': user.id,
          'type': 'TEXT',
          'text': text,
          if (replyToDocumentId != null) 'reply_to': replyToDocumentId,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    // Обновляем updatedAt чата
    try {
      await _strapi.put(
        '${StrapiConfig.chats}/$chatDocumentId',
        body: {'data': {}},
      );
    } catch (_) {}

    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка отправки сообщения');
    final msgRef = item['documentId'] as String? ?? item['id'].toString();

    // Re-fetch with populate to get full sender object
    Message? freshMsg;
    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.messages}/$msgRef',
        queryParams: _msgPopulate,
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) freshMsg = Message.fromJson(freshItem);
    } catch (_) {}
    return freshMsg ?? Message.fromJson(item);
  }

  /// Отправить файл
  Future<Message> sendFile({
    required String chatDocumentId,
    required String filePath,
    required String fileName,
  }) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final uploadResponse = await _strapi.uploadFile(filePath: filePath, fileName: fileName);
    final fileId = uploadResponse[0]['id'];

    final response = await _strapi.post(
      StrapiConfig.messages,
      body: {
        'data': {
          'chat': chatDocumentId,
          'users_permissions_user': user.id,
          'type': 'FILE',
          'file_attachment': fileId,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    try {
      await _strapi.put(
        '${StrapiConfig.chats}/$chatDocumentId',
        body: {'data': {}},
      );
    } catch (_) {}

    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка отправки файла');
    final msgRef = item['documentId'] as String? ?? item['id'].toString();

    Message? freshMsg;
    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.messages}/$msgRef',
        queryParams: _msgPopulate,
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) freshMsg = Message.fromJson(freshItem);
    } catch (_) {}
    return freshMsg ?? Message.fromJson(item);
  }

  /// Отправить файл из bytes (web)
  Future<Message> sendFileBytes({
    required String chatDocumentId,
    required List<int> bytes,
    required String fileName,
    String? text,
    String? replyToDocumentId,
  }) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final uploadResponse = await _strapi.uploadFileBytes(bytes: bytes, fileName: fileName);
    if (uploadResponse.isEmpty) throw Exception('Файл не загружен');
    final fileId = uploadResponse[0]['id'];

    final response = await _strapi.post(
      StrapiConfig.messages,
      body: {
        'data': {
          'chat': chatDocumentId,
          'users_permissions_user': user.id,
          'type': 'FILE',
          if (text != null) 'text': text,
          if (replyToDocumentId != null) 'reply_to': replyToDocumentId,
          'file_attachment': fileId,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    try {
      await _strapi.put(
        '${StrapiConfig.chats}/$chatDocumentId',
        body: {'data': {}},
      );
    } catch (_) {}

    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка отправки файла');
    final msgRef = item['documentId'] as String? ?? item['id'].toString();

    Message? freshMsg;
    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.messages}/$msgRef',
        queryParams: _msgPopulate,
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) freshMsg = Message.fromJson(freshItem);
    } catch (_) {}
    return freshMsg ?? Message.fromJson(item);
  }
}
