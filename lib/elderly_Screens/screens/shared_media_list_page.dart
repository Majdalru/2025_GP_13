import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/shared_item.dart';
import '../../services/sharing_service.dart';
import 'shared_audio_player_page.dart';
import 'video_player_page.dart';
import 'favorites_manager.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class SharedMediaListPage extends StatefulWidget {
  const SharedMediaListPage({super.key});

  @override
  State<SharedMediaListPage> createState() => _SharedMediaListPageState();
}

class _SharedMediaListPageState extends State<SharedMediaListPage> {
  final SharingService _sharingService = SharingService();
  static const kPrimary = Color(0xFF1B3A52);
  String _selectedFilter = 'All'; // All | Audio | Video

  @override
  void _showTopBanner(
    String message, {
    Color color = kPrimary,
    int seconds = 1,
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

  Widget _buildTypeFilterChips() {
    final options = [
      AppLocalizations.of(context)!.all,
      AppLocalizations.of(context)!.audio,
      AppLocalizations.of(context)!.video,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = options[index];
          final isSelected = _selectedFilter == opt;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A2340) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A2340)
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1A2340).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.pleaseLogInFirst),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 24,
                      color: Color(0xFF1A2340),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.familyMedia,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.familyMedia,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Filter chips ─────────────────────────────────────
            _buildTypeFilterChips(),
            const SizedBox(height: 6),

            // ── List ─────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<SharedItem>>(
                stream: _sharingService.getSharedItems(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.noMediaSharedYet,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredItems = items.where((it) {
                    if (_selectedFilter == 'All') return true;
                    if (_selectedFilter == 'Audio')
                      return it.type == SharedItemType.audio;
                    if (_selectedFilter == 'Video')
                      return it.type == SharedItemType.video;
                    return true;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.noMediaInThisFilter,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildSharedItemCard(
                        context,
                        filteredItems[index],
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

  Widget _buildSharedItemCard(BuildContext context, SharedItem item) {
    final isVideo = item.type == SharedItemType.video;
    const kPink = Color(0xFFE91E8C);
    const kPinkBg = Color(0xFFFCE4EC);
    const kAudioColor = Color(0xFF0077B6);
    const kAudioBg = Color(0xFFE3F2FD);

    final iconColor = isVideo ? kPink : kAudioColor;
    final iconBg = isVideo ? kPinkBg : kAudioBg;
    final icon = isVideo
        ? Icons.play_circle_outline_rounded
        : Icons.audiotrack_outlined;
    final typeLabel = isVideo
        ? AppLocalizations.of(context)!.video
        : AppLocalizations.of(context)!.audio;
    final formattedDate = DateFormat('MMM d, h:mm a').format(item.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _handleItemTap(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isNotEmpty ? item.title : typeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Favorite button
              IconButton(
                icon: Icon(
                  favoritesManager.isFavorite(item.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: favoritesManager.isFavorite(item.id)
                      ? Colors.red
                      : const Color(0xFF9CA3AF),
                  size: 26,
                ),
                onPressed: () async {
                  await favoritesManager.toggleFavorite({
                    "itemId": item.id,
                    "audioId": item.id,
                    "title": item.title,
                    "category": "Caregiver",
                    "fileName": item.fileName,
                    "image": isVideo ? "assets/video.jpg" : "assets/audio.jpg",
                    "type": isVideo ? "shared_video" : "shared_audio",
                    "url": item.url,
                  });
                  final nowFav = favoritesManager.isFavorite(item.id);
                  _showTopBanner(
                    nowFav
                        ? AppLocalizations.of(context)!.addedToFavorites
                        : AppLocalizations.of(context)!.removedFromFavorites,
                    color: nowFav ? Colors.green.shade700 : Colors.red.shade700,
                    seconds: 1,
                  );
                  if (mounted) setState(() {});
                },
              ),
              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE53935),
                  size: 24,
                ),
                onPressed: () => _confirmDelete(context, item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SharedItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteMediaTitle),
        content: Text(AppLocalizations.of(context)!.confirmDeleteSpecificMedia),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _sharingService.deleteItem(
                    elderlyId: user.uid,
                    item: item,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.mediaDeletedSuccessfully,
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.errorDeletingMedia(e.toString()),
                    ),
                  ),
                );
              }
            },
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _handleItemTap(BuildContext context, SharedItem item) {
    if (item.type == SharedItemType.video) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoPlayerPage(item: item)),
      );
    } else if (item.type == SharedItemType.audio) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SharedAudioPlayerPage(item: item)),
      );
    }
  }
}
