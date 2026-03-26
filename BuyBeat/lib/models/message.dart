import 'package:json_annotation/json_annotation.dart';
import '../config/strapi_config.dart';

part 'message.g.dart';

/// Модель сообщения для работы со Strapi
@JsonSerializable()
class Message {
  final int id;
  final String? documentId;
  @JsonKey(name: 'type')
  final MessageType messageType;
  final String? text;
  @JsonKey(name: 'file_attachment')
  final Map<String, dynamic>? fileAttachment;
  
  // Relations
  final Map<String, dynamic>? chat;
  @JsonKey(name: 'users_permissions_user')
  final Map<String, dynamic>? sender;

  /// Сообщение, на которое отвечаем (reply-to)
  @JsonKey(name: 'reply_to')
  final Map<String, dynamic>? replyTo;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Message({
    required this.id,
    this.documentId,
    this.messageType = MessageType.text,
    this.text,
    this.fileAttachment,
    this.chat,
    this.sender,
    this.replyTo,
    this.createdAt,
    this.updatedAt,
  });

  bool get isFile => messageType == MessageType.file;
  bool get isText => messageType == MessageType.text;
  
  /// URL файла вложения
  String? get fileUrl {
    if (fileAttachment == null) return null;
    final url = fileAttachment!['url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }
  
  String? get fileName => fileAttachment?['name'] as String?;
  int? get fileSize => fileAttachment?['size'] as int?;
  String? get fileMime => fileAttachment?['mime'] as String?;

  /// Тип вложения по MIME
  bool get isImage {
    final m = fileMime ?? '';
    final n = (fileName ?? '').toLowerCase();
    return m.startsWith('image/') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.gif') || n.endsWith('.webp');
  }
  bool get isAudio {
    final m = fileMime ?? '';
    final n = (fileName ?? '').toLowerCase();
    return m.startsWith('audio/') || n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.ogg') || n.endsWith('.flac') || n.endsWith('.aac');
  }
  bool get isVideo {
    final m = fileMime ?? '';
    final n = (fileName ?? '').toLowerCase();
    return m.startsWith('video/') || n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.avi') || n.endsWith('.webm') || n.endsWith('.mkv');
  }
  bool get isDocument => isFile && !isImage && !isAudio && !isVideo;

  /// Читабельный размер файла
  String get fileSizeFormatted {
    final s = fileAttachment?['size'];
    if (s == null) return '';
    final bytes = (s is num) ? s.toDouble() : 0.0;
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  /// ID чата
  int? get chatId => chat?['id'] as int?;
  
  /// ID отправителя
  int? get senderId => sender?['id'] as int?;
  
  /// Имя отправителя
  String? get senderName {
    if (sender == null) return null;
    return sender!['display_name'] as String? ?? sender!['username'] as String?;
  }

  /// URL аватара отправителя
  String? get senderAvatarUrl {
    if (sender == null) return null;
    final avatar = sender!['avatar'];
    if (avatar is Map<String, dynamic>) {
      final url = avatar['url'] as String?;
      return StrapiConfig.getMediaUrl(url);
    }
    // Некоторые профили хранят avatar_url напрямую
    final url = sender!['avatar_url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }

  // ─── Reply-to helpers ───

  /// Есть ли ответ на сообщение
  bool get hasReply => replyTo != null && replyTo!.containsKey('id');

  /// ID сообщения, на которое отвечаем
  int? get replyToId => replyTo?['id'] as int?;

  /// documentId сообщения, на которое отвечаем
  String? get replyToDocumentId => replyTo?['documentId'] as String?;

  /// Текст сообщения, на которое отвечаем
  String? get replyToText => replyTo?['text'] as String?;

  /// Тип сообщения-оригинала
  bool get replyToIsFile {
    final t = replyTo?['type'] as String?;
    return t == 'FILE';
  }

  /// Имя отправителя оригинального сообщения
  String? get replyToSenderName {
    final s = replyTo?['users_permissions_user'];
    if (s is Map<String, dynamic>) {
      return s['display_name'] as String? ?? s['username'] as String?;
    }
    return null;
  }

  /// ID отправителя оригинального сообщения
  int? get replyToSenderId {
    final s = replyTo?['users_permissions_user'];
    if (s is Map<String, dynamic>) return s['id'] as int?;
    if (s is int) return s;
    return null;
  }

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

enum MessageType {
  @JsonValue('TEXT')
  text,
  @JsonValue('FILE')
  file,
}
