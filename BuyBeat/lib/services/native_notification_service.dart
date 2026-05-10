import 'dart:io' show Platform;
import 'dart:typed_data';
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

  /// Payload, полученный до того как onTap был установлен (cold start)
  String? _pendingPayload;

  /// Коллбэк при нажатии на уведомление — payload = chatId
  void Function(String payload)? _onTapCallback;
  set onTap(void Function(String payload)? callback) {
    _onTapCallback = callback;
    // Если есть отложенный payload (cold start) — доставляем
    if (callback != null && _pendingPayload != null) {
      final p = _pendingPayload!;
      _pendingPayload = null;
      print('🔔 NativeNotif: delivering pending payload=$p');
      callback(p);
    }
  }

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

    // Cold start: приложение запустилось по тапу на уведомление
    if (!kIsWeb) {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse != null) {
        print('🔔 NativeNotif: launched from notification');
        _onNotificationResponse(launchDetails.notificationResponse!);
      }
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    print('🔔 NativeNotif: _onNotificationResponse payload=$payload, onTap=${_onTapCallback != null}');
    if (payload != null && payload.isNotEmpty) {
      if (_onTapCallback != null) {
        _onTapCallback!(payload);
      } else {
        // onTap ещё не установлен (cold start) — сохраняем
        _pendingPayload = payload;
        print('🔔 NativeNotif: stored pending payload=$payload');
      }
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

    final vibrationPattern = Int64List.fromList([0, 400, 200, 400]);
    final androidDetails = AndroidNotificationDetails(
      'chat_messages', // channel id
      'Сообщения чата', // channel name
      channelDescription: 'Уведомления о новых сообщениях в чатах',
      // max importance — heads-up banner even on Realme/ColorOS
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      channelShowBadge: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      enableLights: true,
      // категория "сообщение" — Realme/MIUI уважают её при фильтрации
      category: AndroidNotificationCategory.message,
      // ticker — fallback текст для accessibility и некоторых кастомных ROM
      ticker: 'Новое сообщение',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
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
