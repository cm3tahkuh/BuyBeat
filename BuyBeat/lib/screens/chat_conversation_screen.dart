import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/glass_theme.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';
import '../services/in_app_notification_service.dart';

/// Экран переписки в конкретном чате
class ChatConversationScreen extends StatefulWidget {
  final Chat chat;
  final int currentUserId;

  const ChatConversationScreen({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _chatService = ChatService.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Message> _messages = [];
  /// ID сообщений, отправленных в этой сессии (для правильного определения «слева/справа»
  /// когда POST-ответ возвращает sender без populate)
  final _mySentIds = <int>{};
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription? _wsSub;

  String get _otherName => widget.chat.otherParticipantName(widget.currentUserId);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Подписка на WebSocket-события новых сообщений
    _wsSub = WebSocketService.instance.onNewMessage.listen(_onWsMessage);
    // Сообщаем NotificationService что этот чат открыт
    InAppNotificationService.instance.activeChatId = widget.chat.id;
    InAppNotificationService.instance.activeChatDocumentId = widget.chat.documentId;
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    // Сбрасываем активный чат
    InAppNotificationService.instance.activeChatId = null;
    InAppNotificationService.instance.activeChatDocumentId = null;
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final docId = widget.chat.documentId;
      if (docId == null) throw Exception('Chat documentId is null');
      final msgs = await _chatService.getChatMessages(docId, pageSize: 200);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Ошибка загрузки сообщений: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Тихая перезагрузка (без индикатора загрузки) — используется после отправки файла
  Future<void> _reloadMessages() async {
    try {
      final docId = widget.chat.documentId;
      if (docId == null) return;
      final msgs = await _chatService.getChatMessages(docId, pageSize: 200);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  /// Обработка нового сообщения через WebSocket
  void _onWsMessage(WsNewMessageEvent event) {
    // Игнорируем сообщения для другого чата (сопоставляем по documentId)
    final myDocId = widget.chat.documentId;
    if (myDocId != null && event.chatDocumentId != null) {
      if (event.chatDocumentId != myDocId) return;
    } else {
      if (event.chatId != widget.chat.id) return;
    }
    // Игнорируем дубли (по id и documentId)
    final eId = event.message.id;
    final eDocId = event.message.documentId;
    if (_messages.any((m) =>
        m.id == eId ||
        (eDocId != null && eDocId == m.documentId))) return;

    if (mounted) {
      setState(() {
        _messages.add(event.message);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    setState(() => _isSending = true);

    try {
      final msg = await _chatService.sendMessage(
        chatDocumentId: widget.chat.documentId!,
        text: text,
      );
      if (mounted) {
        setState(() {
          _mySentIds.add(msg.id);
          // Дубль-проверка: WS мог уже добавить это сообщение пока шёл re-fetch
          if (!_messages.any((m) =>
              m.id == msg.id ||
              (msg.documentId != null && msg.documentId == m.documentId))) {
            _messages.add(msg);
          }
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    }
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: LG.bgLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LG.radiusL)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LG.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Прикрепить файл',
                style: LG.font(
                  color: LG.textPrimary,
                  size: 16,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(Icons.image, 'Фото', LG.blue, () {
                    Navigator.pop(ctx);
                    _pickAndSendFile(FileType.custom, extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic']);
                  }),
                  _attachOption(Icons.audiotrack, 'Аудио', LG.orange, () {
                    Navigator.pop(ctx);
                    _pickAndSendFile(FileType.custom, extensions: ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma']);
                  }),
                  _attachOption(Icons.videocam, 'Видео', LG.red, () {
                    Navigator.pop(ctx);
                    _pickAndSendFile(FileType.custom, extensions: ['mp4', 'mov', 'avi', 'webm', 'mkv', 'flv', '3gp']);
                  }),
                  _attachOption(Icons.description, 'Документ', LG.accent, () {
                    Navigator.pop(ctx);
                    _pickAndSendFile(FileType.any, asDocument: true);
                  }),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: LG.font(color: LG.textSecondary, size: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendFile(FileType type, {List<String>? extensions, bool asDocument = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: extensions,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isSending = true);

      final msg = await _chatService.sendFileBytes(
        chatDocumentId: widget.chat.documentId!,
        bytes: file.bytes!,
        fileName: file.name,
        text: asDocument ? '__doc__' : null,
      );

      if (mounted) {
        // Добавляем ID в набор «моих» сообщений до перезагрузки
        _mySentIds.add(msg.id);
        setState(() => _isSending = false);
        // Перезагружаем с сервера, чтобы получить populated file_attachment
        await _reloadMessages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки файла: $e')),
        );
      }
    }
  }

  Future<void> _openFileUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть файл')),
          );
        }
      }
    }
  }

  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    if (msgDay == today) return 'Сегодня';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Вчера';
    return DateFormat('d MMMM yyyy', 'ru').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      showBlobs: false,
      appBar: GlassAppBar(
        titleWidget: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: LG.accent.withValues(alpha: 0.2),
              child: Text(
                _otherName.isNotEmpty ? _otherName[0].toUpperCase() : '?',
                style: LG.font(color: LG.accent, weight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Text(_otherName, style: LG.font(weight: FontWeight.w700, size: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Сообщения
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: LG.accent))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Начните переписку!',
                          style: LG.font(color: LG.textMuted, size: 15),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 80, 14, 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          // Проверяем и по set (для только что отправленных без populate)
                          // и по senderId (для загруженных с сервера)
                          final isMe = _mySentIds.contains(msg.id) ||
                              msg.senderId == widget.currentUserId;
                          final showDate = i == 0 ||
                              (msg.createdAt != null &&
                                  _messages[i - 1].createdAt != null &&
                                  DateTime(msg.createdAt!.year, msg.createdAt!.month, msg.createdAt!.day) !=
                                      DateTime(_messages[i - 1].createdAt!.year, _messages[i - 1].createdAt!.month, _messages[i - 1].createdAt!.day));

                          return Column(
                            children: [
                              if (showDate && msg.createdAt != null) _dateDivider(msg.createdAt!),
                              _buildBubble(msg, isMe),
                            ],
                          );
                        },
                      ),
          ),

          // Ввод
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: LG.blurMedium, sigmaY: LG.blurMedium),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
                decoration: BoxDecoration(
                  color: LG.panelFill,
                  border: Border(top: BorderSide(color: LG.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Кнопка прикрепления файла
                      GestureDetector(
                        onTap: _isSending ? null : _showAttachMenu,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: LG.accent.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            Icons.attach_file,
                            color: _isSending ? LG.textMuted : LG.accent,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: LG.font(color: LG.textPrimary),
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Сообщение...',
                            hintStyle: LG.font(color: LG.textMuted),
                            filled: true,
                            fillColor: LG.bgLight,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: LG.accent.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isSending ? null : _send,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isSending ? null : LG.accentGradient,
                            color: _isSending ? LG.panelFill : null,
                          ),
                          child: _isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send, color: Color(0xFF0A0A0F), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: LG.panelFill,
            borderRadius: BorderRadius.circular(LG.radiusS),
            border: Border.all(color: LG.border, width: 0.5),
          ),
          child: Text(
            _formatDateDivider(date),
            style: LG.font(color: LG.textMuted, size: 12, weight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(Message msg, bool isMe) {
    final time = msg.createdAt != null ? DateFormat.Hm().format(msg.createdAt!) : '';
    final avatarUrl = isMe ? null : msg.senderAvatarUrl;
    final initial = (!isMe && msg.senderName?.isNotEmpty == true)
        ? msg.senderName![0].toUpperCase()
        : _otherName.isNotEmpty
            ? _otherName[0].toUpperCase()
            : '?';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? LG.accent : LG.panelFillLight,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        border: isMe ? null : Border.all(color: LG.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Файловое вложение
          if (msg.isFile) ...[
            if (msg.fileUrl != null)
              _buildFileContent(msg, isMe)
            else
              // Файл ещё не получен с сервера — показываем заглушку
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(LG.radiusS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: LG.textMuted),
                    ),
                    const SizedBox(width: 10),
                    Text('Загрузка файла...', style: LG.font(color: LG.textMuted, size: 13)),
                  ],
                ),
              ),
            if (msg.text != null && msg.text!.isNotEmpty) const SizedBox(height: 6),
          ],
          // Текст сообщения (скрываем маркер __doc__)
          if (msg.text != null && msg.text!.isNotEmpty && msg.text != '__doc__')
            Text(msg.text!, style: LG.font(color: isMe ? const Color(0xFF0A0A0F) : Colors.white, size: 14)),
          const SizedBox(height: 4),
          Text(
            time,
            style: LG.font(
              color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.55) : LG.textMuted,
              size: 11,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: LG.accent.withValues(alpha: 0.2),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(initial,
                      style: LG.font(color: LG.accent, size: 12, weight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMe ? 300 : 270),
            child: bubble,
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Рендер файлового вложения в зависимости от типа
  Widget _buildFileContent(Message msg, bool isMe) {
    final sentAsDoc = msg.text == '__doc__';
    if (msg.isImage && !sentAsDoc) return _buildImageAttachment(msg);
    if (msg.isAudio) return _buildAudioAttachment(msg, isMe);
    if (msg.isVideo) return _buildVideoAttachment(msg, isMe);
    return _buildDocumentAttachment(msg, isMe);
  }

  /// Превью изображения
  Widget _buildImageAttachment(Message msg) {
    return GestureDetector(
      onTap: () => _openFileUrl(msg.fileUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LG.radiusS),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
          child: Image.network(
            msg.fileUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: LG.panelFill,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: LG.textMuted)),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 200,
              height: 80,
              color: LG.panelFill,
              child: const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 32)),
            ),
          ),
        ),
      ),
    );
  }

  /// Карточка аудио
  Widget _buildAudioAttachment(Message msg, bool isMe) {
    return GestureDetector(
      onTap: () => _openFileUrl(msg.fileUrl!),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(LG.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LG.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.audiotrack, color: LG.orange, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.fileName ?? 'Аудио',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(color: isMe ? const Color(0xFF0A0A0F) : Colors.white, size: 13, weight: FontWeight.w600),
                  ),
                  if (msg.fileSizeFormatted.isNotEmpty)
                    Text(
                      msg.fileSizeFormatted,
                      style: LG.font(color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.55) : LG.textMuted, size: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_fill, color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.7) : LG.orange, size: 28),
          ],
        ),
      ),
    );
  }

  /// Карточка видео
  Widget _buildVideoAttachment(Message msg, bool isMe) {
    return GestureDetector(
      onTap: () => _openFileUrl(msg.fileUrl!),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(LG.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LG.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.videocam, color: LG.red, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.fileName ?? 'Видео',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(color: isMe ? const Color(0xFF0A0A0F) : Colors.white, size: 13, weight: FontWeight.w600),
                  ),
                  if (msg.fileSizeFormatted.isNotEmpty)
                    Text(
                      msg.fileSizeFormatted,
                      style: LG.font(color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.55) : LG.textMuted, size: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_fill, color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.7) : LG.red, size: 28),
          ],
        ),
      ),
    );
  }

  /// Карточка документа
  Widget _buildDocumentAttachment(Message msg, bool isMe) {
    return GestureDetector(
      onTap: () => _openFileUrl(msg.fileUrl!),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(LG.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LG.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.description, color: LG.accent, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.fileName ?? 'Документ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LG.font(color: isMe ? const Color(0xFF0A0A0F) : Colors.white, size: 13, weight: FontWeight.w600),
                  ),
                  if (msg.fileSizeFormatted.isNotEmpty)
                    Text(
                      msg.fileSizeFormatted,
                      style: LG.font(color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.55) : LG.textMuted, size: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download, color: isMe ? const Color(0xFF0A0A0F).withValues(alpha: 0.7) : LG.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
