/**
 * Каскадное удаление: при удалении пользователя удаляем все его данные.
 * - beats (которые каскадно удалят beat_files, purchases, favorites)
 * - messages
 * - purchases (как покупатель)
 * - wallet + wallet_entries
 * - favorites
 * - chats (убираем пользователя из чатов; пустые чаты удаляем)
 */
export default {
  async beforeDelete(event: any) {
    const { where } = event.params;
    const id = where?.id;
    if (!id) return;

    const strapi = (global as any).strapi;

    // Находим пользователя со всеми связями
    const user = await strapi.db.query('plugin::users-permissions.user').findOne({
      where: { id },
      populate: ['beats', 'messages', 'purchases', 'wallet', 'chats'],
    });

    if (!user) return;

    // 1. Удаляем биты пользователя (каскадно удалятся beat_files, purchases файлов, favorites)
    if (user.beats?.length) {
      for (const beat of user.beats) {
        try {
          await strapi.documents('api::beat.beat').delete({ documentId: beat.documentId });
        } catch (e) {
          strapi.log.warn(`Cascade: failed to delete beat ${beat.documentId}: ${e}`);
        }
      }
    }

    // 2. Удаляем сообщения пользователя
    if (user.messages?.length) {
      for (const msg of user.messages) {
        try {
          await strapi.documents('api::message.message').delete({ documentId: msg.documentId });
        } catch (e) {
          strapi.log.warn(`Cascade: failed to delete message ${msg.documentId}: ${e}`);
        }
      }
    }

    // 3. Удаляем покупки (как покупатель)
    if (user.purchases?.length) {
      for (const purchase of user.purchases) {
        try {
          await strapi.documents('api::purchase.purchase').delete({ documentId: purchase.documentId });
        } catch (e) {
          strapi.log.warn(`Cascade: failed to delete purchase ${purchase.documentId}: ${e}`);
        }
      }
    }

    // 4. Удаляем кошелёк и его записи
    if (user.wallet) {
      // Сначала wallet_entries
      const walletEntries = await strapi.documents('api::wallet-entry.wallet-entry').findMany({
        filters: { wallet: { documentId: user.wallet.documentId } },
      });
      for (const entry of walletEntries) {
        try {
          await strapi.documents('api::wallet-entry.wallet-entry').delete({ documentId: entry.documentId });
        } catch (e) {
          strapi.log.warn(`Cascade: failed to delete wallet-entry ${entry.documentId}: ${e}`);
        }
      }
      // Затем сам wallet
      try {
        await strapi.documents('api::wallet.wallet').delete({ documentId: user.wallet.documentId });
      } catch (e) {
        strapi.log.warn(`Cascade: failed to delete wallet ${user.wallet.documentId}: ${e}`);
      }
    }

    // 5. Удаляем favorites пользователя
    const favorites = await strapi.db.query('api::favorite.favorite').findMany({
      where: { users_permissions_user: { id: user.id } },
    });
    for (const fav of favorites) {
      try {
        await strapi.documents('api::favorite.favorite').delete({ documentId: fav.documentId });
      } catch (e) {
        strapi.log.warn(`Cascade: failed to delete favorite ${fav.documentId}: ${e}`);
      }
    }

    // 6. Обрабатываем чаты — убираем пользователя
    if (user.chats?.length) {
      for (const chat of user.chats) {
        try {
          // Получаем чат с участниками
          const fullChat = await strapi.documents('api::chat.chat').findOne({
            documentId: chat.documentId,
            populate: ['users_permissions_users', 'messages'],
          });
          if (!fullChat) continue;

          const remainingUsers = (fullChat.users_permissions_users || [])
            .filter((u: any) => u.id !== user.id);

          if (remainingUsers.length === 0) {
            // Удаляем все сообщения чата
            if (fullChat.messages?.length) {
              for (const msg of fullChat.messages) {
                try {
                  await strapi.documents('api::message.message').delete({ documentId: msg.documentId });
                } catch (_) {}
              }
            }
            // Удаляем пустой чат
            await strapi.documents('api::chat.chat').delete({ documentId: chat.documentId });
          } else {
            // Убираем пользователя из чата
            await strapi.documents('api::chat.chat').update({
              documentId: chat.documentId,
              data: {
                users_permissions_users: remainingUsers.map((u: any) => u.id),
              },
            });
          }
        } catch (e) {
          strapi.log.warn(`Cascade: failed to process chat ${chat.documentId}: ${e}`);
        }
      }
    }
  },
};
