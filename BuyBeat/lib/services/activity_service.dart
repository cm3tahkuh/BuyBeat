import '../config/strapi_config.dart';
import '../models/user_activity.dart';
import 'auth_service.dart';
import 'strapi_service.dart';

class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  final _strapi = StrapiService.instance;

  Future<List<UserActivity>> getMyActivity() async {
    final user = await AuthService().getCurrentUser();
    if (user == null || user.isGuest) return [];

    try {
      final response = await _strapi.get('${StrapiConfig.apiUrl}/activities/my');
      final rows = StrapiService.parseList(response);
      final items = rows.map(_fromUnifiedRow).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      // Fallback to direct aggregation when custom backend route is not yet deployed
    }

    final favoritesFuture = _strapi.get(
      '${StrapiConfig.apiUrl}/favorites',
      queryParams: {
        'filters[beat][users_permissions_user][id][\$eq]': user.id.toString(),
        'populate[users_permissions_user][fields][0]': 'username',
        'populate[users_permissions_user][fields][1]': 'display_name',
        'populate[beat][fields][0]': 'title',
        'populate[beat][fields][1]': 'documentId',
        'sort': 'createdAt:desc',
        'pagination[pageSize]': '100',
      },
    );

    final purchasesFuture = _strapi.get(
      StrapiConfig.purchases,
      queryParams: {
        'status': 'published',
        'filters[purchase_status][\$eq]': 'completed',
        'filters[beat_file][beat][users_permissions_user][id][\$eq]': user.id.toString(),
        'populate[users_permissions_user][fields][0]': 'username',
        'populate[users_permissions_user][fields][1]': 'display_name',
        'populate[beat_file][populate][beat][fields][0]': 'title',
        'populate[beat_file][populate][beat][fields][1]': 'documentId',
        'sort': 'createdAt:desc',
        'pagination[pageSize]': '100',
      },
    );

    final results = await Future.wait([favoritesFuture, purchasesFuture]);

    final favoriteRows = StrapiService.parseList(results[0]);
    final purchaseRows = StrapiService.parseList(results[1]);

    final activities = <UserActivity>[];

    for (final row in favoriteRows) {
      final actor = row['users_permissions_user'] as Map<String, dynamic>?;
      final beat = row['beat'] as Map<String, dynamic>?;
      final createdAtRaw = row['createdAt'] as String?;
      final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now().toUtc();
      final actorName =
          (actor?['display_name'] as String?) ??
          (actor?['username'] as String?) ??
          'Пользователь';
      final beatTitle = (beat?['title'] as String?) ?? 'Ваш бит';
      final beatDocId = beat?['documentId'] as String?;

      activities.add(UserActivity(
        type: UserActivityType.favorite,
        actorName: actorName,
        actorUserId: (actor?['id'] as num?)?.toInt(),
        beatTitle: beatTitle,
        beatDocumentId: beatDocId,
        createdAt: createdAt,
      ));
    }

    for (final row in purchaseRows) {
      final actor = row['users_permissions_user'] as Map<String, dynamic>?;
      final beatFile = row['beat_file'] as Map<String, dynamic>?;
      final beat = beatFile?['beat'] as Map<String, dynamic>?;
      final createdAtRaw = row['createdAt'] as String?;
      final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now().toUtc();
      final actorName =
          (actor?['display_name'] as String?) ??
          (actor?['username'] as String?) ??
          'Пользователь';
      final beatTitle = (beat?['title'] as String?) ?? 'Ваш бит';
      final beatDocId = beat?['documentId'] as String?;

      activities.add(UserActivity(
        type: UserActivityType.purchase,
        actorName: actorName,
        actorUserId: (actor?['id'] as num?)?.toInt(),
        beatTitle: beatTitle,
        beatDocumentId: beatDocId,
        createdAt: createdAt,
      ));
    }

    activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return activities;
  }

  UserActivity _fromUnifiedRow(Map<String, dynamic> row) {
    final typeRaw = (row['type'] as String? ?? 'favorite').toLowerCase();
    final type = typeRaw == 'purchase'
      ? UserActivityType.purchase
      : (typeRaw == 'follow' ? UserActivityType.follow : UserActivityType.favorite);
    final createdAtRaw = row['createdAt'] as String?;
    final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now().toUtc();

    return UserActivity(
      type: type,
      actorName: (row['actorName'] as String?) ?? 'Пользователь',
      actorUserId: (row['actorUserId'] as num?)?.toInt(),
      beatTitle: (row['beatTitle'] as String?) ?? 'Ваш бит',
      beatDocumentId: row['beatDocumentId'] as String?,
      createdAt: createdAt,
    );
  }
}
