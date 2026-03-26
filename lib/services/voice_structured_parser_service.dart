import 'dart:convert';

import 'package:http/http.dart' as http;

class VoiceStructuredParserService {
  static final VoiceStructuredParserService _instance =
      VoiceStructuredParserService._internal();

  factory VoiceStructuredParserService() => _instance;
  VoiceStructuredParserService._internal();

  final Uri _chatUri = Uri.parse('https://api.openai.com/v1/chat/completions');

  Future<Map<String, dynamic>?> _postForJson({
    required String apiKey,
    required String systemPrompt,
    required String userText,
    required Map<String, dynamic> schema,
  }) async {
    if (apiKey.isEmpty) return null;

    try {
      final response = await http.post(
        _chatUri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'temperature': 0,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userText},
          ],
          'response_format': {
            'type': 'json_schema',
            'json_schema': {
              'name': 'voice_parse_schema',
              'strict': true,
              'schema': schema,
            },
          },
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Parser HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          decoded['choices']?[0]?['message']?['content']?.toString() ?? '';

      if (content.trim().isEmpty) return null;

      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Structured parser error: $e');
      return null;
    }
  }

  Future<List<String>?> parseDays(String userText, String apiKey) async {
    final schema = {
      'type': 'object',
      'properties': {
        'days': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum': [
              'Sunday',
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
            ],
          },
        },
      },
      'required': ['days'],
      'additionalProperties': false,
    };

    final systemPrompt = '''
You extract medication days from Arabic or English speech.
Return only normalized weekdays in English.

Rules:
- "كل يوم" or "every day" means all 7 days.
- Accept natural Arabic variants like:
  أحد, الاحد, الأحد
  اثنين, الاثنين, الإثنين
  ثلاثاء, الثلاثاء
  اربعاء, الأربعاء, الاربعاء
  خميس, الخميس
  جمعة, الجمعة
  سبت, السبت
- Return unique days only.
''';

    final json = await _postForJson(
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userText: userText,
      schema: schema,
    );

    final days = (json?['days'] as List?)?.map((e) => e.toString()).toList();
    if (days == null || days.isEmpty) return null;
    return days;
  }

  Future<String?> parseFrequency(String userText, String apiKey) async {
    final schema = {
      'type': 'object',
      'properties': {
        'frequency': {
          'type': 'string',
          'enum': [
            'Once a day',
            'Twice a day',
            'Three times a day',
            'Four times a day',
          ],
        },
      },
      'required': ['frequency'],
      'additionalProperties': false,
    };

    final systemPrompt = '''
You extract medication frequency from Arabic or English speech.
Map the answer to exactly one of:
- Once a day
- Twice a day
- Three times a day
- Four times a day

Examples:
- "مرة" => Once a day
- "مرة واحدة" => Once a day
- "مرتين" => Twice a day
- "ثلاث مرات" => Three times a day
- "أربع مرات" => Four times a day
- "once" => Once a day
- "twice" => Twice a day
''';

    final json = await _postForJson(
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userText: userText,
      schema: schema,
    );

    return json?['frequency']?.toString();
  }

  Future<Map<String, int>?> parseTime(String userText, String apiKey) async {
    final schema = {
      'type': 'object',
      'properties': {
        'hour': {'type': 'integer', 'minimum': 0, 'maximum': 23},
        'minute': {'type': 'integer', 'minimum': 0, 'maximum': 59},
      },
      'required': ['hour', 'minute'],
      'additionalProperties': false,
    };

    final systemPrompt = '''
You extract medication time from Arabic or English speech.
Return 24-hour time as hour and minute.

Examples:
- "ثلاث الصباح" => 3:00
- "الثالثة صباحًا" => 3:00
- "ثلاث العصر" => 15:00
- "سبعة ونص مساء" => 19:30
- "ثمانية وربع" => 8:15
- "8 am" => 8:00
- "9:30 pm" => 21:30
''';

    final json = await _postForJson(
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userText: userText,
      schema: schema,
    );

    final hour = json?['hour'];
    final minute = json?['minute'];

    if (hour is int && minute is int) {
      return {'hour': hour, 'minute': minute};
    }
    return null;
  }

  Future<Map<String, dynamic>?> parseDuration(
    String userText,
    String apiKey,
  ) async {
    final schema = {
      'type': 'object',
      'properties': {
        'mode': {
          'type': 'string',
          'enum': ['ongoing', 'days'],
        },
        'days': {
          'type': 'integer',
          'minimum': 0,
          'maximum': 3650,
        },
      },
      'required': ['mode', 'days'],
      'additionalProperties': false,
    };

    final systemPrompt = '''
You extract medication duration from Arabic or English speech.

Return:
- mode = "ongoing" and days = 0 if the medication is continuous / indefinite
- mode = "days" and a total number of days if it has an end

Convert phrases like:
- "مستمر" => ongoing
- "دائم" => ongoing
- "خمس ايام" => 5 days
- "أسبوع" => 7 days
- "أسبوعين" => 14 days
- "شهر" => 30 days
- "شهرين" => 60 days
- "سنة" => 365 days
- "سنتين" => 730 days
- "10 days" => 10 days
- "2 months" => 60 days

Approximation rules:
- 1 week = 7 days
- 1 month = 30 days
- 1 year = 365 days
''';

    final json = await _postForJson(
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userText: userText,
      schema: schema,
    );

    if (json == null) return null;
    return json;
  }
}