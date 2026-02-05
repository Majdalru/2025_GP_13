import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/audio_item.dart';

class YouTubePlayerPage extends StatefulWidget {
  final AudioItem item;

  const YouTubePlayerPage({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  State<YouTubePlayerPage> createState() => _YouTubePlayerPageState();
}

class _YouTubePlayerPageState extends State<YouTubePlayerPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final url = widget.item.url ?? '';

    // نستخرج الـ videoId من الرابط (يدعم youtu.be و youtube.com)
    final videoId = _extractYouTubeId(url);

    // لو ما قدرنا نستخرج id، نرجع نفتح الرابط كما هو
    if (videoId == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..loadRequest(Uri.parse(url));
      return;
    }

    final html = '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body, html {
        margin: 0;
        padding: 0;
        background-color: #000000;;
        height: 100%;
        overflow: hidden;
      }
      .video-container {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
      }
      iframe {
        width: 100%;
        height: 100%;
        border: 0;
      }
    </style>
  </head>
  <body>
    <div class="video-container">
      <iframe
        src="https://www.youtube.com/embed/$videoId"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
      ></iframe>
    </div>
  </body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.item.url;

    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1B3A52), // نفس الأزرق المستخدم عندكم
  iconTheme: const IconThemeData(
    color: Colors.white, // لون سهم الرجوع
    size: 32,
  ),
  title: Text(
    widget.item.title,
    style: const TextStyle(
      color: Colors.white,      // لون العنوان
      fontSize: 26,
      fontWeight: FontWeight.bold,
    ),
  ),
  centerTitle: true,
),

      body: (url == null || url.isEmpty)
          ? const Center(
              child: Text(
                'No valid YouTube URL provided.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }

  /// دالة صغيرة تستخرج videoId من روابط يوتيوب المختلفة
  String? _extractYouTubeId(String url) {
    try {
      if (url.isEmpty) return null;

      // روابط قصيرة مثل youtu.be/xxxx
      if (url.contains('youtu.be/')) {
        final uri = Uri.parse(url);
        return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
      }

      // روابط عادية مثل youtube.com/watch?v=xxxx
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
