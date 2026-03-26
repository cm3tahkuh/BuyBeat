import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // для форматирования дат

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _chats = [
    {
      "id": 1,
      "name": "Producer A",
      "lastMessage": "Yo! I got a new beat 🔥",
      "messages": [
        {
          "user": "Producer A",
          "text": "Yo! I got a new beat 🔥",
          "date": DateTime(2025, 9, 15, 22, 30),
        },
        {
          "user": "Me",
          "text": "Send it over, bro!",
          "date": DateTime(2025, 9, 15, 22, 31),
        },
        {
          "user": "Producer A",
          "text": "Sure, check your inbox 😉",
          "date": DateTime(2025, 9, 16, 10, 15),
        },
      ]
    },
    {
      "id": 2,
      "name": "Artist B",
      "lastMessage": "Let’s collab soon!",
      "messages": [
        {
          "user": "Artist B",
          "text": "Let’s collab soon!",
          "date": DateTime(2025, 9, 16, 12, 0),
        },
        {
          "user": "Me",
          "text": "I’m down, send me stems 🎹",
          "date": DateTime(2025, 9, 16, 12, 5),
        },
      ]
    },
  ];

  Map<String, dynamic>? _selectedChat;
  final TextEditingController _controller = TextEditingController();

  void _selectChat(Map<String, dynamic> chat) {
    setState(() {
      _selectedChat = chat;
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty || _selectedChat == null) return;

    setState(() {
      _selectedChat!["messages"].add({
        "user": "Me",
        "text": _controller.text.trim(),
        "date": DateTime.now(),
      });
      _selectedChat!["lastMessage"] = _controller.text.trim();
      _controller.clear();
    });
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(local.year, local.month, local.day);

    if (messageDay == today) {
      return "Сегодня";
    } else if (messageDay == yesterday) {
      return "Вчера";
    } else {
      return DateFormat("d MMMM yyyy", "ru").format(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chats")),
      body: Row(
        children: [
          // Левая колонка (список чатов)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[900],
              child: ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  final isSelected = _selectedChat?["id"] == chat["id"];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    color: isSelected ? Colors.blue[800] : Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectChat(chat),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            chat["name"][0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          chat["name"],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          chat["lastMessage"],
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Правая колонка (выбранный чат)
          Expanded(
            flex: 2,
            child: _selectedChat == null
                ? const Center(
                    child: Text(
                      "Select a chat to start messaging",
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _selectedChat!["messages"].length,
                          itemBuilder: (context, index) {
                            final msg = _selectedChat!["messages"][index];
                            final isMe = msg["user"] == "Me";
                            final date = msg["date"] as DateTime;

                            // Определяем, нужно ли показать разделитель даты
                            bool showDateDivider = false;
                            if (index == 0) {
                              showDateDivider = true;
                            } else {
                              final prevDate = _selectedChat!["messages"][index - 1]["date"] as DateTime;
                              if (DateTime(prevDate.year, prevDate.month, prevDate.day) !=
                                  DateTime(date.year, date.month, date.day)) {
                                showDateDivider = true;
                              }
                            }

                            return Column(
                              children: [
                                if (showDateDivider)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDate(date),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: isMe
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.grey[700],
                                          child: Text(
                                            msg["user"][0],
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                      const SizedBox(width: 6),
                                      Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.blue
                                              : Colors.grey[800],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          msg["text"],
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      if (isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.blue,
                                            child: const Text(
                                              "M",
                                              style: TextStyle(
                                                  color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Поле ввода
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: Colors.grey[850],
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Type a message...",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.blue),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
