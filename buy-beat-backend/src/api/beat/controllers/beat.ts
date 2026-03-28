/**
 * beat controller
 */

import { factories } from '@strapi/strapi';

export default factories.createCoreController('api::beat.beat', ({ strapi }) => ({
  /**
   * POST /api/beats/:documentId/play
   * Increment play_count by 1 — public, no auth required.
   *
   * Uses raw DB query to update BOTH draft and published rows
   * (Strapi 5 draftAndPublish keeps two rows per document).
   */
  async incrementPlay(ctx: any) {
    const { documentId } = ctx.params as { documentId: string };

    try {
      const knex = strapi.db.connection;

      // Increment on ALL rows for this document_id (draft + published)
      const affected = await knex('beats')
        .where({ document_id: documentId })
        .update({
          play_count: knex.raw('COALESCE(play_count, 0) + 1'),
        });

      if (affected === 0) {
        return ctx.notFound('Beat not found');
      }

      // Read back the published row's count (what the REST API returns)
      const row = await knex('beats')
        .where({ document_id: documentId })
        .whereNotNull('published_at')
        .select('play_count')
        .first();

      const count = row?.play_count ?? 1;

      ctx.body = { play_count: count };
    } catch (err) {
      strapi.log.error('incrementPlay error: ' + String(err));
      ctx.internalServerError('Failed to increment play count');
    }
  },
}));
