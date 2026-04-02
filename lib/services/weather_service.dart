import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String apiKey = ''; //Api for weatherApi

  Future<Map<String, dynamic>> getCurrentWeather({
    required double lat,
    required double lon,
    String lang = 'en',
  }) async {
    final url = Uri.parse(
      'https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$lat,$lon&lang=$lang',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load weather: ${response.statusCode}');
    }
  }
}