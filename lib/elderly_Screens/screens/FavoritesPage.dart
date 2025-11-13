import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';
import '../../models/audio_item.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String searchQuery = '';

  static const kPrimary = Color(0xFF1B3A52);

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

  void _showTopBanner(String message,
      {Color color = kPrimary, int seconds = 700}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: color,
          content: Text(
            message,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );

    Future.delayed(Duration(milliseconds: seconds), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteAudios = favoritesManager.favorites;

    final filteredFavorites = favoriteAudios.where((audio) {
      final title = audio["title"].toLowerCase();
      final category = audio["category"].toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: const Text("Favorites"),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              style:
                  const TextStyle(fontSize: 22, fontFamily: 'NotoSansArabic'),
              decoration: InputDecoration(
                hintText: 'Search favorites...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),

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
                              fontSize: 24, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: filteredFavorites.length,
                    itemBuilder: (context, index) {
                      final audio = filteredFavorites[index];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side:
                              BorderSide(color: kPrimary.withOpacity(0.9), width: 2),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 35,
                            backgroundImage: AssetImage(audio["image"]),
                          ),
                          title: Text(
                            audio["title"],
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: kPrimary),
                          ),
                          subtitle: Text(
                            audio["category"],
                            style: const TextStyle(
                                fontSize: 20, color: Colors.grey),
                          ),

                          trailing: IconButton(
                            icon: const Icon(Icons.favorite,
                                color: Colors.red, size: 36),
                            onPressed: () {
                              favoritesManager.toggleFavorite(audio);

                              _showTopBanner("Removed from Favorites",
                                  color: Colors.red.shade700);
                            },
                          ),

                          onTap: () {
                            final item = AudioItem(
                              id: audio["audioId"],
                              title: audio["title"],
                              category: audio["category"],
                              fileName: audio["fileName"],
                              imageAsset: audio["image"],
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AudioPlayerPage(item: item),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
