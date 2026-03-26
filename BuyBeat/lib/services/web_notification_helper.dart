/// Conditional export: web_notification_helper_stub.dart is used on non-web,
/// web_notification_helper_web.dart is used on web.
export 'web_notification_helper_stub.dart'
    if (dart.library.js_interop) 'web_notification_helper_web.dart';
