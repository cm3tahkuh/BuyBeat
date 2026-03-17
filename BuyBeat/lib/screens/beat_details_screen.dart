import 'package:flutter/material.dart';

class BeatDetailsScreen extends StatelessWidget {
  final String title;
  final String genre;
  final String author;

  const BeatDetailsScreen({
    super.key,
    required this.title,
    required this.genre,
    required this.author,
  });

  final List<Map<String, String>> mockFiles = const [
    {"type": "MP3", "price": "\$10"},
    {"type": "WAV", "price": "\$20"},
    {"type": "STEMS", "price": "\$40"},
    {"type": "PROJECT", "price": "\$100"},
    {"type": "EXCLUSIVE", "price": "\$500"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заглушка для обложки
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[800],
              child: const Icon(Icons.album, size: 100, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("$genre • $author", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            const Text("Available files:", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: mockFiles.length,
                itemBuilder: (context, index) {
                  final file = mockFiles[index];
                  return Card(
                    color: Colors.grey[900],
                    child: ListTile(
                      title: Text(file["type"]!, style: const TextStyle(color: Colors.white)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Buying ${file["type"]} for ${file["price"]}")),
                          );
                        },
                        child: Text("Buy ${file["price"]}"),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
