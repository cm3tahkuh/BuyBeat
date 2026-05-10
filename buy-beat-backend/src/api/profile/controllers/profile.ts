async function getAuthUserFromBearer(ctx: any) {
  const header =
    ctx.request?.header?.authorization ||
    ctx.request?.headers?.authorization;
  if (!header || !header.startsWith('Bearer ')) return null;

  const token = header.slice(7).trim();
  if (!token) return null;

  try {
    const jwtService = strapi.service('plugin::users-permissions.jwt');
    const payload = await (jwtService as any).verify(token);
    const userId = payload?.id;
    if (!userId) return null;

    const user = await strapi.db.query('plugin::users-permissions.user').findOne({
      where: { id: userId },
      select: ['id', 'documentId', 'username', 'display_name'],
    });
    return user ?? null;
  } catch {
    return null;
  }
}

export default {
  async publicById(ctx: any) {
    const viewer = await getAuthUserFromBearer(ctx);

    const targetUserId = Number(ctx.params?.id);
    if (!targetUserId) return ctx.badRequest('Invalid user id');

    const targetUser = await strapi.db.query('plugin::users-permissions.user').findOne({
      where: { id: targetUserId },
      select: ['id', 'documentId', 'username', 'display_name', 'bio', 'app_role'],
      populate: {
        avatar: {
          select: ['url'],
        },
      },
    });

    if (!targetUser) return ctx.notFound('Пользователь не найден');

    const beats = await strapi.documents('api::beat.beat').findMany({
      status: 'published',
      filters: { users_permissions_user: { id: targetUserId } },
      fields: ['id'],
      pagination: { page: 1, pageSize: 1000 },
    });

    const favoritesOnBeats = await strapi.documents('api::favorite.favorite').findMany({
      filters: { beat: { users_permissions_user: { id: targetUserId } } },
      fields: ['id'],
      pagination: { page: 1, pageSize: 1000 },
    });

    const followers = await strapi.documents('api::follow.follow').findMany({
      filters: { following: { id: targetUserId } },
      fields: ['id'],
      pagination: { page: 1, pageSize: 1000 },
    });

    const following = await strapi.documents('api::follow.follow').findMany({
      filters: { follower: { id: targetUserId } },
      fields: ['id'],
      pagination: { page: 1, pageSize: 1000 },
    });

    let isFollowing = false;
    if (viewer && viewer.id !== targetUserId) {
      const row = await strapi.documents('api::follow.follow').findMany({
        filters: {
          follower: { id: viewer.id },
          following: { id: targetUserId },
        },
        fields: ['id'],
        pagination: { page: 1, pageSize: 1 },
      });
      isFollowing = row.length > 0;
    }

    ctx.body = {
      data: {
        userId: targetUser.id,
        username: targetUser.username,
        displayName: targetUser.display_name,
        bio: targetUser.bio,
        role: targetUser.app_role,
        avatarUrl: targetUser.avatar?.url || null,
        followersCount: followers.length,
        followingCount: following.length,
        beatsCount: beats.length,
        likesCount: favoritesOnBeats.length,
        isFollowing,
      },
    };
  },
};
