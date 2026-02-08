import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/shared_item.dart';
import '../../services/sharing_service.dart';
import 'shared_audio_player_page.dart';
import 'video_player_page.dart';

class SharedMediaListPage extends StatefulWidget {
  const SharedMediaListPage({super.key});

  @override
  State<SharedMediaListPage> createState() => _SharedMediaListPageState();
}

class _SharedMediaListPageState extends State<SharedMediaListPage> {
  final SharingService _sharingService = SharingService();
  static const kPrimary = Color(0xFF1B3A52);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Media')),
        body: const Center(child: Text('Please log in first.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: kPrimary,
        title: const Text("Family Media"),
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
              return const Center(
                child: Text(
                  'No media shared yet.',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildSharedItemCard(context, item);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSharedItemCard(BuildContext context, SharedItem item) {
    IconData icon;
    Color color;
    String typeLabel;

    switch (item.type) {
      case SharedItemType.video:
        icon = Icons.videocam;
        color = Colors.orange;
        typeLabel = 'Video';
        break;
      case SharedItemType.audio:
        icon = Icons.audiotrack;
        color = Colors.blue;
        typeLabel = 'Voice';
        break;

      default:
         icon = Icons.perm_media;
         color = Colors.grey;
         typeLabel = 'Media';    }

    final formattedDate =
        DateFormat('MMM d, h:mm a').format(item.timestamp);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleItemTap(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isNotEmpty ? item.title : typeLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),

                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _handleItemTap(BuildContext context, SharedItem item) {
    if (item.type == SharedItemType.video) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerPage(item: item),
          ),
        );
    } else if (item.type == SharedItemType.audio) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SharedAudioPlayerPage(item: item),
        ),
      );
    }
  }
}
