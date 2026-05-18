import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'favorites_manager.dart';
import '../../models/audio_item.dart';
import 'youtube_player_page.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

const _kMediaCategories = {
  'Quran',
  'Story',
  'Health',
  'quran',
  'story',
  'health',
};

const _kNavy = Color(0xFF102E50);
const _kTeal = Color(0xFF4E949C);
const _kGreen = Color(0xFF3A8C78);
const _kGold = Color(0xFFF5C35D);

Color _accentFor(String cat) {
  switch (cat.toLowerCase()) {
    case 'quran':
      return _kTeal;
    case 'story':
      return _kNavy;
    case 'health':
      return _kGreen;
    default:
      return _kNavy;
  }
}

Color _bgFor(String cat) {
  switch (cat.toLowerCase()) {
    case 'quran':
      return const Color(0xFFDEF0EC);
    case 'story':
      return const Color(0xFFD6E4EE);
    case 'health':
      return const Color(0xFFE8F7F2);
    default:
      return const Color(0xFFD6E4EE);
  }
}

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

  void _showTopBanner(String message, {required Color color}) {
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  String _localizedCategory(String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category.trim().toLowerCase()) {
      case 'story':
        return loc.story;
      case 'quran':
        return loc.quran;
      case 'health':
        return loc.health;
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final favoriteAudios = favoritesManager.favorites.where((audio) {
      final cat = (audio['category'] ?? '').toString().trim();
      return _kMediaCategories.contains(cat);
    }).toList();

    final filteredFavorites = favoriteAudios.where((audio) {
      final title = (audio['title'] ?? '').toString().toLowerCase();
      final category = (audio['category'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in filteredFavorites) {
      final cat = (item['category'] ?? 'Other').toString();
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 30, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Color(0xFF1A2340),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 184, 214, 217),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        loc.favorites,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => searchQuery = v),
                  style: const TextStyle(
                    fontSize: 17,
                    fontFamily: 'NotoSansArabic',
                  ),
                  decoration: InputDecoration(
                    hintText: loc.searchFavorites,
                    hintStyle: TextStyle(
                      fontSize: 17,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _kNavy,
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: filteredFavorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 72,
                            color: _kNavy.withOpacity(0.18),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            loc.noResultsFound,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _kNavy.withOpacity(0.35),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: grouped.entries.map((entry) {
                        final category = entry.key;
                        final items = entry.value;
                        final accent = _accentFor(category);
                        final accentBg = _bgFor(category);
                        final localizedCat = _localizedCategory(category);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section divider + label
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    localizedCat,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${items.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: accent.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Cards
                            ...items.map((audio) {
                              final isArabic =
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode ==
                                  'ar';
                              final titleEn = (audio['title'] ?? '').toString();
                              final titleAr = (audio['titleAr'] ?? '')
                                  .toString();
                              final title = isArabic
                                  ? (titleAr.isNotEmpty ? titleAr : titleEn)
                                  : titleEn;
                              final image =
                                  (audio['image'] ?? 'assets/audio.jpg')
                                      .toString();

                              return _FavCard(
                                audio: audio,
                                title: title,
                                image: image,
                                accent: accent,
                                accentBg: accentBg,
                                onRemove: () async {
                                  await favoritesManager.toggleFavorite(audio);
                                  _showTopBanner(
                                    loc.removedFromFavorites,
                                    color: Colors.red.shade600,
                                  );
                                },
                                onTap: () {
                                  final type = (audio['type'] ?? 'audio')
                                      .toString();
                                  final url = audio['url'] as String?;
                                  final itemId =
                                      (audio['itemId'] ??
                                              audio['audioId'] ??
                                              audio['id'] ??
                                              '')
                                          .toString();
                                  final item = AudioItem(
                                    id: itemId,
                                    title: title,
                                    category: category,
                                    fileName: (audio['fileName'] ?? '')
                                        .toString(),
                                    tag: (audio['tag'] ?? '').toString(),
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
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Favourite card ────────────────────────────────────────────────────────────
class _FavCard extends StatelessWidget {
  final Map<String, dynamic> audio;
  final String title;
  final String image;
  final Color accent;
  final Color accentBg;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _FavCard({
    required this.audio,
    required this.title,
    required this.image,
    required this.accent,
    required this.accentBg,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  image,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title only — no bubble
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Remove button
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.red.shade400,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
