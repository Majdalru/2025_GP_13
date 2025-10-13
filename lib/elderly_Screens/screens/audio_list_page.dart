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

    final filteredItems = allItems.where((item) {
      final title = item["title"]!.toLowerCase();
      return title.contains(searchQuery.toLowerCase());
    }).toList();

    const darkBlue = Color(0xFF2A4D69); // الأزرق الداكن
    const cardColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Top Row (Back + Title)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        size: 36, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.category,
                    style: const TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                style:
                    const TextStyle(fontSize: 22, fontFamily: 'NotoSansArabic'),
                decoration: InputDecoration(
                  hintText: 'Search for audio...',
                  hintStyle:
                      const TextStyle(fontSize: 22, color: Colors.grey),
                  prefixIcon:
                      const Icon(Icons.search, size: 30, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 15, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 List of Audio Cards
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
                          shadowColor: darkBlue.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: darkBlue.withOpacity(0.8),
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(20),
                            leading: CircleAvatar(
                              radius: 35,
                              backgroundImage:
                                  AssetImage(item["image"]!),
                            ),
                            title: Text(
                              item["title"]!,
                              style: const TextStyle(
                                fontFamily: 'NotoSansArabic',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: darkBlue,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    isFavorite ? Colors.red : Colors.grey,
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

                                final nowFav = favoritesManager
                                    .isFavorite(item["title"]!);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      nowFav
                                          ? 'Added to Favorites'
                                          : 'Removed from Favorites',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'NotoSansArabic',
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    duration:
                                        const Duration(milliseconds: 1200),
                                    backgroundColor:
                                        nowFav ? Colors.green : Colors.red,
                                    behavior:
                                        SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(15),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 20,
                                    ),
                                  ),
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
