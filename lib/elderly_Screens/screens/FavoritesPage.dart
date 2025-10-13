import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String searchQuery = '';

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

    final filteredFavorites = favoriteAudios.where((audio) {
      final title = audio["title"]!.toLowerCase();
      final category = audio["category"]!.toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    const darkBlue = Color(0xFF2A4D69);

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
                  const Text(
                    "Favorites",
                    style: TextStyle(
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
                  hintText: 'Search favorites...',
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

            // 🔹 Favorites List
            Expanded(
              child: filteredFavorites.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border,
                              size: 100, color: Colors.grey),
                          SizedBox(height: 20),
                          Text(
                            "No results found",
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 24,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredFavorites.length,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      itemBuilder: (context, index) {
                        final audio = filteredFavorites[index];
                        return Card(
                          color: Colors.white,
                          elevation: 3,
                          shadowColor: darkBlue.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: darkBlue.withOpacity(0.9),
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              radius: 35,
                              backgroundImage:
                                  AssetImage(audio["image"]!),
                            ),
                            title: Text(
                              audio["title"]!,
                              style: const TextStyle(
                                fontFamily: 'NotoSansArabic',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: darkBlue,
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
            ),
          ],
        ),
      ),
    );
  }
}
