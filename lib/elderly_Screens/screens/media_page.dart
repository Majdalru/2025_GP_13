import 'package:flutter/material.dart';
import 'audio_list_page.dart';
import 'Favoritespage.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F6FA);
    const appBarColor = Color(0xFF2C3E50);
    const iconColor = Color(0xFF34495E);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 3,
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 36, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Media",
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 30,
              childAspectRatio: 0.8,
              children: [
                _buildMediaCard(context, Icons.library_music, "Story"),
                _buildMediaCard(context, Icons.menu_book, "Quran"),
                _buildMediaCard(context, Icons.school, "Courses"),
                _buildMediaCard(context, Icons.favorite, "Health"),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
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
                icon: const Icon(Icons.favorite, size: 45, color: Colors.white),
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
                  backgroundColor: Color.fromARGB(255, 186, 90, 122),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(BuildContext context, IconData icon, String title) {
    const cardColor = Colors.white;
    const iconColor = Color(0xFF34495E);

    return Card(
      color: cardColor,
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: Color(0xFF2C3E50).withOpacity(0.1),
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
              Icon(icon, size: 90, color: iconColor),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
