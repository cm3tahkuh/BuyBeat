enum UserActivityType { favorite, purchase, follow }

class UserActivity {
  final UserActivityType type;
  final String actorName;
  final int? actorUserId;
  final String beatTitle;
  final String? beatDocumentId;
  final DateTime createdAt;

  const UserActivity({
    required this.type,
    required this.actorName,
    this.actorUserId,
    required this.beatTitle,
    required this.createdAt,
    this.beatDocumentId,
  });
}
