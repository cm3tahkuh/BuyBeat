/**
 * Custom favorite controller
 * toggle — add/remove favorite in one call
 * my — get current user's favorites with populated beat
 */

export default {
  /**
   * POST /api/favorites/toggle
   * Body: { beatDocumentId: string }
   * Returns: { favorited: boolean }
   */
  async toggle(ctx: any) {
    const user = ctx.state.user;
    if (!user) return ctx.unauthorized('Необходима авторизация');

    const { beatDocumentId } = ctx.request.body;
    if (!beatDocumentId) return ctx.badRequest('beatDocumentId is required');

    // Use Strapi document service — relations are in link tables
    const favorites = await strapi.documents('api::favorite.favorite').findMany({
      filters: {
        users_permissions_user: { id: user.id },
        beat: { documentId: beatDocumentId },
      },
      fields: ['id'],
    });

    if (favorites && favorites.length > 0) {
      // Remove favorite
      for (const fav of favorites) {
        await strapi.documents('api::favorite.favorite').delete({
          documentId: fav.documentId,
        });
      }
      ctx.body = { favorited: false };
    } else {
      // Add favorite — pass documentId for relations
      await strapi.documents('api::favorite.favorite').create({
        data: {
          users_permissions_user: user.documentId,
          beat: beatDocumentId,
        } as any,
      });
      ctx.body = { favorited: true };
    }
  },

  /**
   * GET /api/favorites/my
   * Returns list of user's favorited beat documentIds
   */
  async my(ctx: any) {
    const user = ctx.state.user;
    if (!user) return ctx.unauthorized('Необходима авторизация');

    const favorites = await strapi.documents('api::favorite.favorite').findMany({
      filters: {
        users_permissions_user: { id: user.id },
      },
      populate: {
        beat: {
          fields: ['id', 'documentId'],
        },
      },
    });

    // Return array of beat documentIds
    const beatDocumentIds = (favorites || [])
      .filter((f: any) => f.beat?.documentId)
      .map((f: any) => f.beat.documentId);

    ctx.body = { data: beatDocumentIds };
  },
};
