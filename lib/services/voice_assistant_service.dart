import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// تهيئة الخدمة
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // طلب إذن الميكروفون
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('⚠️ Microphone permission denied');
        return false;
      }

      // تهيئة Speech-to-Text
      final speechAvailable = await _speech.initialize(
        onStatus: (status) => debugPrint('🎤 Speech status: $status'),
        onError: (error) => debugPrint('❌ Speech error: $error'),
      );

      // تهيئة Text-to-Speech
      await _tts.setLanguage('en-US'); // يمكنك تغييرها لـ 'ar-SA' للعربي
      await _tts.setSpeechRate(0.5); // سرعة الكلام (0.5 = بطيء وواضح)
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _isInitialized = speechAvailable;
      debugPrint(_isInitialized 
          ? '✅ Voice Assistant initialized' 
          : '❌ Voice Assistant failed to initialize');
      
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Error initializing Voice Assistant: $e');
      return false;
    }
  }

  /// التحدث (Text-to-Speech)
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _isSpeaking = true;
      await _tts.speak(text);
      // انتظر حتى ينتهي الكلام
      await Future.delayed(Duration(milliseconds: text.length * 50));
      _isSpeaking = false;
    } catch (e) {
      debugPrint('❌ Error speaking: $e');
      _isSpeaking = false;
    }
  }

  /// إيقاف الكلام
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// الاستماع (Speech-to-Text)
  Future<String?> listen({
    Duration timeout = const Duration(seconds: 10),
    Function(String)? onResult,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    if (!await _speech.hasPermission) {
      debugPrint('⚠️ No microphone permission');
      return null;
    }

    String? finalResult;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            finalResult = result.recognizedWords;
            debugPrint('🎤 Final: $finalResult');
          } else {
            onResult?.call(result.recognizedWords);
            debugPrint('🎤 Partial: ${result.recognizedWords}');
          }
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      // انتظر حتى ينتهي الاستماع
      await Future.delayed(timeout);
      await _speech.stop();

      return finalResult;
    } catch (e) {
      debugPrint('❌ Error listening: $e');
      return null;
    }
  }

  /// إيقاف الاستماع
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// تحليل الأمر الصوتي
  VoiceCommand? analyzeCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    
    // أوامر الأدوية
    if (_containsAny(lowerText, ['medication', 'medicine', 'med', 'pill', 'drug', 'أدوية', 'دواء'])) {
      if (_containsAny(lowerText, ['add', 'new', 'أضف', 'جديد'])) {
        return VoiceCommand.addMedication;
      } else if (_containsAny(lowerText, ['edit', 'change', 'عدل', 'غير'])) {
        return VoiceCommand.editMedication;
      } else if (_containsAny(lowerText, ['delete', 'remove', 'احذف', 'امسح'])) {
        return VoiceCommand.deleteMedication;
      } else {
        return VoiceCommand.goToMedication;
      }
    }
    
    // أوامر الميديا
    if (_containsAny(lowerText, ['media', 'video', 'music', 'listen', 'watch', 'ميديا', 'فيديو', 'أسمع', 'أشوف'])) {
      return VoiceCommand.goToMedia;
    }
    
    // أوامر الطوارئ
    if (_containsAny(lowerText, ['sos', 'emergency', 'help', 'طوارئ', 'مساعدة'])) {
      return VoiceCommand.sos;
    }
    
    // أوامر العودة للرئيسية
    if (_containsAny(lowerText, ['home', 'main', 'back', 'رئيسية', 'رجوع'])) {
      return VoiceCommand.goToHome;
    }

    return null;
  }

  /// مساعد للتحقق من وجود أي كلمة من القائمة
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// الحصول على رسالة ترحيب
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning! How are you today?";
    } else if (hour < 17) {
      return "Good afternoon! How are you feeling?";
    } else {
      return "Good evening! How has your day been?";
    }
  }

  /// محادثة تفاعلية
  Future<void> startConversation({
    required BuildContext context,
    required Function(VoiceCommand) onCommand,
  }) async {
    // سؤال 1: الترحيب
    await speak(getGreeting());
    await Future.delayed(const Duration(seconds: 2));
    
    final response1 = await listen(timeout: const Duration(seconds: 8));
    if (response1 != null) {
      if (_containsAny(response1.toLowerCase(), ['good', 'fine', 'great', 'تمام', 'بخير'])) {
        await speak("That's wonderful to hear!");
      } else if (_containsAny(response1.toLowerCase(), ['bad', 'not good', 'tired', 'مو زين', 'تعبان'])) {
        await speak("I'm sorry to hear that. Is there anything I can help you with?");
      }
    }

    await Future.delayed(const Duration(seconds: 2));

    // سؤال 2: هل يحتاج مساعدة
    await speak("Would you like me to help you navigate the app?");
    await Future.delayed(const Duration(seconds: 2));
    
    final response2 = await listen(timeout: const Duration(seconds: 8));
    if (response2 != null) {
      final command = analyzeCommand(response2);
      if (command != null) {
        onCommand(command);
        return;
      }
      
      if (_containsAny(response2.toLowerCase(), ['yes', 'sure', 'please', 'نعم', 'أيوه', 'طيب'])) {
        await speak("Great! Where would you like to go? You can say medication, media, or home.");
        await Future.delayed(const Duration(seconds: 2));
        
        final response3 = await listen(timeout: const Duration(seconds: 10));
        if (response3 != null) {
          final command = analyzeCommand(response3);
          if (command != null) {
            onCommand(command);
            return;
          }
        }
      }
    }

    await speak("Alright! Just tap the voice button if you need help anytime.");
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  /// تنظيف الموارد
  Future<void> dispose() async {
    await _tts.stop();
    await _speech.stop();
  }
}

/// الأوامر الصوتية المتاحة
enum VoiceCommand {
  goToMedication,
  addMedication,
  editMedication,
  deleteMedication,
  goToMedia,
  goToHome,
  sos,
  goToSettings, // ← جديد
}