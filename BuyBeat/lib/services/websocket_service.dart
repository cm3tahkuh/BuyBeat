import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/strapi_config.dart';
import '../models/message.dart';
import 'strapi_service.dart';

/// Событие нового сообщения, полученного через WebSocket
class WsNewMessageEvent {
  final int chatId;
  final String? chatDocumentId;
  final Message message;
  WsNewMessageEvent({required this.chatId, this.chatDocumentId, required this.message});
}

/// Сервис WebSocket-соединения с Strapi для real-time уведомлений о сообщениях.
///
/// Использует протокол:
/// 1. Клиент подключается и отправляет `{"type":"auth","token":"<jwt>"}`
/// 2. Сервер отвечает `{"type":"auth_ok","userId":...}`
/// 3. При новых сообщениях сервер шлёт `{"type":"new_message","chatId":...,"message":{...}}`
class WebSocketService {
  // ─── Singleton ───
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();
  WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  bool _isConnected = false;

  /// ID текущего авторизованного юзера (устанавливается после auth_ok)
  int? _authenticatedUserId;
  int? get authenticatedUserId => _authenticatedUserId;

  /// Стрим событий новых сообщений — слушайте его из UI
  final _messageController = StreamController<WsNewMessageEvent>.broadcast();
  Stream<WsNewMessageEvent> get onNewMessage => _messageController.stream;

  /// Стрим статуса подключения
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  bool get isConnected => _isConnected;

  // ─── Публичный API ───

  /// Подключиться к WebSocket серверу и авторизоваться
  void connect() {
    final token = StrapiService.instance.token;
    if (token == null) {
      debugPrint('WS: нет токена — подключение невозможно');
      return;
    }
    _intentionalClose = false;
    _doConnect(token);
  }

  /// Отключиться (при логауте)
  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setConnected(false);
    _authenticatedUserId = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }

  // ─── Внутренняя логика ───

  void _doConnect(String token) {
    try {
      _subscription?.cancel();
      _channel?.sink.close();

      final wsUrl = StrapiConfig.wsUrl;
      debugPrint('WS: connecting to $wsUrl …');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        (data) => _onData(data, token),
        onError: (error) {
          debugPrint('WS error: $error');
          _setConnected(false);
          _scheduleReconnect(token);
        },
        onDone: () {
          debugPrint('WS: connection closed');
          _setConnected(false);
          if (!_intentionalClose) _scheduleReconnect(token);
        },
        cancelOnError: false,
      );

      // Отправляем авторизацию сразу после подключения
      _send({'type': 'auth', 'token': token});
    } catch (e) {
      debugPrint('WS: connect error: $e');
      _setConnected(false);
      _scheduleReconnect(token);
    }
  }

  void _onData(dynamic raw, String token) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'auth_ok':
          _authenticatedUserId = data['userId'] as int?;
          _setConnected(true);
          debugPrint('WS: authenticated as user $_authenticatedUserId');
          break;

        case 'auth_error':
          debugPrint('WS: auth error — ${data['message']}');
          _setConnected(false);
          break;

        case 'new_message':
          _handleNewMessage(data);
          break;

        default:
          debugPrint('WS: unknown message type: $type');
      }
    } catch (e) {
      debugPrint('WS: parse error: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final chatId = data['chatId'] as int?;
      final chatDocumentId = data['chatDocumentId'] as String?;
      final msgJson = data['message'] as Map<String, dynamic>?;
      if (chatId == null || msgJson == null) return;

      final message = Message.fromJson(msgJson);
      _messageController.add(WsNewMessageEvent(
        chatId: chatId,
        chatDocumentId: chatDocumentId,
        message: message,
      ));
    } catch (e) {
      debugPrint('WS: error parsing new_message: $e');
    }
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('WS: send error: $e');
    }
  }

  void _setConnected(bool value) {
    if (_isConnected == value) return;
    _isConnected = value;
    _connectionController.add(value);
  }

  /// Переподключение с экспоненциальным backoff (3с, 6с, 12с, … max 30с)
  int _reconnectAttempt = 0;

  void _scheduleReconnect(String token) {
    _reconnectTimer?.cancel();
    if (_intentionalClose) return;

    final delay = Duration(
      seconds: (3 * (1 << _reconnectAttempt)).clamp(3, 30),
    );
    _reconnectAttempt++;
    debugPrint('WS: reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)…');

    _reconnectTimer = Timer(delay, () {
      _doConnect(token);
    });
  }
}
