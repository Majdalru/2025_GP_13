import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  final Record _record = Record();

  /// يسجل صوت ويحفظه كملف
  Future<File?> recordAudio({int seconds = 4}) async {
    try {
      final hasPerm = await _record.hasPermission();
      if (!hasPerm) {
        print('❌ No mic permission for record');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_input.m4a';

      await _record.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );

      print('🎙️ Recording for $seconds seconds...');
      await Future.delayed(Duration(seconds: seconds));

      final stopPath = await _record.stop();
      final filePath = stopPath ?? path;

      print('🎙️ Recording saved to: $filePath');
      return File(filePath);
    } catch (e) {
      print('❌ Recording error: $e');
      return null;
    }
  }

  /// يرسل الملف إلى OpenAI gpt-4o-transcribe ويترجم الصوت إلى نص
  Future<String?> transcribeAudio(File audioFile, String apiKey) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            audioFile.path,
            contentType: MediaType('audio', 'm4a'),
          ),
        )
        ..fields['model'] = 'gpt-4o-transcribe'
        ..fields['response_format'] = 'json';
      // لاحظ: ما حددنا language عشان الموديل يكتشف تلقائي

      print('📤 Sending audio to OpenAI...');

      final streamedResponse = await request.send();
      final body = await streamedResponse.stream.bytesToString();

      print('📥 Raw OpenAI response: $body');

      if (streamedResponse.statusCode != 200) {
        print('❌ OpenAI HTTP error: ${streamedResponse.statusCode}');
        return null;
      }

      final jsonRes = json.decode(body) as Map<String, dynamic>;
      return jsonRes['text'] as String?;
    } catch (e) {
      print('❌ Transcription error: $e');
      return null;
    }
  }
}
