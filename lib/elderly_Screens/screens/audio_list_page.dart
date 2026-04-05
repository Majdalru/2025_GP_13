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

  static const kPrimary = Color(0xFF1B3A52);

  final Map<String, List<String>> _tagsPerCategory = {
    'Quran': ['All', 'maher-almuaiqly', 'saad-alghamdi', 'alminshawi'],
    'Story': ['All', 'islamic', 'world'],
    'Health': ['All', 'food', 'sleep', 'general'],
    'Caregiver': ['All'],
  };

  String _selectedTag = 'All';

  String _getTitle(AudioItem item) {
    final lang = Localizations.localeOf(context).languageCode;

    if (item.category == 'Quran') {
      if (lang == 'ar') {
        return item.titleAr?.isNotEmpty == true ? item.titleAr! : item.title;
      }
    }

    return item.title;
  }

  void _showTopBanner(
    String message, {
    Color color = kPrimary,
    int seconds = 5,
  }) {
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );

    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  String _localizedCategoryTitle(BuildContext context, String category) {
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

  String _localizedTagLabel(BuildContext context, String tag) {
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

    const cardColor = Colors.white;
    final loc = AppLocalizations.of(context)!;

     final lang = Localizations.localeOf(context).languageCode;

  final stream =    (widget.category == 'Story' || widget.category == 'Health') && lang == 'ar'
        ? FirebaseFirestore.instance
            .collection('audioMedia')
            .where('category', isEqualTo: widget.category)
            .where('language', isEqualTo:'ar')
            .snapshots()
        : FirebaseFirestore.instance
            .collection('audioMedia')
            .where('category', isEqualTo: widget.category)
            .snapshots();



    final tags = _tagsPerCategory[widget.category] ?? ['All'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: Text(_localizedCategoryTitle(context, widget.category)),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                style: const TextStyle(
                  fontSize: 22,
                  fontFamily: 'NotoSansArabic',
                ),
                decoration: InputDecoration(
                  hintText: loc.searchForAudio,
                  hintStyle: const TextStyle(fontSize: 22, color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 30,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: kPrimary, width: 2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  final isSelected = _selectedTag == tag;

                  return ChoiceChip(
                    label: Text(
                      _localizedTagLabel(context, tag),
                      style: const TextStyle(fontSize: 16),
                    ),
                    selected: isSelected,
                    selectedColor: kPrimary,
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedTag = selected ? tag : 'All';
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 4),

            Expanded(
              child: StreamBuilder(
                stream:stream,
                   
                builder: (context, snapshot) {
                    debugPrint('hasError = ${snapshot.hasError}');
debugPrint('error = ${snapshot.error}');
debugPrint('docs count = ${snapshot.data?.docs.length}');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      'Firestore error in AudioListPage: ${snapshot.error}',
                    );
                    return Center(
                      child: Text(
                        '${loc.errorOccurred}: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filteredDocs = (widget.category == 'Story' || widget.category == 'Health')
    ? docs.where((doc) {
        final data = doc.data();
        final itemLang = data['language'];

        if (lang == 'ar') {
          return itemLang == 'ar'; // عربي فقط
        } else {
          return itemLang != 'ar'; // إنجليزي فقط
        }
      }).toList()
    : docs;

final allItems = filteredDocs
    .map((doc) => AudioItem.fromDoc(doc))
    .toList();

                  final query = searchQuery.toLowerCase().trim();
                  final selectedTag = _selectedTag;

                  final filteredItems = allItems.where((item) {
                    final title = _getTitle(item).toLowerCase();
                    final tag = item.tag.toLowerCase();

                    final matchesSearch =
                        query.isEmpty ||
                        title.contains(query) ||
                        tag.contains(query);

                    final matchesTag =
                        selectedTag == 'All' || item.tag == selectedTag;

                    return matchesSearch && matchesTag;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Text(
                        loc.noResultsFound,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isFavorite = favoritesManager.isFavorite(item.id);

                      return Card(
                        color: cardColor,
                        elevation: 3,
                        shadowColor: kPrimary.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: kPrimary.withOpacity(0.8),
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: CircleAvatar(
                            radius: 35,
                            backgroundImage: AssetImage(item.imageAsset),
                          ),
                          title: Text(
                            _getTitle(item),
                            style: const TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: kPrimary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey,
                              size: 36,
                            ),
                            onPressed: () async {
                              await favoritesManager.toggleFavorite({
                                "audioId": item.id,
                                "title": item.title,
                                "titleAr": item.titleAr,
                                "category": item.category,
                                "image": item.imageAsset,
                                "fileName": item.fileName,
                                "tag": item.tag,
                                "type": item.type,
                                "url": item.url,
                              });

                              final nowFav = favoritesManager.isFavorite(item.id);

                              _showTopBanner(
                                nowFav
                                    ? loc.addedToFavorites
                                    : loc.removedFromFavorites,
                                color: nowFav
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                seconds: 1,
                              );

                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () {
                            if (item.type == 'youtube' &&
                                item.url != null &&
                                item.url!.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      YouTubePlayerPage(item: item),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AudioPlayerPage(item: item),
                                ),
                              );
                            }
                          },
                        ),
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