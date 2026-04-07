/**
 * Каскадное удаление: при удалении кошелька удаляем все wallet_entries.
 */
export default {
  async beforeDelete(event: any) {
    const { where } = event.params;
    const documentId = where?.documentId || where?.id;
    if (!documentId) return;

    const strapi = (global as any).strapi;

    const entries = await strapi.documents('api::wallet-entry.wallet-entry').findMany({
      filters: { wallet: { documentId } },
    });

    for (const entry of entries) {
      await strapi.documents('api::wallet-entry.wallet-entry').delete({ documentId: entry.documentId });
    }
  },
};
