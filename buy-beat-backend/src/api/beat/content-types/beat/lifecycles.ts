/**
 * Каскадное удаление: при удалении бита удаляем все связанные записи.
 * - beat_files (и связанные purchases каждого beat_file)
 * - favorites
 */
export default {
  async beforeDelete(event: any) {
    const { where } = event.params;
    const documentId = where?.documentId || where?.id;
    if (!documentId) return;

    const strapi = (global as any).strapi;

    // Находим beat чтобы получить его beat_files
    const beat = await strapi.documents('api::beat.beat').findOne({
      documentId,
      populate: ['beat_files'],
    });

    if (beat) {
      // Удаляем purchases каждого beat_file
      if (beat.beat_files?.length) {
        for (const bf of beat.beat_files) {
          const purchases = await strapi.documents('api::purchase.purchase').findMany({
            filters: { beat_file: { documentId: bf.documentId } },
          });
          for (const p of purchases) {
            await strapi.documents('api::purchase.purchase').delete({ documentId: p.documentId });
          }
          // Удаляем сам beat_file
          await strapi.documents('api::beat-file.beat-file').delete({ documentId: bf.documentId });
        }
      }

      // Удаляем favorites, связанные с этим битом
      const favorites = await strapi.documents('api::favorite.favorite').findMany({
        filters: { beat: { documentId } },
      });
      for (const fav of favorites) {
        await strapi.documents('api::favorite.favorite').delete({ documentId: fav.documentId });
      }
    }
  },
};
