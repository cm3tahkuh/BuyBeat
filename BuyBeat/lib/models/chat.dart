import 'package:json_annotation/json_annotation.dart';

part 'chat.g.dart';

/// Модель чата (Strapi v5: flat JSON, без attributes)
@JsonSerializable()
class Chat {
  final int id;
  final String? documentId;

  /// Участники чата (Strapi: users_permissions_users)
  @JsonKey(name: 'users_permissions_users')
  final List<dynamic>? participants;

  /// Сообщения (populated если запрошено)
  final List<dynamic>? messages;

  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Chat({
    required this.id,
    this.documentId,
    this.participants,
    this.messages,
    this.createdAt,
    this.updatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
  Map<String, dynamic> toJson() => _$ChatToJson(this);

  /// Получить имя собеседника (исключая текущего пользователя)
  String otherParticipantName(int currentUserId) {
    if (participants == null || participants!.isEmpty) return 'Unknown';
    for (final p in participants!) {
      if (p is Map<String, dynamic> && p['id'] != currentUserId) {
        return p['display_name'] as String? ?? p['username'] as String? ?? 'Unknown';
      }
    }
    // Если все участники — это мы сами
    final first = participants!.first;
    if (first is Map<String, dynamic>) {
      return first['display_name'] as String? ?? first['username'] as String? ?? 'Unknown';
    }
    return 'Unknown';
  }

  /// URL аватара собеседника
  String? otherParticipantAvatarUrl(int currentUserId) {
    if (participants == null || participants!.isEmpty) return null;
    for (final p in participants!) {
      if (p is Map<String, dynamic> && p['id'] != currentUserId) {
        final avatar = p['avatar'];
        if (avatar is Map<String, dynamic>) {
          final url = avatar['url'] as String?;
          return url;
        }
      }
    }
    return null;
  }

  /// ID собеседника
  int? otherParticipantId(int currentUserId) {
    if (participants == null) return null;
    for (final p in participants!) {
      if (p is Map<String, dynamic> && p['id'] != currentUserId) {
        return p['id'] as int?;
      }
    }
    return null;
  }

  /// Последнее сообщение (текст)
  String? get lastMessageText {
    if (messages == null || messages!.isEmpty) return null;
    // Сообщения отсортированы по createdAt desc — первое = последнее
    final last = messages!.last;
    if (last is Map<String, dynamic>) {
      return last['text'] as String?;
    }
    return null;
  }

  /// Время последнего сообщения
  DateTime? get lastMessageTime {
    if (messages == null || messages!.isEmpty) return null;
    final last = messages!.last;
    if (last is Map<String, dynamic> && last['createdAt'] != null) {
      return DateTime.tryParse(last['createdAt'] as String);
    }
    return null;
  }
}
