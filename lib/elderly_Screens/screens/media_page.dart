import 'package:flutter/material.dart';
import 'audio_list_page.dart';
import 'Favoritespage.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand color (dark blue)
    const darkBlue = Color(0xFF2A4D69);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: back button + title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        size: 36, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    "Media",
                    style: TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Grid of media cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 30,
                  childAspectRatio: 0.8,
                  children: [
                    _buildMediaCard(context, Icons.library_music, "Story", darkBlue),
                    _buildMediaCard(context, Icons.menu_book, "Quran", darkBlue),
                    _buildMediaCard(context, Icons.school, "Courses", darkBlue),
                    _buildMediaCard(context, Icons.favorite, "Health", darkBlue),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Favorites button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 90,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoritesPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite,
                        size: 45, color: Colors.white),
                    label: const Text(
                      "Favorites",
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard(
      BuildContext context, IconData icon, String title, Color borderColor) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: borderColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor.withOpacity(0.9), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: borderColor.withOpacity(0.15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioListPage(category: title),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 90, color: borderColor),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: borderColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
