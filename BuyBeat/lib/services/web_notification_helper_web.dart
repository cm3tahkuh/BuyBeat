/// Web notification implementation using the browser Notification API.
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> requestWebNotificationPermission() async {
  final permission = web.Notification.permission;
  if (permission != 'granted') {
    await web.Notification.requestPermission().toDart;
  }
}

Future<void> showWebNotification({
  required String title,
  required String body,
}) async {
  if (web.Notification.permission != 'granted') {
    final result = (await web.Notification.requestPermission().toDart);
    if (result.toDart != 'granted') return;
  }

  web.Notification(
    title,
    web.NotificationOptions(body: body),
  );
}
