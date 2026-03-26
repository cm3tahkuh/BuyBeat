import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'web_notification_helper.dart' as web_notify;

/// Нативные уведомления (Android notification shade, iOS Notification Center).
/// На Web используется browser Notification API через flutter_local_notifications (Linux/Windows).
/// Для web-платформы уведомления обрабатываются отдельно через JS interop.
class NativeNotificationService {
  static NativeNotificationService? _instance;
  static NativeNotificationService get instance =>
      _instance ??= NativeNotificationService._();
  NativeNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _notificationId = 0;

  /// Коллбэк при нажатии на уведомление — payload = chatId
  void Function(String payload)? onTap;

  /// Инициализация плагина. Вызывать до runApp() или в main().
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      // На вебе используем browser Notification API
      await web_notify.requestWebNotificationPermission();
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher', // стандартная иконка приложения
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Запрашиваем разрешение на Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // Запрашиваем разрешение на iOS
    if (!kIsWeb && Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onTap?.call(payload);
    }
  }

  /// Показать нативное уведомление.
  /// [chatId] — если указан, используется как ID уведомления для группировки
  /// (новое сообщение в том же чате заменяет предыдущее уведомление).
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? chatId,
  }) async {
    if (!_initialized) return;

    // Web — browser Notification API
    if (kIsWeb) {
      await web_notify.showWebNotification(title: title, body: body);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'chat_messages', // channel id
      'Сообщения чата', // channel name
      channelDescription: 'Уведомления о новых сообщениях в чатах',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // звук по умолчанию
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Если указан chatId — используем его как id уведомления,
    // чтобы новое сообщение в том же чате заменяло старое (без дублей)
    final notifId = chatId ?? _notificationId++;

    await _plugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
