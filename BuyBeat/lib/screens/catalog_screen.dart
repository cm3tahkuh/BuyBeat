import 'package:flutter/material.dart';
import 'beat_details_screen.dart';

class CatalogScreen extends StatelessWidget {
  final Function(String)? onPlay;

  const CatalogScreen({super.key, this.onPlay});

  final List<Map<String, String>> mockBeats = const [
    {"title": "Trap Beat 1", "genre": "Trap", "author": "Producer A"},
    {"title": "Lo-fi Chill", "genre": "Lo-fi", "author": "Producer B"},
    {"title": "Drill Madness", "genre": "Drill", "author": "Producer C"},
    {"title": "Dark Piano", "genre": "Trap", "author": "Producer D"},
    {"title": "Night Ride", "genre": "Lo-fi", "author": "Producer E"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Colors.black,
  appBar: AppBar(
    backgroundColor: const Color(0xFF000000), // ✅ правильный чёрный цвет
    elevation: 0,
    title: const Text(
      "Каталог битов",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    centerTitle: true,
  ),
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ListView.separated(
        itemCount: mockBeats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final beat = mockBeats[index];
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF000000), // ✅ теперь точно чёрный
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blueAccent.withOpacity(0.15),
                width: 1,
              ),
            ),
                child: ListTile(
                  leading: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.music_note,
                        color: Colors.blueAccent, size: 22),
                  ),
                  title: Text(
                    beat["title"]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    "${beat["genre"]} • ${beat["author"]}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow,
                        color: Colors.blueAccent, size: 28),
                    onPressed: () {
                      onPlay?.call(beat["title"]!);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BeatDetailsScreen(
                          title: beat["title"]!,
                          genre: beat["genre"]!,
                          author: beat["author"]!,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
