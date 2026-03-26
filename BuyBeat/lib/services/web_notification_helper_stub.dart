/// Web notification stub — used on non-web platforms.
/// Actual implementation is in web_notification_helper_web.dart.

Future<void> requestWebNotificationPermission() async {}

Future<void> showWebNotification({
  required String title,
  required String body,
}) async {}
