/**
 * Каскадное удаление: при удалении чата удаляем все его сообщения.
 */
export default {
  async beforeDelete(event: any) {
    const { where } = event.params;
    const documentId = where?.documentId || where?.id;
    if (!documentId) return;

    const strapi = (global as any).strapi;

    const messages = await strapi.documents('api::message.message').findMany({
      filters: { chat: { documentId } },
    });

    for (const msg of messages) {
      await strapi.documents('api::message.message').delete({ documentId: msg.documentId });
    }
  },
};
