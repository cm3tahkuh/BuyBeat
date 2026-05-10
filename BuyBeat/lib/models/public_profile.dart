import '../config/strapi_config.dart';

class PublicProfile {
  final int userId;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? role;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final int beatsCount;
  final int likesCount;
  final bool isFollowing;

  const PublicProfile({
    required this.userId,
    this.username,
    this.displayName,
    this.bio,
    this.role,
    this.avatarUrl,
    required this.followersCount,
    required this.followingCount,
    required this.beatsCount,
    required this.likesCount,
    required this.isFollowing,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      bio: json['bio'] as String?,
      role: json['role'] as String?,
      avatarUrl: StrapiConfig.getMediaUrl(json['avatarUrl'] as String?),
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      beatsCount: (json['beatsCount'] as num?)?.toInt() ?? 0,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }

  PublicProfile copyWith({
    bool? isFollowing,
    int? followersCount,
  }) {
    return PublicProfile(
      userId: userId,
      username: username,
      displayName: displayName,
      bio: bio,
      role: role,
      avatarUrl: avatarUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      beatsCount: beatsCount,
      likesCount: likesCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
