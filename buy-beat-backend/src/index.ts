import type { Core } from '@strapi/strapi';
import cluster from 'cluster';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { WebSocketServer } = require('ws');

const WS_OPEN = 1; // WebSocket.OPEN
const IPC_TYPE = 'ws_broadcast';

// ─── WebSocket-менеджер (живёт только в primary процессе) ───
class WsManager {
  private static _instance: WsManager;
  private wss: any = null;
  private clients = new Map<number, Set<any>>();

  static get instance(): WsManager {
    if (!WsManager._instance) WsManager._instance = new WsManager();
    return WsManager._instance;
  }

  /** Возвращает true, если этот процесс успешно занял порт 1338 */
  hasServer(): boolean {
    return this.wss !== null;
  }

  /**
   * Запуск WS-сервера. Каждый процесс пытается занять порт;
   * проигравшие получают EADDRINUSE и тихо устанавливают this.wss = null.
   */
  start(strapi: Core.Strapi) {
    const port = parseInt(process.env.WS_PORT || '1338', 10);

    this.wss = new WebSocketServer({ port });

    // Если порт уже занят (другой воркер) — тихо игнорируем
    this.wss.on('error', (err: any) => {
      if (err.code === 'EADDRINUSE') {
        strapi.log.debug(`WS: port ${port} already in use (another worker), skipping`);
        this.wss = null;
      } else {
        strapi.log.error('WS server error: ' + String(err));
      }
    });

    this.wss.on('listening', () => {
      strapi.log.info(`🔌 WebSocket server listening on port ${port}`);
    });

    this.wss.on('connection', (ws: any) => {
      ws._userId = undefined as number | undefined;
      ws._isAlive = true;

      ws.on('pong', () => { ws._isAlive = true; });

      ws.on('message', async (raw: any) => {
        try {
          const msg = JSON.parse(raw.toString());
          if (msg.type === 'auth' && msg.token) {
            await this.handleAuth(ws, msg.token, strapi);
          }
        } catch { /* ignore bad frames */ }
      });

      ws.on('close', () => this.removeClient(ws));
      ws.on('error', () => this.removeClient(ws));

      setTimeout(() => {
        if (!ws._userId) ws.close();
      }, 10_000);
    });

    // Heartbeat каждые 30с
    setInterval(() => {
      if (!this.wss) return;
      this.wss.clients.forEach((ws: any) => {
        if (!ws._isAlive) { this.removeClient(ws); return ws.terminate(); }
        ws._isAlive = false;
        ws.ping();
      });
    }, 30_000);

    // IPC: воркеры передают broadcast → primary
    cluster.on('message', (_worker: any, msg: any) => {
      if (!msg || msg.type !== IPC_TYPE) return;
      this.sendToUsers(msg.userIds, msg.data);
    });
  }

  private async handleAuth(ws: any, token: string, strapi: Core.Strapi) {
    try {
      const jwtService = strapi.service('plugin::users-permissions.jwt');
      const payload = await (jwtService as any).verify(token);
      const userId = payload?.id;
      if (!userId) {
        ws.send(JSON.stringify({ type: 'auth_error', message: 'Invalid token' }));
        return ws.close();
      }
      ws._userId = userId;
      if (!this.clients.has(userId)) this.clients.set(userId, new Set());
      this.clients.get(userId)!.add(ws);
      ws.send(JSON.stringify({ type: 'auth_ok', userId }));
    } catch {
      ws.send(JSON.stringify({ type: 'auth_error', message: 'Token verification failed' }));
      ws.close();
    }
  }

  private removeClient(ws: any) {
    const userId = ws._userId as number | undefined;
    if (!userId) return;
    const set = this.clients.get(userId);
    if (set) {
      set.delete(ws);
      if (set.size === 0) this.clients.delete(userId);
    }
  }

  sendToUser(userId: number, data: Record<string, unknown>) {
    const set = this.clients.get(userId);
    if (!set) return;
    const payload = JSON.stringify(data);
    set.forEach((ws: any) => {
      if (ws.readyState === WS_OPEN) ws.send(payload);
    });
  }

  sendToUsers(userIds: number[], data: Record<string, unknown>) {
    for (const id of userIds) this.sendToUser(id, data);
  }
}

/**
 * Отправить broadcast: если этот процесс владеет WS-сервером — напрямую,
 * иначе — через IPC к процессу-владельцу (работает в dev-режиме
 * с одним воркером; в multi-worker production нужен Redis pub/sub).
 */
function broadcast(userIds: number[], data: Record<string, unknown>) {
  if (WsManager.instance.hasServer()) {
    WsManager.instance.sendToUsers(userIds, data);
  } else if (typeof process.send === 'function') {
    process.send({ type: IPC_TYPE, userIds, data });
  }
}

export default {
  register() {},

  bootstrap({ strapi }: { strapi: Core.Strapi }) {
    // Каждый процесс пытается занять порт; тот, которому удалось — станет WS-сервером.
    // Остальные получат EADDRINUSE и тихо пропустят (см. wss.on('error')).
    WsManager.instance.start(strapi);

    // Lifecycle hook регистрируется в каждом процессе
    strapi.db.lifecycles.subscribe({
      models: ['api::message.message'],

      async afterCreate(event) {
        // In Strapi v5 with Draft & Publish, afterCreate fires TWICE for a
        // single REST-API create-with-publishedAt call:
        // 1) draft row  → published_at IS NULL
        // 2) published row → published_at IS NOT NULL
        // We must ONLY broadcast for the published row; broadcasting the draft
        // would cause duplicate notifications AND "disappearing messages" because
        // the draft row-id is not returned by the public REST API on reload.
        if (!event.result?.published_at) return;

        // Capture data we need INSIDE the lifecycle (before transaction closes).
        // event.params.data contains the input data passed to create(),
        // including the chat relation as a documentId string.
        const messageRowId = event.result?.id;
        const inputData = event.params?.data;
        const chatInput = inputData?.chat;

        if (!messageRowId) return;

        // Defer all DB queries to after the transaction commits.
        // SQLite deadlocks if we query other tables inside the same transaction.
        setImmediate(async () => {
          try {
            // 1. Resolve chat documentId
            let chatDocumentId: string | null = null;

            if (typeof chatInput === 'string' && chatInput.length > 10) {
              // Already a documentId string (from REST API: chat: "abc123...")
              chatDocumentId = chatInput;
            } else {
              // Fallback: look up from the link table (transaction is committed now)
              const linkRow = await strapi.db.connection('messages_chat_lnk')
                .where('message_id', messageRowId)
                .first('chat_id');
              if (linkRow?.chat_id) {
                const chatRow = await strapi.db.connection('chats')
                  .where('id', linkRow.chat_id)
                  .first('document_id');
                chatDocumentId = chatRow?.document_id || null;
              }
            }

            if (!chatDocumentId) return;

            // 2. Get chat participants (use published status to match REST API ids)
            const chat = await strapi.documents('api::chat.chat').findOne({
              documentId: chatDocumentId,
              status: 'published',
              populate: { users_permissions_users: { fields: ['id'] } },
            });
            if (!chat?.users_permissions_users?.length) return;

            const participantIds: number[] = chat.users_permissions_users.map((u: any) => u.id);

            // 3. Get full message via Document Service
            const msgRow = await strapi.db.connection('messages')
              .where('id', messageRowId)
              .first('document_id');
            if (!msgRow?.document_id) return;

            const fullMessage = await strapi.documents('api::message.message').findOne({
              documentId: msgRow.document_id,
              // Use 'published' status so the broadcast payload matches exactly
              // what the REST API returns (same row IDs). This prevents the
              // "disappearing messages" bug where the draft-id and published-id differ.
              status: 'published',
              populate: {
                users_permissions_user: {
                  fields: ['id', 'username', 'display_name'],
                  populate: { avatar: { fields: ['url'] } },
                },
                file_attachment: { fields: ['id', 'url', 'name', 'mime', 'size'] },
                chat: { fields: ['id', 'documentId'] },
                reply_to: {
                  fields: ['id', 'documentId', 'text', 'type'],
                  populate: {
                    users_permissions_user: { fields: ['id', 'username', 'display_name'] },
                  },
                },
              },
            });

            // 4. Broadcast to participants
            if (!fullMessage) {
              strapi.log.warn('WS: fullMessage is null, skipping broadcast for messageRowId=' + messageRowId);
              return;
            }
            broadcast(participantIds, {
              type: 'new_message',
              chatId: chat.id,
              chatDocumentId: chatDocumentId,
              message: fullMessage,
            });
          } catch (err) {
            strapi.log.error('WS broadcast error: ' + String(err));
          }
        });
      },
    });
  },
};
