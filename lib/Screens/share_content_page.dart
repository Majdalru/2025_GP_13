import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/shared_item.dart';
import '../services/sharing_service.dart';

class ShareContentPage extends StatefulWidget {
  final String elderlyId;

  const ShareContentPage({super.key, required this.elderlyId});

  @override
  State<ShareContentPage> createState() => _ShareContentPageState();
}

class _ShareContentPageState extends State<ShareContentPage> {
  final SharingService _sharingService = SharingService();
  final Record _audioRecorder = Record();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _isUploading = false;
  bool _isRecording = false;


  @override
  void dispose() {
    _messageController.dispose();
    _titleController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Helper to show snackbar
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // 1. Share Video
  Future<void> _shareVideo() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickVideo(source: ImageSource.gallery);

    if (file == null) return;

    _showTitleDialog(
      type: 'Video',
      onConfirm: (title) async {
        setState(() => _isUploading = true);
        try {
          final File videoFile = File(file.path);
          final String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';

          final url = await _sharingService.uploadFile(
            file: videoFile,
            elderlyId: widget.elderlyId,
            fileName: fileName,
            type: SharedItemType.video,
          );

          if (url != null) {
            final item = SharedItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: SharedItemType.video,
              title: title,
              url: url,
              fileName: fileName,
              senderId: FirebaseAuth.instance.currentUser?.uid ?? 'caregiver',
              timestamp: DateTime.now(),
            );

            await _sharingService.shareItem(
              item: item,
              elderlyId: widget.elderlyId,
            );
            _showSnack('Video shared successfully!');
          } else {
            _showSnack('Failed to upload video', isError: true);
          }
        } catch (e) {
          _showSnack('Error sharing video: $e', isError: true);
        } finally {
          setState(() => _isUploading = false);
        }
      },
    );
  }

  // 2. Share Voice (Record or Pick)
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          path: path,
          encoder: AudioEncoder.aacLc,
        );
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      _showSnack('Error starting recording: $e', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        // _recordedPath = path; // Removed field, just pass it
      });
      if (path != null) {
        _confirmUploadVoice(path);
      }
    } catch (e) {
      _showSnack('Error stopping recording: $e', isError: true);
    }
  }

  void _confirmUploadVoice(String path) {
    _showTitleDialog(
      type: 'Voice Message',
      onConfirm: (title) async {
        setState(() => _isUploading = true);
        try {
          final File audioFile = File(path);
          final String fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';

          final url = await _sharingService.uploadFile(
            file: audioFile,
            elderlyId: widget.elderlyId,
            fileName: fileName,
            type: SharedItemType.audio,
          );

          if (url != null) {
            final item = SharedItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: SharedItemType.audio,
              title: title,
              url: url,
              fileName: fileName,
              senderId: FirebaseAuth.instance.currentUser?.uid ?? 'caregiver',
              timestamp: DateTime.now(),
            );

            await _sharingService.shareItem(
              item: item,
              elderlyId: widget.elderlyId,
            );
            _showSnack('Voice message shared successfully!');
          }
        } catch (e) {
          _showSnack('Error sharing voice: $e', isError: true);
        } finally {
          setState(() => _isUploading = false);
        }
      },
    );
  }
  


  void _showTitleDialog({
    required String type,
    required Function(String) onConfirm,
  }) {
    _titleController.text = '$type ${DateTime.now().hour}:${DateTime.now().minute}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Name this $type'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Enter title (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm(_titleController.text);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Light grey background
      appBar: AppBar(
        title: const Text(
          'Share with Elderly',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1B3A52),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'What would you like to share today?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose a media type below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 40),

                // Video Card
                _buildActionCard(
                  title: 'Share Video',
                  subtitle: 'Pick from Gallery',
                  icon: Icons.videocam_rounded,
                  color: Colors.orange.shade600,
                  onTap: _shareVideo,
                ),

                const SizedBox(height: 24),

                // Voice Card
                _buildActionCard(
                  title: _isRecording ? 'Recording...' : 'Voice Message',
                  subtitle: _isRecording
                      ? 'Tap to Stop'
                      : 'Tap to Record',
                  icon: _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isRecording ? Colors.red.shade600 : Colors.blue.shade600,
                  isRecording: _isRecording,
                  onTap: _isRecording ? _stopRecording : _startRecording,
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Uploading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isRecording = false,
  }) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Icon Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color,
                  ),
                ),
                const SizedBox(width: 24),
                
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isRecording ? Colors.red.shade700 : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow or status indicator
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade300,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
