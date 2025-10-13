import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    favoritesManager.addListener(_update);
  }

  @override
  void dispose() {
    favoritesManager.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final favoriteAudios = favoritesManager.favorites;

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
        title: const Text(
          "Favorites",
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: favoriteAudios.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    "No favorites yet",
                    style: TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 24,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: favoriteAudios.length,
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              itemBuilder: (context, index) {
                final audio = favoriteAudios[index];
                return Card(
                  color: cardColor,
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 35,
                      backgroundImage: AssetImage(audio["image"]!),
                    ),
                    title: Text(
                      audio["title"]!,
                      style: const TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      audio["category"]!,
                      style: const TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 20,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 36,
                      ),
                      onPressed: () {
                        favoritesManager.toggleFavorite(audio);
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AudioPlayerPage(
                            title: audio["title"]!,
                            category: audio["category"]!,
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
