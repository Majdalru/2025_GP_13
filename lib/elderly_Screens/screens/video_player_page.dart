import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/shared_item.dart';

class VideoPlayerPage extends StatefulWidget {
  final SharedItem item;

  const VideoPlayerPage({super.key, required this.item});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.item.url == null) throw Exception("Video URL is null");

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url!),
      );

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error initializing video player: $e");
      if (mounted) {
           setState(() => _isLoading = false);
           ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error loading video: $e')),
           );
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.item.title),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : _chewieController != null &&
                      _chewieController!.videoPlayerController.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : const Text(
                      "Could not load video",
                      style: TextStyle(color: Colors.white),
                    ),
        ),
      ),
    );
  }
}
