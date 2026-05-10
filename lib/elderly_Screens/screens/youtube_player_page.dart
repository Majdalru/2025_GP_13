import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/audio_item.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

class YouTubePlayerPage extends StatefulWidget {
  final AudioItem item;
  const YouTubePlayerPage({Key? key, required this.item}) : super(key: key);

  @override
  State<YouTubePlayerPage> createState() => _YouTubePlayerPageState();
}

class _YouTubePlayerPageState extends State<YouTubePlayerPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final url = widget.item.url ?? '';
    final videoId = _extractYouTubeId(url);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (e) => debugPrint('Error: ${e.description}'),
      ));

    // نفتح m.youtube.com مباشرة بدل iframe
    if (videoId != null) {
      _controller.loadRequest(
        Uri.parse('https://m.youtube.com/watch?v=$videoId'),
      );
    } else if (url.isNotEmpty) {
      _controller.loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.item.url;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A52),
        iconTheme: const IconThemeData(color: Colors.white, size: 32),
        title: Text(
          widget.item.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: (url == null || url.isEmpty)
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noValidYoutubeUrl,
                style: const TextStyle(fontSize: 18),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }

  String? _extractYouTubeId(String url) {
    try {
      if (url.isEmpty) return null;
      if (url.contains('youtu.be/')) {
        final uri = Uri.parse(url);
        return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
      }
      final uri = Uri.parse(url);
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}