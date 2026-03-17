import 'package:json_annotation/json_annotation.dart';
import '../config/strapi_config.dart';

part 'user.g.dart';

/// Модель пользователя для работы со Strapi
@JsonSerializable()
class User {
  final int id;
  @JsonKey(name: 'documentId')
  final String? documentId;
  final String? username;
  final String? email;
  @JsonKey(name: 'display_name')
  final String? displayName;
  final Map<String, dynamic>? avatar;
  final String? bio;
  @JsonKey(name: 'app_role', unknownEnumValue: UserRole.artist)
  final UserRole appRole;
  @JsonKey(name: 'is_onboarded')
  final bool isOnboarded;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  User({
    required this.id,
    this.documentId,
    this.username,
    this.email,
    this.displayName,
    this.avatar,
    this.bio,
    this.appRole = UserRole.artist,
    this.isOnboarded = false,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  /// URL аватара
  String? get avatarUrl {
    if (avatar == null) return null;
    final url = avatar!['url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }

  bool get isGuest => appRole == UserRole.guest;
  bool get isArtist => appRole == UserRole.artist;
  bool get isProducer => appRole == UserRole.producer;
  bool get isAdmin => appRole == UserRole.admin || appRole == UserRole.superAdmin;
  bool get isSuperAdmin => appRole == UserRole.superAdmin;
  bool get isRegistered => !isGuest;
  
  /// Создать копию с изменёнными полями
  User copyWith({
    int? id,
    String? documentId,
    String? username,
    String? email,
    String? displayName,
    Map<String, dynamic>? avatar,
    String? bio,
    UserRole? appRole,
    bool? isOnboarded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      appRole: appRole ?? this.appRole,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserRole {
  @JsonValue('guest')
  guest,
  @JsonValue('artist')
  artist,
  @JsonValue('producer')
  producer,
  @JsonValue('admin')
  admin,
  @JsonValue('super_admin')
  superAdmin,
}

