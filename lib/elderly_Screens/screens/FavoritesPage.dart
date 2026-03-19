import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';
import '../../models/audio_item.dart';
import 'youtube_player_page.dart';
import '../../models/shared_item.dart';
import 'video_player_page.dart';
import 'shared_audio_player_page.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

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

  String _localizedCategory(BuildContext context, String category) {
    switch (category.trim().toLowerCase()) {
      case 'story':
        return AppLocalizations.of(context)!.story;
      case 'quran':
        return AppLocalizations.of(context)!.quran;
      case 'health':
        return AppLocalizations.of(context)!.health;
      case 'caregiver':
        return AppLocalizations.of(context)!.caregiver;
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteAudios = favoritesManager.favorites;

    final filteredFavorites = favoriteAudios.where((audio) {
      final title = (audio["title"] ?? '').toString().toLowerCase();
      final category = (audio["category"] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var item in filteredFavorites) {
      final cat =
          (item["category"] ?? AppLocalizations.of(context)!.other).toString();
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: Text(AppLocalizations.of(context)!.favorites),
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
                hintText: AppLocalizations.of(context)!.searchFavorites,
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
          Expanded(
            child: filteredFavorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 100,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppLocalizations.of(context)!.noResultsFound,
                          style: const TextStyle(
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
                      final localizedCategory =
                          _localizedCategory(context, category);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Text(
                              localizedCategory,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: kPrimary,
                              ),
                            ),
                          ),
                          ...items.map((audio) {
                            final isArabic = Localizations.localeOf(context).languageCode == 'ar';

final titleEn = (audio["title"] ?? "").toString();
final titleAr = (audio["titleAr"] ?? "").toString();

final title = isArabic
    ? (titleAr.isNotEmpty ? titleAr : titleEn)
    : titleEn;
                            final image =
                                (audio["image"] ?? 'assets/audio.jpg')
                                    .toString();

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
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
                                  localizedCategory,
                                  style: const TextStyle(
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
                                  onPressed: () async {
                                    await favoritesManager.toggleFavorite(audio);

                                    _showTopBanner(
                                      AppLocalizations.of(context)!
                                          .removedFromFavorites,
                                      color: Colors.red.shade700,
                                    );
                                  },
                                ),
                                onTap: () {
                                  final type =
                                      (audio["type"] ?? 'audio').toString();
                                  final url = audio["url"] as String?;

                                  if (type == "shared_video" ||
                                      type == "shared_audio") {
                                    if (url == null || url.isEmpty) {
                                      _showTopBanner(
                                        AppLocalizations.of(context)!
                                            .mediaLinkMissing,
                                        color: Colors.red.shade700,
                                      );
                                      return;
                                    }

                                    final sharedItem = SharedItem(
                                      id:
                                          (audio["itemId"] ??
                                                  audio["audioId"] ??
                                                  audio["id"] ??
                                                  '')
                                              .toString(),
                                      type: type == "shared_video"
                                          ? SharedItemType.video
                                          : SharedItemType.audio,
                                      title: title,
                                      url: url,
                                      fileName: (audio["fileName"] ?? '')
                                          .toString(),
                                      senderId:
                                          (audio["senderId"] ?? 'caregiver')
                                              .toString(),
                                      timestamp: DateTime.now(),
                                    );

                                    if (sharedItem.type ==
                                        SharedItemType.video) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              VideoPlayerPage(item: sharedItem),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SharedAudioPlayerPage(
                                            item: sharedItem,
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final itemId =
                                      (audio["itemId"] ??
                                              audio["audioId"] ??
                                              audio["id"] ??
                                              '')
                                          .toString();

                                  final item = AudioItem(
                                    id: itemId,
                                    title: title,
                                    category: category,
                                    fileName:
                                        (audio["fileName"] ?? '').toString(),
                                    tag: (audio["tag"] ?? '').toString(),
                                    imageAsset: image,
                                    type: type,
                                    url: url,
                                  );

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