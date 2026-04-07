/**
 * Каскадное удаление: при удалении beat-file удаляем все связанные purchases.
 */
export default {
  async beforeDelete(event: any) {
    const { where } = event.params;
    const documentId = where?.documentId || where?.id;
    if (!documentId) return;

    const strapi = (global as any).strapi;

    const purchases = await strapi.documents('api::purchase.purchase').findMany({
      filters: { beat_file: { documentId } },
    });

    for (const p of purchases) {
      await strapi.documents('api::purchase.purchase').delete({ documentId: p.documentId });
    }
  },
};
