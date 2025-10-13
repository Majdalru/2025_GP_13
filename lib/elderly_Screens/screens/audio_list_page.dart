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

    final items = audioData[widget.category] ?? [];

    const backgroundColor = Color(0xFFFDFEFE);
    const appBarColor = Color(0xFF2C3E50);
    const textColor = Color(0xFF34495E);
    const cardColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 36, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category,
          style: const TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return Card(
            color: cardColor,
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Colors.grey.withOpacity(0.15),
                width: 1.0,
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
                  color: textColor,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  favoritesManager.isFavorite(item["title"]!)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: favoritesManager.isFavorite(item["title"]!)
                      ? Colors.red
                      : Colors.grey,
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

                  final isNowFavorite =
                      favoritesManager.isFavorite(item["title"]!);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isNowFavorite
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
                      duration: const Duration(seconds: 1),
                      backgroundColor: isNowFavorite
                          ? Colors.green
                          : Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
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
    );
  }
}
