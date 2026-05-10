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
  async toggle(ctx: any) {
    const user = await getAuthUserFromBearer(ctx);
    if (!user) return ctx.unauthorized('Необходима авторизация');

    const targetUserId = Number(ctx.request.body?.targetUserId);
    if (!targetUserId) return ctx.badRequest('targetUserId is required');
    if (targetUserId === user.id) return ctx.badRequest('Нельзя подписаться на себя');

    const targetUser = await strapi.db.query('plugin::users-permissions.user').findOne({
      where: { id: targetUserId },
      select: ['id', 'documentId'],
    });
    if (!targetUser) return ctx.notFound('Пользователь не найден');

    const existing = await strapi.documents('api::follow.follow').findMany({
      filters: {
        follower: { id: user.id },
        following: { id: targetUserId },
      },
      pagination: { page: 1, pageSize: 5 },
    });

    let isFollowing = false;

    if (existing && existing.length > 0) {
      for (const row of existing) {
        await strapi.documents('api::follow.follow').delete({ documentId: row.documentId });
      }
      isFollowing = false;
    } else {
      await strapi.documents('api::follow.follow').create({
        data: {
          follower: user.documentId,
          following: targetUser.documentId,
        } as any,
      });
      isFollowing = true;
    }

    const followers = await strapi.documents('api::follow.follow').findMany({
      filters: { following: { id: targetUserId } },
      pagination: { page: 1, pageSize: 1000 },
    });

    ctx.body = {
      isFollowing,
      followersCount: followers.length,
    };
  },

  async myFollowing(ctx: any) {
    const user = await getAuthUserFromBearer(ctx);
    if (!user) return ctx.unauthorized('Необходима авторизация');

    const rows = await strapi.documents('api::follow.follow').findMany({
      filters: {
        follower: { id: user.id },
      },
      populate: {
        following: {
          fields: ['id', 'username', 'display_name'],
          populate: {
            avatar: { fields: ['url'] },
          },
        },
      },
      sort: ['createdAt:desc'],
      pagination: { page: 1, pageSize: 300 },
    });

    const items = (rows || [])
      .map((row: any) => {
        const target = row?.following;
        if (!target?.id) return null;
        return {
          userId: target.id,
          username: target.username ?? null,
          displayName: target.display_name ?? null,
          avatarUrl: target.avatar?.url ?? null,
        };
      })
      .filter(Boolean);

    ctx.body = { data: items };
  },
};
