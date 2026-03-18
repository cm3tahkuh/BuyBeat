import 'package:json_annotation/json_annotation.dart';
import '../config/strapi_config.dart';

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
          return url != null ? StrapiConfig.getMediaUrl(url) : null;
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
    // Берём последнее по ID (максимальный id = самое новое)
    Map<String, dynamic>? newest;
    int maxId = -1;
    for (final m in messages!) {
      if (m is Map<String, dynamic>) {
        final id = m['id'] as int? ?? 0;
        if (id > maxId) { maxId = id; newest = m; }
      }
    }
    if (newest == null) return null;
    final type = newest['type'] as String?;
    final text = newest['text'] as String?;
    // FILE messages → показываем тип вложения
    if (type == 'FILE' || text == '__doc__') {
      final att = newest['file_attachment'];
      if (att is Map<String, dynamic>) {
        final mime = (att['mime'] as String?) ?? '';
        final name = (att['name'] as String?) ?? '';
        if (mime.startsWith('image/') || _isImageExt(name)) return '📷 Фото';
        if (mime.startsWith('audio/') || _isAudioExt(name)) return '🎵 Аудио';
        if (mime.startsWith('video/') || _isVideoExt(name)) return '🎬 Видео';
      }
      return '📎 Документ';
    }
    return text;
  }

  static bool _isImageExt(String n) {
    final l = n.toLowerCase();
    return l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.gif') || l.endsWith('.webp');
  }
  static bool _isAudioExt(String n) {
    final l = n.toLowerCase();
    return l.endsWith('.mp3') || l.endsWith('.wav') || l.endsWith('.ogg') || l.endsWith('.flac') || l.endsWith('.aac');
  }
  static bool _isVideoExt(String n) {
    final l = n.toLowerCase();
    return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.avi') || l.endsWith('.webm') || l.endsWith('.mkv');
  }

  /// Время последнего сообщения
  DateTime? get lastMessageTime {
    if (messages == null || messages!.isEmpty) return null;
    Map<String, dynamic>? newest;
    int maxId = -1;
    for (final m in messages!) {
      if (m is Map<String, dynamic>) {
        final id = m['id'] as int? ?? 0;
        if (id > maxId) { maxId = id; newest = m; }
      }
    }
    if (newest != null && newest['createdAt'] != null) {
      return DateTime.tryParse(newest['createdAt'] as String);
    }
    return null;
  }
}
