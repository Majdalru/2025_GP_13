import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/shared_item.dart';
import '../../services/sharing_service.dart';
import 'shared_audio_player_page.dart';
import 'video_player_page.dart';
import 'favorites_manager.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

// ── Filter enum — never compare against localized strings ────────────────────
enum _Filter { all, audio, video, favorites }

class SharedMediaListPage extends StatefulWidget {
  const SharedMediaListPage({super.key});

  @override
  State<SharedMediaListPage> createState() => _SharedMediaListPageState();
}

class _SharedMediaListPageState extends State<SharedMediaListPage> {
  final SharingService _sharingService = SharingService();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _kNavy = Color(0xFF102E50);
  static const _kTeal = Color(0xFF4E949C);
  static const _kGold = Color(0xFFF5C35D);
  static const _kPink = Color(0xFFE91E8C);
  static const _kBlue = Color(0xFF0077B6);

  // ── Filter state ──────────────────────────────────────────────────────────
  _Filter _filter = _Filter.all;

  bool get _isFavoritesMode => _filter == _Filter.favorites;

  // ── Banner ────────────────────────────────────────────────────────────────
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

  // ── Filter chips — All / Audio / Video only ───────────────────────────────
  Widget _buildFilterChips(AppLocalizations loc) {
    final chips = [
      (_Filter.all, loc.all, Icons.apps_rounded),
      (_Filter.audio, loc.audio, Icons.audiotrack_outlined),
      (_Filter.video, loc.video, Icons.play_circle_outline_rounded),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (filterVal, label, icon) = chips[i];
          final isSelected = _filter == filterVal;

          return GestureDetector(
            onTap: () => setState(() => _filter = filterVal),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _kNavy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _kNavy : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _kNavy.withOpacity(0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.white : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: Text(loc.pleaseLogInFirst)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
              child: Row(
                children: [
                  // Back
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: Color(0xFF1A2340),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F2F5),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title
                  Row(
                    children: [
                      const Icon(
                        Icons.videocam_outlined,
                        color: _kTeal,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc.familyMedia,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Heart icon — toggles favorites view ─────────────
                  GestureDetector(
                    onTap: () => setState(() {
                      _filter = _isFavoritesMode
                          ? _Filter.all
                          : _Filter.favorites;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isFavoritesMode
                            ? Colors.red.shade50
                            : const Color(0xFFF0F2F5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFavoritesMode
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline,
                        color: _isFavoritesMode
                            ? Colors.red.shade400
                            : Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Filter chips (only shown when NOT in favorites mode) ──
            if (!_isFavoritesMode) ...[
              _buildFilterChips(loc),
              const SizedBox(height: 8),
            ] else ...[
              // Favorites header label
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      loc.favorites,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _filter = _Filter.all),
                      child: Text(
                        loc.all,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── List ─────────────────────────────────────────────────
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

                  final allItems = snapshot.data ?? [];

                  if (allItems.isEmpty) {
                    return _buildEmpty(
                      icon: Icons.videocam_off_outlined,
                      message: loc.noMediaSharedYet,
                    );
                  }

                  // ── Filter using enum — language-safe ──────────────
                  final filteredItems = allItems.where((it) {
                    switch (_filter) {
                      case _Filter.all:
                        return true;
                      case _Filter.audio:
                        return it.type == SharedItemType.audio;
                      case _Filter.video:
                        return it.type == SharedItemType.video;
                      case _Filter.favorites:
                        return favoritesManager.isFavorite(it.id);
                    }
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return _buildEmpty(
                      icon: _isFavoritesMode
                          ? Icons.favorite_border_rounded
                          : Icons.inbox_outlined,
                      message: _isFavoritesMode
                          ? loc.noResultsFound
                          : loc.noMediaInThisFilter,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) => _buildSharedItemCard(
                      context,
                      filteredItems[index],
                      // hide delete button when in favorites mode
                      showDelete: !_isFavoritesMode,
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

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────
  Widget _buildSharedItemCard(
    BuildContext context,
    SharedItem item, {
    required bool showDelete,
  }) {
    final loc = AppLocalizations.of(context)!;
    final isVideo = item.type == SharedItemType.video;
    final isFav = favoritesManager.isFavorite(item.id);

    const kPinkBg = Color(0xFFFCE4EC);
    const kAudioBg = Color(0xFFE3F2FD);

    final iconColor = isVideo ? _kPink : _kBlue;
    final iconBg = isVideo ? kPinkBg : kAudioBg;
    final icon = isVideo
        ? Icons.play_circle_outline_rounded
        : Icons.audiotrack_outlined;
    final typeLabel = isVideo ? loc.video : loc.audio;
    final formattedDate = DateFormat('MMM d, h:mm a').format(item.timestamp);

    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _handleItemTap(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              // Type icon badge
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
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

              // Favourite button
              GestureDetector(
                onTap: () async {
                  await favoritesManager.toggleFavorite({
                    'itemId': item.id,
                    'audioId': item.id,
                    'title': item.title,
                    'category': 'Caregiver',
                    'fileName': item.fileName,
                    'image': isVideo ? 'assets/video.jpg' : 'assets/audio.jpg',
                    'type': isVideo ? 'shared_video' : 'shared_audio',
                    'url': item.url,
                  });
                  final nowFav = favoritesManager.isFavorite(item.id);
                  _showTopBanner(
                    nowFav ? loc.addedToFavorites : loc.removedFromFavorites,
                    color: nowFav ? Colors.green.shade600 : Colors.red.shade600,
                  );
                  if (mounted) setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isFav ? Colors.red.shade50 : const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_outline,
                    color: isFav ? Colors.red.shade400 : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ),

              // Delete button — hidden in favorites mode
              if (showDelete) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _confirmDelete(context, item),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, SharedItem item) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(loc.deleteMediaTitle),
        content: Text(loc.confirmDeleteSpecificMedia),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel, style: const TextStyle(fontSize: 17)),
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.mediaDeletedSuccessfully)),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.errorDeletingMedia(e.toString())),
                    ),
                  );
                }
              }
            },
            child: Text(
              loc.delete,
              style: const TextStyle(color: Colors.red, fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
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
