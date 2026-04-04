import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsService {
  static const String _apiKey = '';//PUT_YOUR_API_KEY_HERE
  static const String _baseUrl = 'https://gnews.io/api/v4/top-headlines';

  Future<List<Map<String, dynamic>>> getTopHeadlines({
    required String languageCode, // ar or en
    String? country, // صارت اختيارية
    int maxResults = 3,
    String category = 'health',
  }) async {
    final queryParams = {
      'lang': languageCode,
      'category': category,
      'max': maxResults.toString(),
      'apikey': _apiKey,
    };

    if (country != null && country.isNotEmpty) {
      queryParams['country'] = country;
    }

    final uri = Uri.https(
      'gnews.io',
      '/api/v4/top-headlines',
      queryParams,
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List articles = data['articles'] ?? [];

      return articles.map((item) {
        final source = item['source'] as Map<String, dynamic>?;

        return {
          'title': item['title'] ?? '',
          'description': item['description'] ?? '',
          'content': item['content'] ?? '',
          'url': item['url'] ?? '',
          'image': item['image'] ?? '',
          'publishedAt': item['publishedAt'] ?? '',
          'sourceName': source?['name'] ?? '',
        };
      }).toList();
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid API key or missing API key.');
    }

    if (response.statusCode == 403) {
      throw Exception('Daily quota exceeded.');
    }

    if (response.statusCode == 429) {
      throw Exception('Too many requests in a short time.');
    }

    throw Exception('Failed to load news: ${response.statusCode}');
  }
}