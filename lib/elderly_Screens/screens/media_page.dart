import 'package:flutter/material.dart';
import 'audio_list_page.dart';
import 'Favoritespage.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  static const kPrimary = Color(0xFF1B3A52);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),

      // 🔹 AppBar مثل الصورة
       appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: const Color(0xFF1B3A52),
        title: const Text("Media"),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),

      // 🔹 المحتوى
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Grid مصغّرة قليلاً
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 25,
                childAspectRatio: 0.8, // 🔹 أصغر شوي
                children: [
                  _buildMediaCard(context, Icons.library_music, "Story"),
                  _buildMediaCard(context, Icons.menu_book, "Quran"),
                  _buildMediaCard(context, Icons.upload_file, "Caregiver"),
                  _buildMediaCard(context, Icons.favorite, "Health"),
                ],
              ),

              const SizedBox(height: 40),

              // 🔹 زر Favorites بنفس تنسيق الهوم
              SizedBox(
                width: double.infinity,
                height: 90,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesPage()),
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
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard(BuildContext context, IconData icon, String title) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: kPrimary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: kPrimary.withOpacity(0.9), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: kPrimary.withOpacity(0.15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AudioListPage(category: title)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: kPrimary), // 🔹 أصغر شوي
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 26, // 🔹 أصغر قليلاً
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
