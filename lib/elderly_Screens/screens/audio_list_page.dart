import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'youTube_player_page.dart';
import 'favorites_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/audio_item.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class AudioListPage extends StatefulWidget {
  final String category;
  const AudioListPage({super.key, required this.category});

  @override
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage> {
  String searchQuery = '';
  String _selectedTag = 'All';

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _kNavy = Color(0xFF102E50);
  static const _kTeal = Color(0xFF4E949C);
  static const _kGreen = Color(0xFF3A8C78);

  Color get _accent {
    switch (widget.category) {
      case 'Quran':
        return _kTeal;
      case 'Story':
        return _kNavy;
      case 'Health':
        return _kGreen;
      default:
        return _kNavy;
    }
  }

  Color get _accentBg {
    switch (widget.category) {
      case 'Quran':
        return const Color(0xFFDEF0EC);
      case 'Story':
        return const Color(0xFFD6E4EE);
      case 'Health':
        return const Color(0xFFE8F7F2);
      default:
        return const Color(0xFFD6E4EE);
    }
  }

  final Map<String, List<String>> _tagsPerCategory = {
    'Quran': ['All', 'maher-almuaiqly', 'saad-alghamdi', 'alminshawi'],
    'Story': ['All', 'islamic', 'world'],
    'Health': ['All', 'food', 'sleep', 'general'],
    'Caregiver': ['All'],
  };

  String _getTitle(AudioItem item) {
    final lang = Localizations.localeOf(context).languageCode;
    if (widget.category == 'Quran' && lang == 'ar') {
      return item.titleAr?.isNotEmpty == true ? item.titleAr! : item.title;
    }
    return item.title;
  }

  void _showTopBanner(String message, {required Color color}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: color,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  String _localizedCategoryTitle(String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category) {
      case 'Quran':
        return loc.quran;
      case 'Story':
        return loc.story;
      case 'Health':
        return loc.health;
      case 'Caregiver':
        return loc.caregiver;
      case 'Favorites':
        return loc.favorites;
      default:
        return category;
    }
  }

  String _localizedTagLabel(String tag) {
    final loc = AppLocalizations.of(context)!;
    switch (tag) {
      case 'All':
        return loc.all;
      case 'maher-almuaiqly':
        return loc.maherAlMuaiqly;
      case 'saad-alghamdi':
        return loc.saadAlGhamdi;
      case 'alminshawi':
        return loc.alMinshawi;
      case 'islamic':
        return loc.islamicStories;
      case 'world':
        return loc.worldStories;
      case 'food':
        return loc.food;
      case 'sleep':
        return loc.sleep;
      case 'general':
        return loc.generalHealth;
      default:
        return tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final accent = _accent;
    final acBg = _accentBg;
    final tags = _tagsPerCategory[widget.category] ?? ['All'];

    final stream =
        (widget.category == 'Story' || widget.category == 'Health') &&
            lang == 'ar'
        ? FirebaseFirestore.instance
              .collection('audioMedia')
              .where('category', isEqualTo: widget.category)
              .where('language', isEqualTo: 'ar')
              .snapshots()
        : FirebaseFirestore.instance
              .collection('audioMedia')
              .where('category', isEqualTo: widget.category)
              .snapshots();

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
                      backgroundColor: Color.fromARGB(
                        255,
                        230,
                        232,
                        234,
                      ), // light circle
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _localizedCategoryTitle(widget.category),
                        style: const TextStyle(
                          fontSize: 26,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    hintText: loc.searchForAudio,
                    hintStyle: TextStyle(
                      fontSize: 17,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: accent,
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

            const SizedBox(height: 10),

            // ── Tag chips ────────────────────────────────────────────
            if (tags.length > 1)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final tag = tags[i];
                    final isSelected = _selectedTag == tag;
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedTag = isSelected ? 'All' : tag,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _localizedTagLabel(tag),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: accent),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '${loc.errorOccurred}: ${snapshot.error}',
                        style: const TextStyle(fontSize: 17, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filteredDocs =
                      (widget.category == 'Story' ||
                          widget.category == 'Health')
                      ? docs.where((doc) {
                          final itemLang = doc.data()['language'];
                          return lang == 'ar'
                              ? itemLang == 'ar'
                              : itemLang != 'ar';
                        }).toList()
                      : docs;

                  final allItems = filteredDocs
                      .map((doc) => AudioItem.fromDoc(doc))
                      .toList();
                  final query = searchQuery.toLowerCase().trim();

                  final filteredItems = allItems.where((item) {
                    final title = _getTitle(item).toLowerCase();
                    final tag = item.tag.toLowerCase();
                    final matchesSearch =
                        query.isEmpty ||
                        title.contains(query) ||
                        tag.contains(query);
                    final matchesTag =
                        _selectedTag == 'All' || item.tag == _selectedTag;
                    return matchesSearch && matchesTag;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: accent.withOpacity(0.25),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            loc.noResultsFound,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: accent.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isFav = favoritesManager.isFavorite(item.id);
                      final title = _getTitle(item);

                      return _AudioCard(
                        item: item,
                        title: title,
                        isFavorite: isFav,
                        accent: accent,
                        accentBg: acBg,
                        onFavTap: () async {
                          await favoritesManager.toggleFavorite({
                            'audioId': item.id,
                            'title': item.title,
                            'titleAr': item.titleAr,
                            'category': item.category,
                            'image': item.imageAsset,
                            'fileName': item.fileName,
                            'tag': item.tag,
                            'type': item.type,
                            'url': item.url,
                          });
                          final nowFav = favoritesManager.isFavorite(item.id);
                          _showTopBanner(
                            nowFav
                                ? loc.addedToFavorites
                                : loc.removedFromFavorites,
                            color: nowFav
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                          );
                          if (mounted) setState(() {});
                        },
                        onTap: () {
                          if (item.type == 'youtube' &&
                              item.url != null &&
                              item.url!.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => YouTubePlayerPage(item: item),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AudioPlayerPage(item: item),
                              ),
                            );
                          }
                        },
                      );
                    },
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

// ── Audio card ────────────────────────────────────────────────────────────────
class _AudioCard extends StatelessWidget {
  final AudioItem item;
  final String title;
  final bool isFavorite;
  final Color accent;
  final Color accentBg;
  final VoidCallback onFavTap;
  final VoidCallback onTap;

  const _AudioCard({
    required this.item,
    required this.title,
    required this.isFavorite,
    required this.accent,
    required this.accentBg,
    required this.onFavTap,
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
              // Thumbnail — rounded square
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  item.imageAsset,
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

              // Title only — no category bubble
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Favourite button
              GestureDetector(
                onTap: onFavTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isFavorite
                        ? Colors.red.shade50
                        : const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline,
                    color: isFavorite
                        ? Colors.red.shade400
                        : Colors.grey.shade400,
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
