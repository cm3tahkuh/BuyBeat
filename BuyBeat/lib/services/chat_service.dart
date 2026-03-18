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

  /// Получить или создать чат между текущим пользователем и другим
  Future<Chat> getOrCreateChat(int otherUserId) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    // Ищем существующий чат с этим пользователем
    final response = await _strapi.get(
      StrapiConfig.chats,
      queryParams: {
        'populate': '*',
        'filters[users_permissions_users][id][\$eq]': user.id.toString(),
        'pagination[pageSize]': '100',
      },
    );

    final items = StrapiService.parseList(response);
    for (final json in items) {
      final chat = Chat.fromJson(json);
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

  /// Получить сообщения чата
  Future<List<Message>> getChatMessages(int chatId, {int page = 1, int pageSize = 50}) async {
    final response = await _strapi.get(
      StrapiConfig.messages,
      queryParams: {
        'populate': '*',
        'filters[chat][id][\$eq]': chatId.toString(),
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
    required int chatId,
    required String text,
  }) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final response = await _strapi.post(
      StrapiConfig.messages,
      body: {
        'data': {
          'chat': chatId,
          'users_permissions_user': user.id,
          'type': 'TEXT',
          'text': text,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    // Обновляем updatedAt чата (чтобы он поднялся вверх списка)
    try {
      await _strapi.put(
        '${StrapiConfig.chats}/$chatId',
        body: {'data': {}},
      );
    } catch (_) {}

    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка отправки сообщения');
    final msgId = item['id'];

    // Re-fetch with populate to get full sender object
    // Wrap in try/catch - silently fall back to POST response on any error
    Message? freshMsg;
    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.messages}/$msgId',
        queryParams: {'populate': '*'},
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) freshMsg = Message.fromJson(freshItem);
    } catch (_) {}
    return freshMsg ?? Message.fromJson(item);
  }

  /// Отправить файл
  Future<Message> sendFile({
    required int chatId,
    required String filePath,
    required String fileName,
  }) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    // Загружаем файл
    final uploadResponse = await _strapi.uploadFile(filePath: filePath, fileName: fileName);
    final fileId = uploadResponse[0]['id'];

    final response = await _strapi.post(
      StrapiConfig.messages,
      body: {
        'data': {
          'chat': chatId,
          'users_permissions_user': user.id,
          'type': 'FILE',
          'file_attachment': fileId,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    try {
      await _strapi.put(
        '${StrapiConfig.chats}/$chatId',
        body: {'data': {}},
      );
    } catch (_) {}

    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка отправки файла');
    final msgId = item['id'];

    Message? freshMsg;
    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.messages}/$msgId',
        queryParams: {'populate': '*'},
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) freshMsg = Message.fromJson(freshItem);
    } catch (_) {}
    return freshMsg ?? Message.fromJson(item);
  }

  /// Отправить файл из bytes (web)
  Future<Message> sendFileBytes({
    required int chatId,
    required List<int> bytes,
    required String fileName,
    String? text,
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
          'chat': chatId,
          'users_permissions_user': user.id,
          'type': 'FILE',
          if (text != null) 'text': text,
          'file_attachment': fileId,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );

    try {
      await _strapi.put(
        '${StrapiConfig.chats}/$chatId',
        body: {'data': {}},
      );
    } catch (_) {}

    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка отправки файла');
    final msgId = item['id'];

    Message? freshMsg;
    try {
      final freshResponse = await _strapi.get(
        '${StrapiConfig.messages}/$msgId',
        queryParams: {'populate': '*'},
      );
      final freshItem = StrapiService.parseItem(freshResponse);
      if (freshItem != null) freshMsg = Message.fromJson(freshItem);
    } catch (_) {}
    return freshMsg ?? Message.fromJson(item);
  }
}
