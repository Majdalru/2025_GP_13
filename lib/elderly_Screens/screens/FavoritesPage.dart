import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';
import '../../models/audio_item.dart';
import 'youtube_player_page.dart';

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

  void _showTopBanner(
    String message, {
    Color color = kPrimary,
    int milliseconds = 700,
  }) {
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );

    Future.delayed(Duration(milliseconds: milliseconds), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteAudios = favoritesManager.favorites;

    // فلترة البحث
    final filteredFavorites = favoriteAudios.where((audio) {
      final title = (audio["title"] ?? '').toLowerCase();
      final category = (audio["category"] ?? '').toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    // نصنّف بحسب الكاتيجوري
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var item in filteredFavorites) {
      final cat = item["category"] ?? "Other";
      grouped.putIfAbsent(cat, () => []).add(item);
    }

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
          // حقل البحث
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              style: const TextStyle(
                fontSize: 22,
                fontFamily: 'NotoSansArabic',
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search favorites...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // محتوى الصفحة
          Expanded(
            child: filteredFavorites.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 100,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20),
                        Text(
                          "No results found",
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    children: grouped.entries.map((entry) {
                      final category = entry.key;
                      final items = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // عنوان القسم (Story / Quran / Health / Caregiver)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: kPrimary,
                              ),
                            ),
                          ),

                          // عناصر الفيفورت في هذا القسم
                          ...items.map((audio) {
                            final title = audio["title"] ?? "";
                            final image =
                                audio["image"] ?? 'assets/audio.jpg';

                            return Card(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: kPrimary.withOpacity(0.9),
                                  width: 2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  radius: 35,
                                  backgroundImage: AssetImage(image),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: kPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey,
                                  ),
                                ),

                                // زر حذف من الفيفورت
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 36,
                                  ),
                                  onPressed: () async {
                                    await favoritesManager
                                        .toggleFavorite(audio);

                                    _showTopBanner(
                                      "Removed from Favorites",
                                      color: Colors.red.shade700,
                                    );
                                  },
                                ),

                                onTap: () {
                                  // نقرأ النوع والرابط من البيانات المخزّنة
                                  final type =
                                      (audio["type"] ?? 'audio') as String;
                                  final url = audio["url"] as String?;

                                  final item = AudioItem(
                                    id: audio["audioId"] ?? '',
                                    title: title,
                                    category: category,
                                    fileName:
                                        audio["fileName"] ?? '',
                                    tag: audio["tag"] ?? '',
                                    imageAsset: image,
                                    type: type,
                                    url: url,
                                  );

                                  // لو يوتيوب → افتح صفحة يوتيوب
                                  if (item.type == 'youtube' &&
                                      item.url != null &&
                                      item.url!.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            YouTubePlayerPage(item: item),
                                      ),
                                    );
                                  } else {
                                    // غير كذا → Audio عادي
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AudioPlayerPage(item: item),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
