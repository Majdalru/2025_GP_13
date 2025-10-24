import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';

class AudioListPage extends StatefulWidget {
  final String category;

  const AudioListPage({super.key, required this.category});

  @override
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage> {
  String searchQuery = '';

  static const kPrimary = Color(0xFF1B3A52);

  void _showTopBanner(String message, {Color color = kPrimary, int seconds = 5}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: color,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()], //  
        ),
      );

    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, String>>> audioData = {
      "Story": [
        {"title": "The Necklace", "image": "assets/images/story_necklace.jpg"},
        {"title": "The Tell-Tale Heart", "image": "assets/images/story_heart.jpg"},
        {"title": "The Open Window", "image": "assets/images/story_window.jpg"},
        {"title": "The Bet", "image": "assets/images/story_bet.jpg"},
      ],
      "Quran": [
        {"title": "Surah Yaseen", "image": "assets/images/quran_yaseen.jpg"},
        {"title": "Surah Al-Mulk", "image": "assets/images/quran_mulk.jpg"},
      ],
      "Courses": [
        {"title": "Using Your Phone Safely", "image": "assets/images/course_phone.jpg"},
        {"title": "Keeping Your Memory Sharp", "image": "assets/images/course_memory.jpg"},
        {"title": "Introduction to AI (Simple Talk)", "image": "assets/images/course_ai.jpg"},
      ],
      "Health": [
        {"title": "Easy Morning Exercises", "image": "assets/images/health_morning.jpg"},
        {"title": "Tips for Better Sleep", "image": "assets/images/health_sleep.jpg"},
        {"title": "Foods That Boost Memory", "image": "assets/images/health_food.jpg"},
        {"title": "Stretching for Seniors", "image": "assets/images/health_stretch.jpg"},
      ],
    };

    final allItems = audioData[widget.category] ?? [];
    final filteredItems = allItems
        .where((item) => item["title"]!
            .toLowerCase()
            .contains(searchQuery.toLowerCase()))
        .toList();

    const cardColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: Text(widget.category),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ===== Search Bar =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                style: const TextStyle(fontSize: 22, fontFamily: 'NotoSansArabic'),
                decoration: InputDecoration(
                  hintText: 'Search for audio...',
                  hintStyle: const TextStyle(fontSize: 22, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 30, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ===== List of Audio Cards =====
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isFavorite =
                            favoritesManager.isFavorite(item["title"]!);

                        return Card(
                          color: cardColor,
                          elevation: 3,
                          shadowColor: kPrimary.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: kPrimary.withOpacity(0.8),
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(20),
                            leading: CircleAvatar(
                              radius: 35,
                              backgroundImage: AssetImage(item["image"]!),
                            ),
                            title: Text(
                              item["title"]!,
                              style: const TextStyle(
                                fontFamily: 'NotoSansArabic',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: kPrimary,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.grey,
                                size: 36,
                              ),
                              onPressed: () {
                                setState(() {
                                  favoritesManager.toggleFavorite({
                                    "title": item["title"]!,
                                    "category": widget.category,
                                    "image": item["image"]!,
                                  });
                                });

                                final nowFav =
                                    favoritesManager.isFavorite(item["title"]!);

                                // ===== إشعار علوي بدل SnackBar =====
                                _showTopBanner(
                                  nowFav
                                      ? 'Added to Favorites successfully'
                                      : 'Removed from Favorites',
                                  color: nowFav
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                );
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AudioPlayerPage(
                                    title: item["title"]!,
                                    category: widget.category,
                                  ),
                                ),
                              );
                            },
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
