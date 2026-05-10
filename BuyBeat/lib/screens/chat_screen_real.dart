import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/glass_theme.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/unread_count_service.dart';
import 'chat_conversation_screen.dart';

/// Экран списка чатов (вкладка Chat)
class ChatScreen extends StatefulWidget {
  /// Если передан — сразу открываем/создаём чат с этим пользователем
  final int? openChatWithUserId;
  final String? openChatWithUserName;

  const ChatScreen({
    super.key,
    this.openChatWithUserId,
    this.openChatWithUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService.instance;
  final _authService = AuthService();

  List<Chat> _chats = [];
  User? _currentUser;
  bool _isLoading = true;
  bool _didAutoOpen = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    UnreadCountService.instance.addListener(_onUnreadChanged);
  }

  void _onUnreadChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UnreadCountService.instance.removeListener(_onUnreadChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await _authService.getCurrentUser();
      final chats = await _chatService.getMyChats();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _chats = chats;
          _isLoading = false;
        });
        // Если попросили открыть чат — делаем это
        if (!_didAutoOpen && widget.openChatWithUserId != null) {
          _didAutoOpen = true;
          _openOrCreateChat(widget.openChatWithUserId!, widget.openChatWithUserName ?? 'User');
        }
      }
    } catch (e) {
      print('Ошибка загрузки чатов: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openOrCreateChat(int userId, String userName) async {
    // Показываем loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: LG.accent)),
    );

    try {
      final chat = await _chatService.getOrCreateChat(userId);
      if (!mounted) return;
      Navigator.pop(context); // закрываем loading
      _navigateToConversation(chat);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  void _navigateToConversation(Chat chat) async {
    // Mark as read when opening
    final key = chat.documentId ?? chat.id.toString();
    UnreadCountService.instance.markRead(key);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chat: chat,
          currentUserId: _currentUser?.id ?? 0,
        ),
      ),
    );
    // Обновляем список чатов при возврате
    _loadData();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    if (msgDay == today) return DateFormat.Hm().format(local);
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Вчера';
    return DateFormat('dd.MM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Чаты',
        showBack: false,
        leading: const SizedBox.shrink(),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: LG.accent))
          : _chats.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: LG.accent,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 80),
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: LG.border,
                      indent: 74,
                    ),
                    itemBuilder: (context, i) => _buildChatTile(_chats[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: LG.textMuted),
          const SizedBox(height: 16),
          Text(
            'Нет чатов',
            style: LG.font(color: LG.textSecondary, size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Напишите продюсеру со страницы бита',
            style: LG.font(color: LG.textMuted, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(Chat chat) {
    final uid = _currentUser?.id ?? 0;
    final name = chat.otherParticipantName(uid);
    final avatarUrl = chat.otherParticipantAvatarUrl(uid);
    final lastMsg = chat.lastMessageText;
    final lastTime = chat.lastMessageTime ?? chat.updatedAt;
    final unreadKey = chat.documentId ?? chat.id.toString();
    final unreadCount = UnreadCountService.instance.unreadFor(unreadKey);

    return InkWell(
      onTap: () => _navigateToConversation(chat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Аватар
            CircleAvatar(
              radius: 26,
              backgroundColor: LG.accent.withValues(alpha: 0.2),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: LG.font(
                        color: LG.accent,
                        weight: FontWeight.w800,
                        size: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Имя + last msg
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(
                      color: LG.textPrimary,
                      weight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                      size: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg ?? 'Нет сообщений',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(
                      color: unreadCount > 0
                          ? LG.textPrimary
                          : (lastMsg != null ? LG.textSecondary : LG.textMuted),
                      size: 13,
                      weight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Время + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(lastTime),
                  style: LG.font(
                    color: unreadCount > 0 ? LG.accent : LG.textMuted,
                    size: 12,
                    weight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (unreadCount > 0) ...
                  [
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: LG.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Color(0xFF0A0A0F),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
