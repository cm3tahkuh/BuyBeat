import '../config/strapi_config.dart';
import '../models/public_profile.dart';
import 'strapi_service.dart';

class FollowingUser {
  final int userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  const FollowingUser({
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory FollowingUser.fromJson(Map<String, dynamic> json) {
    return FollowingUser(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: StrapiConfig.getMediaUrl(json['avatarUrl'] as String?),
    );
  }
}

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  final _strapi = StrapiService.instance;

  Future<PublicProfile> getPublicProfile(int userId) async {
    final response = await _strapi.get('${StrapiConfig.apiUrl}/profiles/$userId');
    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Профиль не найден');
    return PublicProfile.fromJson(item);
  }

  Future<Map<String, dynamic>> toggleFollow(int targetUserId) async {
    final response = await _strapi.post(
      '${StrapiConfig.apiUrl}/follows/toggle',
      body: {'targetUserId': targetUserId},
    );

    return {
      'isFollowing': response['isFollowing'] as bool? ?? false,
      'followersCount': (response['followersCount'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<FollowingUser>> getMyFollowing() async {
    final response = await _strapi.get('${StrapiConfig.apiUrl}/follows/my-following');
    final rows = StrapiService.parseList(response);
    return rows.map(FollowingUser.fromJson).where((u) => u.userId > 0).toList();
  }
}
