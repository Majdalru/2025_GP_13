import 'package:flutter/material.dart';
import 'audio_player_page.dart';
import 'youTube_player_page.dart';
import 'favorites_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/audio_item.dart';

class AudioListPage extends StatefulWidget {
  final String category;

  const AudioListPage({super.key, required this.category});

  @override
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage> {
  String searchQuery = '';

  static const kPrimary = Color(0xFF1B3A52);

  //  tags حسب كل كاتيجوري
  final Map<String, List<String>> _tagsPerCategory = {
    'Quran': [
      'All',
      'maher-almuaiqly',
      'saad-alghamdi',
      'alminshawi',
    ],
    'Story': [
      'All',
      'islamic',
      'world',
    ],
    'Health': [
      'All',
      'food',
      'sleep',
      'general',
    ],
    'Caregiver': [
      'All',
    ],
  };

  String _selectedTag = 'All';

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
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    const cardColor = Colors.white;

    //  التاقات المناسبة للكاتيجوري الحالي
    final tags = _tagsPerCategory[widget.category] ?? ['All'];

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: Text(widget.category),
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
            // ===== Search Bar =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                style: const TextStyle(
                  fontSize: 22,
                  fontFamily: 'NotoSansArabic',
                ),
                decoration: InputDecoration(
                  hintText: 'Search for audio...',
                  hintStyle: const TextStyle(fontSize: 22, color: Colors.grey),
                  prefixIcon:
                      const Icon(Icons.search, size: 30, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            //  Filter by Tag (Chips)
           //  Filter by Tag (Chips) — scroll أفقي أوضح
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

      // نسوي label  لليوزر
      String label = tag;
      if (tag == 'All') label = 'All';
      if (tag == 'maher-almuaiqly') label = 'Maher Al-Muaiqly';
      if (tag == 'saad-alghamdi') label = 'Saad Al-Ghamdi';
      if (tag == 'alminshawi') label = 'Al-Minshawi';

      if (tag == 'islamic') label = 'Islamic Stories';
      if (tag == 'world') label = 'World Stories';

      if (tag == 'food') label = 'Food';
      if (tag == 'sleep') label = 'Sleep';
      if (tag == 'general') label = 'General Health';

      return ChoiceChip(
        label: Text(
          label,
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

            // ===== List of Audio Cards =====
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('audioMedia')
                    .where('category', isEqualTo: widget.category)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                        ' Firestore error in AudioListPage: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // نحول الـ docs إلى List<AudioItem>
                  final allItems =
                      docs.map((doc) => AudioItem.fromDoc(doc)).toList();

                  final query = searchQuery.toLowerCase();
                  final selectedTag = _selectedTag;

                  //  فلترة بالبحث + التاق معاً
                  final filteredItems = allItems.where((item) {
                    final matchesSearch =
                        item.title.toLowerCase().contains(query);

                    final matchesTag =
                        selectedTag == 'All' || item.tag == selectedTag;

                    return matchesSearch && matchesTag;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return const Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(
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

                      //  نستخدم id بدل title
                      final isFavorite =
                          favoritesManager.isFavorite(item.id);

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
                            item.title,
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
                                "category": item.category,
                                "image": item.imageAsset,
                                "fileName": item.fileName,
                                "tag": item.tag, 
                                 "type": item.type,       // 👈 مهم
                                 "url": item.url,         // 👈 مهم لليوتيوب
                              });

                              final nowFav =
                                  favoritesManager.isFavorite(item.id);

                              _showTopBanner(
                                nowFav
                                    ? 'Added to Favorites successfully'
                                    : 'Removed from Favorites',
                                color: nowFav
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                seconds: 1,
                              );

                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () {
  // لو نوعه YouTube نروح لصفحة اليوتيوب
  if (item.type == 'youtube' && item.url != null && item.url!.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubePlayerPage(
          item: item,
        ),
      ),
    );
  } else {
    // أي شيء ثاني (أو ما فيه type) يفتح المشغّل الصوتي العادي
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioPlayerPage(
          item: item,
        ),
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
