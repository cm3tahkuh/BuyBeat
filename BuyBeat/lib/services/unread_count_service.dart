import 'package:flutter/foundation.dart';

/// Tracks unread message counts per chat for the current app session.
/// Counts are incremented by [InAppNotificationService] on every incoming
/// WS message and reset to 0 when the user opens the corresponding chat.
class UnreadCountService extends ChangeNotifier {
  static UnreadCountService? _instance;
  static UnreadCountService get instance =>
      _instance ??= UnreadCountService._();
  UnreadCountService._();

  /// key = chatDocumentId (or chatId.toString() as fallback)
  final Map<String, int> _counts = {};

  /// Total unread messages across all chats.
  int get totalUnread => _counts.values.fold(0, (a, b) => a + b);

  /// Unread count for a specific chat.
  int unreadFor(String key) => _counts[key] ?? 0;

  /// Called when a new message arrives for [key].
  void increment(String key) {
    _counts[key] = (_counts[key] ?? 0) + 1;
    notifyListeners();
  }

  /// Called when the user opens a chat — resets its counter.
  void markRead(String key) {
    if ((_counts[key] ?? 0) == 0) return;
    _counts[key] = 0;
    notifyListeners();
  }

  /// Reset everything (e.g. on logout).
  void reset() {
    _counts.clear();
    notifyListeners();
  }
}
