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
  /**
   * GET /api/activities/my
   * Unified activity stream for producer/admin profile:
   * - favorites on my beats
   * - completed purchases of my beats
   */
  async my(ctx: any) {
    const user = await getAuthUserFromBearer(ctx);
    if (!user) return ctx.unauthorized('Необходима авторизация');

    const favorites = await strapi.documents('api::favorite.favorite').findMany({
      filters: {
        beat: { users_permissions_user: { id: user.id } },
      },
      populate: {
        users_permissions_user: { fields: ['id', 'username', 'display_name'] },
        beat: { fields: ['title', 'documentId'] },
      },
      sort: ['createdAt:desc'],
      pagination: { page: 1, pageSize: 200 },
    });

    const purchases = await strapi.documents('api::purchase.purchase').findMany({
      status: 'published',
      filters: {
        purchase_status: { $eq: 'completed' },
        beat_file: { beat: { users_permissions_user: { id: user.id } } },
      },
      populate: {
        users_permissions_user: { fields: ['id', 'username', 'display_name'] },
        beat_file: {
          populate: {
            beat: { fields: ['title', 'documentId'] },
          },
        },
      },
      sort: ['createdAt:desc'],
      pagination: { page: 1, pageSize: 200 },
    });

    const follows = await strapi.documents('api::follow.follow').findMany({
      filters: {
        following: { id: user.id },
      },
      populate: {
        follower: { fields: ['id', 'username', 'display_name'] },
      },
      sort: ['createdAt:desc'],
      pagination: { page: 1, pageSize: 200 },
    });

    const favoriteItems = (favorites || []).map((row: any) => ({
      type: 'favorite',
      actorName:
        row?.users_permissions_user?.display_name ||
        row?.users_permissions_user?.username ||
        'Пользователь',
      actorUserId: row?.users_permissions_user?.id || null,
      beatTitle: row?.beat?.title || 'Ваш бит',
      beatDocumentId: row?.beat?.documentId || null,
      createdAt: row?.createdAt || new Date().toISOString(),
    }));

    const purchaseItems = (purchases || []).map((row: any) => ({
      type: 'purchase',
      actorName:
        row?.users_permissions_user?.display_name ||
        row?.users_permissions_user?.username ||
        'Пользователь',
      actorUserId: row?.users_permissions_user?.id || null,
      beatTitle: row?.beat_file?.beat?.title || 'Ваш бит',
      beatDocumentId: row?.beat_file?.beat?.documentId || null,
      createdAt: row?.createdAt || new Date().toISOString(),
    }));

    const followItems = (follows || []).map((row: any) => ({
      type: 'follow',
      actorName:
        row?.follower?.display_name ||
        row?.follower?.username ||
        'Пользователь',
      actorUserId: row?.follower?.id || null,
      beatTitle: '',
      beatDocumentId: null,
      createdAt: row?.createdAt || new Date().toISOString(),
    }));

    const items = [...favoriteItems, ...purchaseItems, ...followItems].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );

    ctx.body = { data: items };
  },
};
