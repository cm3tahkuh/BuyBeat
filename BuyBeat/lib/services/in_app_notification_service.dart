import 'dart:async';
import 'package:flutter/material.dart';
import 'websocket_service.dart';
import 'native_notification_service.dart';

/// Сервис уведомлений о новых сообщениях.
/// Показывает нативные уведомления (Android shade / iOS / Web).
class InAppNotificationService {
  static InAppNotificationService? _instance;
  static InAppNotificationService get instance =>
      _instance ??= InAppNotificationService._();
  InAppNotificationService._();

  /// navigatorKey для MaterialApp
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription? _sub;

  /// documentId чата, который сейчас открыт (чтобы не показывать уведомление для него)
  String? _activeChatDocumentId;
  set activeChatDocumentId(String? id) => _activeChatDocumentId = id;

  /// Числовой ID для обратной совместимости
  int? _activeChatId;
  set activeChatId(int? id) => _activeChatId = id;

  /// Коллбэк при нажатии на уведомление — переход в чат
  void Function(int chatId, String senderName)? onTap;

  /// Начать слушать WebSocket-события и показывать баннеры
  void start() {
    _sub?.cancel();
    _sub = WebSocketService.instance.onNewMessage.listen(_onMessage);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onMessage(WsNewMessageEvent event) {
    // Не показываем уведомление для открытого чата
    if (_activeChatDocumentId != null && event.chatDocumentId == _activeChatDocumentId) return;
    if (_activeChatId != null && event.chatId == _activeChatId) return;

    // Не показываем свои собственные сообщения
    final myId = WebSocketService.instance.authenticatedUserId;
    if (event.message.senderId == myId) return;

    final senderName = event.message.senderName ?? 'Новое сообщение';
    final text = event.message.isFile
        ? '📎 Файл'
        : (event.message.text ?? '');

    // Показываем только нативное уведомление (Android shade / iOS Notification Center)
    NativeNotificationService.instance.show(
      title: senderName,
      body: text,
      payload: event.chatId.toString(),
      chatId: event.chatId,
    );
  }
}
