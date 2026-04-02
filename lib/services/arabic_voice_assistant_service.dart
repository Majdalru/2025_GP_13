import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/voice_command.dart';
import '../models/medication.dart';
import 'medication_scheduler.dart';
import 'voice_structured_parser_service.dart';
import 'whisper_service.dart';

/// Google Cloud TTS API Key
const String _googleTtsApiKey = '';

/// OpenAI API Key for Whisper + intent classification + structured parsing
const String _openAIApiKey = '';

class ArabicVoiceAssistantService {
  static final ArabicVoiceAssistantService _instance =
      ArabicVoiceAssistantService._internal();

  factory ArabicVoiceAssistantService() => _instance;

  ArabicVoiceAssistantService._internal();

  final AudioPlayer _player = AudioPlayer();
  final VoiceStructuredParserService _structuredParser =
      VoiceStructuredParserService();

  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isInitialized => _isInitialized;

  void Function(bool isListening, bool isSpeaking)? _onListeningStateChange;

  void setOnListeningStateChange(
    void Function(bool isListening, bool isSpeaking)? callback,
  ) {
    _onListeningStateChange = callback;
  }

  void _notifyState({required bool listening, required bool speaking}) {
    final cb = _onListeningStateChange;
    if (cb != null) {
      cb(listening, speaking);
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('🎙️ لم يتم منح صلاحية الميكروفون');
      return false;
    }

    _isInitialized = true;
    debugPrint('✅ ArabicVoiceAssistantService initialized');
    return true;
  }

  String getGreeting() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    if (displayName.isNotEmpty) {
      return 'مرحبًا $displayName، كيف أقدر أساعدك؟';
    }
    return 'مرحبًا، كيف أقدر أساعدك اليوم؟';
  }

  // =========================
  // GOOGLE CLOUD TTS
  // =========================

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (_googleTtsApiKey.isEmpty) {
      debugPrint('❌ Google TTS API Key is empty');
      return;
    }

    debugPrint('🗣️ Arabic TTS: $text');

    _isSpeaking = true;
    _notifyState(listening: false, speaking: true);

    try {
      await _player.stop();

      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleTtsApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': 'ar-XA',
            'name': 'ar-XA-Wavenet-D',
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 0.85,
            'pitch': 0.0,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Google TTS HTTP ${response.statusCode}: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final audioContent = data['audioContent'] as String?;

      if (audioContent == null || audioContent.isEmpty) {
        debugPrint('❌ No audioContent returned from Google TTS');
        return;
      }

      final audioBytes = base64Decode(audioContent);
      await _player.play(BytesSource(audioBytes));
      await _player.onPlayerComplete.first;
    } catch (e) {
      debugPrint('❌ Arabic speak error: $e');
    } finally {
      _isSpeaking = false;
      _notifyState(listening: false, speaking: false);
    }
  }

  Future<void> stopSpeaking() async {
    await _player.stop();
    _isSpeaking = false;
    _notifyState(listening: false, speaking: false);
  }

  // =========================
  // BEEP
  // =========================

  Future<void> _playBeep() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/beep.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('❌ Beep error: $e');
    }
  }

  // =========================
  // LISTEN (Whisper)
  // =========================

  Future<String?> listenWhisper({int seconds = 6}) async {
    final ok = await initialize();
    if (!ok) return null;

    _notifyState(listening: true, speaking: false);

    await _playBeep();

    final whisper = WhisperService();
    final file = await whisper.recordAudio(seconds: seconds);

    if (file == null) {
      debugPrint('❌ No audio file recorded');
      _notifyState(listening: false, speaking: false);
      return null;
    }

    final text = await whisper.transcribeAudio(
      file,
      _openAIApiKey,
      arabic: true,
    );

    if (text == null || text.trim().isEmpty) {
      debugPrint('❌ Whisper returned empty text');
      _notifyState(listening: false, speaking: false);
      return null;
    }

    final cleaned = text.trim();
    debugPrint('🧠 Whisper text: "$cleaned"');

    _notifyState(listening: false, speaking: false);
    return cleaned;
  }

  // =========================
  // MAIN CHAT FLOW
  // =========================

  Future<void> startConversation({
    required BuildContext context,
    required void Function(VoiceCommand) onCommand,
  }) async {
    final ok = await initialize();
    if (!ok) return;

    await speak(getGreeting());

    final answer = await listenWhisper(seconds: 6);

    if (_isCancelUtterance(answer)) {
      await speak('حسنًا، سأتوقف الآن.');
      return;
    }

    if (answer == null || answer.trim().isEmpty) {
      await speak('عذرًا، لم أسمع شيئًا. يمكنك المحاولة مرة أخرى لاحقًا.');
      return;
    }

    final command = await analyzeSmartCommand(answer);
    if (command != null) {
      onCommand(command);
    } else {
      await speak(
        'عذرًا، لم أفهم طلبك. يمكنك السؤال عن الطقس او قول  الأدوية أو الوسائط أو الصفحة الرئيسية أو الطوارئ.',
      );
    }
  }

  // =========================
  // SMART INTENT
  // =========================

  Future<VoiceCommand?> analyzeSmartCommand(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;

    VoiceCommand? fromChat;

    if (_openAIApiKey.isNotEmpty) {
      fromChat = await _analyzeWithChatGPT(cleaned);
      if (fromChat != null) {
        return fromChat;
      }
    }

    return analyzeCommandLocally(cleaned);
  }

  Future<VoiceCommand?> _analyzeWithChatGPT(String text) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_openAIApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'temperature': 0,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an intent classifier for an elderly medication app. '
                  'The user may speak Arabic or English. '
                  'Valid intents are: goToMedication, addMedication, editMedication, deleteMedication, '
                  'goToMedia, goToHome, sos, goToSettings, none. '
                  'Respond ONLY with pure JSON like {"intent":"addMedication"}.',
            },
            {'role': 'user', 'content': text},
          ],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ ChatGPT HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          (decoded['choices'][0]['message']['content'] as String).trim();

      Map<String, dynamic>? jsonIntent;

      try {
        jsonIntent = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        final start = content.indexOf('{');
        final end = content.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          final sub = content.substring(start, end + 1);
          jsonIntent = jsonDecode(sub) as Map<String, dynamic>;
        }
      }

      if (jsonIntent == null) return null;

      final intentString = (jsonIntent['intent'] ?? '').toString();
      return _intentFromString(intentString);
    } catch (e) {
      debugPrint('❌ ChatGPT intent error: $e');
      return null;
    }
  }

  VoiceCommand? _intentFromString(String raw) {
    final lower = raw.trim().toLowerCase();

    switch (lower) {
      case 'gotomedication':
      case 'gotomed':
      case 'med':
      case 'medication':
        return VoiceCommand.goToMedication;

      
      case 'weather':
      case 'getweather':
      case 'weathertoday':
        return VoiceCommand.weather;

      case 'addmedication':
      case 'add_medication':
      case 'add':
        return VoiceCommand.addMedication;

      case 'editmedication':
      case 'edit_medication':
      case 'edit':
        return VoiceCommand.editMedication;

      case 'deletemedication':
      case 'delete_medication':
      case 'delete':
        return VoiceCommand.deleteMedication;

      case 'gotomedia':
      case 'media':
        return VoiceCommand.goToMedia;

      case 'gotohome':
      case 'home':
        return VoiceCommand.goToHome;

      case 'sos':
      case 'emergency':
        return VoiceCommand.sos;

      case 'gotosettings':
      case 'settings':
        return VoiceCommand.goToSettings;

      default:
        return null;
    }
  }

  // =========================
  // LOCAL COMMAND ANALYZER
  // =========================

  VoiceCommand? analyzeCommandLocally(String text) {
    final lower = _normalizeArabic(text.toLowerCase());

    if (_containsAny(lower, [
      'sos',
      'emergency',
      'help me',
      'call help',
      'استغاثه',
      'استغاثة',
      'طوارئ',
      'ساعد',
      'نجده',
      'نجدة',
    ])) {
      return VoiceCommand.sos;
    }

    if (_containsAny(lower, [
      'media',
      'audio',
      'song',
      'video',
      'وسايط',
      'وسائط',
      'ميديا',
      'صوت',
      'فيديو',
      'قران',
      'قرآن',
      'سوره',
      'سورة',
    ])) {
      return VoiceCommand.goToMedia;
    }

    if (_containsAny(lower, [
      'medication',
      'medications',
      'medicine',
      'med',
      'pill',
      'دواء',
      'الادويه',
      'الأدوية',
      'ادوية',
      'أدوية',
      'دوائي',
      'الدواء',
    ])) {
      return VoiceCommand.goToMedication;
    }

    if (_containsAny(lower, [
      'home',
      'main page',
      'الصفحه الرئيسيه',
      'الصفحة الرئيسية',
      'الرئيسيه',
      'الرئيسية',
      'البيت',
      'هوم',
    ])) {
      return VoiceCommand.goToHome;
    }

    if (_containsAny(lower, [
      'settings',
      'اعدادات',
      'إعدادات',
      'الاعدادات',
      'الإعدادات',
    ])) {
      return VoiceCommand.goToSettings;
    }

    if (_containsAny(lower, [
      'add medicine',
      'add medication',
      'new medicine',
      'اضف دواء',
      'أضف دواء',
      'دواء جديد',
      'اضافة دواء',
      'إضافة دواء',
      'ابي اضيف دواء',
      'أبي أضيف دواء',
      'ابغى اضيف دواء',
    ])) {
      return VoiceCommand.addMedication;
    }

    if (_containsAny(lower, [
      'delete medicine',
      'remove medicine',
      'حذف دواء',
      'احذف الدواء',
      'شيل الدواء',
      'امسح الدواء',
    ])) {
      return VoiceCommand.deleteMedication;
    }

    if (_containsAny(lower, [
      'edit medicine',
      'change medicine',
      'تعديل دواء',
      'غير الدواء',
      'عدل الدواء',
      'عدّل الدواء',
      'ابغى اعدل الدواء',
    ])) {
      return VoiceCommand.editMedication;
    }

    if (_containsAny(lower, [
      'الطقس',
      'جو',
      'الجو',
      'درجه الحراره',
      'درجة الحرارة',
      'حراره',
      'حرارة',
      'كيف الطقس',
      'كيف الجو',
      'وش الجو',
      'وش الطقس',
      'ايش الطقس',
    ])) {
      return VoiceCommand.weather;
    }

    return null;
  }

  bool _containsAny(String text, List<String> patterns) {
    for (final p in patterns) {
      if (text.contains(_normalizeArabic(p.toLowerCase()))) {
        return true;
      }
    }
    return false;
  }

  String _normalizeArabic(String input) {
    final diacritics = RegExp(
      r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
    );
    return input
        .replaceAll(diacritics, '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  // =========================
  // MEDICATION FLOWS
  // =========================

  Future<void> runAddMedicationFlow(String elderlyId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await speak('يجب تسجيل الدخول أولًا لإضافة دواء.');
      return;
    }

    final ok = await initialize();
    if (!ok) return;

    await speak('حسنًا، لنضيف دواءً جديدًا. سأطرح عليك بعض الأسئلة.');

    final name = await _askQuestion(
      'ما اسم الدواء؟ يمكنك قوله بالعربية أو الإنجليزية.',
      listenSeconds: 6,
    );

    if (_isCancelUtterance(name)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    if (name == null || name.isEmpty) {
      await speak('لم أتمكن من سماع اسم الدواء. سنتوقف الآن.');
      return;
    }

    final confirmName = await _askQuestion(
      'قلت $name. هل هذا صحيح؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (_isCancelUtterance(confirmName)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    if (_isNo(confirmName)) {
      await speak('حسنًا، تم إلغاء إضافة الدواء.');
      return;
    }

    final daysAnswer = await _askQuestion(
      'في أي أيام تأخذ هذا الدواء؟ يمكنك قول كل يوم، أو ذكر أيام محددة مثل الأحد والثلاثاء والخميس.',
      listenSeconds: 7,
    );

    if (_isCancelUtterance(daysAnswer)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    final parsedDays =
        await _structuredParser.parseDays(daysAnswer ?? '', _openAIApiKey);
    final days = parsedDays ??
        const [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ];

    final freqAnswer = await _askQuestion(
      'كم مرة في اليوم تأخذ هذا الدواء؟ قل مرة واحدة، مرتين، ثلاث مرات، أو أربع مرات.',
      listenSeconds: 6,
    );

    if (_isCancelUtterance(freqAnswer)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    final frequency = await _structuredParser.parseFrequency(
      freqAnswer ?? '',
      _openAIApiKey,
    );
    final finalFrequency = frequency ?? 'Once a day';

    final timeAnswer = await _askQuestion(
      'في أي وقت تأخذ الجرعة الأولى؟ مثلًا الساعة 8 صباحًا أو 9:30 مساءً.',
      listenSeconds: 7,
    );

    if (_isCancelUtterance(timeAnswer)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    TimeOfDay firstTime;
    if (timeAnswer == null || timeAnswer.isEmpty) {
      firstTime = _fallbackTime();
    } else {
      final parsedTime = await _structuredParser.parseTime(
        timeAnswer,
        _openAIApiKey,
      );
      if (parsedTime != null) {
        firstTime = TimeOfDay(
          hour: parsedTime['hour']!,
          minute: parsedTime['minute']!,
        );
      } else {
        firstTime = _fallbackTime();
      }
    }

    final times = expandTimesForFrequency(firstTime, finalFrequency);

    final durationAnswer = await _askQuestion(
      'هل هذا الدواء مستمر، أم له مدة محددة؟ يمكنك قول مستمر، أو خمسة أيام، أو شهرين، أو سنة.',
      listenSeconds: 7,
    );

    if (_isCancelUtterance(durationAnswer)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    Timestamp? endDate;
    if (durationAnswer != null && durationAnswer.trim().isNotEmpty) {
      final parsedDuration = await _structuredParser.parseDuration(
        durationAnswer,
        _openAIApiKey,
      );

      if (parsedDuration != null) {
        final mode = parsedDuration['mode']?.toString();
        final daysCount = (parsedDuration['days'] as num?)?.toInt() ?? 0;

        if (mode == 'days' && daysCount > 0) {
          final end = DateTime.now().add(Duration(days: daysCount));
          endDate = Timestamp.fromDate(end);
        } else {
          endDate = null;
        }
      }
    }

    final notesAnswer = await _askQuestion(
      'هل تريد إضافة ملاحظات؟ مثل قبل الأكل أو بعد الأكل. إذا لا، قل لا.',
      listenSeconds: 6,
    );

    if (_isCancelUtterance(notesAnswer)) {
      await speak('حسنًا، سنتوقف عن إضافة الدواء.');
      return;
    }

    final notes = (notesAnswer != null &&
            !_isNo(notesAnswer) &&
            notesAnswer.trim().isNotEmpty)
        ? notesAnswer
        : null;

    final newMed = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      days: days,
      frequency: finalFrequency,
      times: times,
      notes: notes,
      addedBy: currentUser.uid,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      endDate: endDate,
    );

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(elderlyId);

    try {
      await docRef.set({
        'medsList': FieldValue.arrayUnion([newMed.toMap()]),
      }, SetOptions(merge: true));

      await speak('تمت إضافة $name إلى قائمة الأدوية.');
      await MedicationScheduler().scheduleAllMedications(elderlyId);
    } catch (e) {
      debugPrint('❌ Error saving medication by voice: $e');
      await speak('عذرًا، حدث خطأ أثناء حفظ الدواء.');
    }
  }

  Future<void> runDeleteMedicationFlow(String elderlyId) async {
    final ok = await initialize();
    if (!ok) return;

    final meds = await _loadMedications(elderlyId);
    if (meds.isEmpty) {
      await speak('لا يوجد لديك أدوية محفوظة حاليًا.');
      return;
    }

    final namesText = meds.map((m) => m.name).join('، ');
    await speak('الأدوية الحالية هي: $namesText. ما الدواء الذي تريد حذفه؟');

    Medication? target;
    const maxTries = 3;

    for (int attempt = 1; attempt <= maxTries; attempt++) {
      final answer = await listenWhisper(seconds: 6);

      if (_isCancelUtterance(answer)) {
        await speak('حسنًا، سنتوقف عن الحذف الآن.');
        return;
      }

      if (answer == null || answer.trim().isEmpty) {
        if (attempt < maxTries) {
          await speak('لم أسمع اسم الدواء. من فضلك قل اسم الدواء بوضوح.');
          continue;
        } else {
          await speak('لم أتمكن من سماع الاسم. تم إلغاء الحذف.');
          return;
        }
      }

      target = _selectMedicationFromUtterance(answer, meds);

      if (target != null) break;

      if (attempt < maxTries) {
        await speak('لم أتمكن من مطابقة الاسم مع أي دواء. حاول مرة أخرى.');
      } else {
        await speak('لم أجد دواءً مطابقًا. تم إلغاء الحذف.');
        return;
      }
    }

    if (target == null) return;

    final confirm = await _askQuestion(
      'هل تريد حذف ${target.name}؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('حسنًا، سنتوقف عن الحذف الآن.');
      return;
    }

    if (!_isYes(confirm)) {
      await speak('حسنًا، لن أحذف الدواء.');
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(elderlyId);

    try {
      await docRef.update({
        'medsList': FieldValue.arrayRemove([target.toMap()]),
      });

      await speak('تم حذف الدواء ${target.name}.');
      await MedicationScheduler().scheduleAllMedications(elderlyId);
    } catch (e) {
      debugPrint('❌ Error deleting medication: $e');
      await speak('عذرًا، لم أتمكن من حذف الدواء بسبب خطأ.');
    }
  }

  Future<void> runEditMedicationFlow(String elderlyId) async {
    final ok = await initialize();
    if (!ok) return;

    final meds = await _loadMedications(elderlyId);
    if (meds.isEmpty) {
      await speak('لا يوجد لديك أدوية لتعديلها.');
      return;
    }

    await speak('ما الدواء الذي تريد تعديله؟');
    final namesText = meds.map((m) => m.name).join('، ');
    await speak('الأدوية الموجودة هي: $namesText');

    Medication? targetMed;
    const maxTries = 3;

    for (int attempt = 1; attempt <= maxTries; attempt++) {
      final answer = await listenWhisper(seconds: 6);

      if (_isCancelUtterance(answer)) {
        await speak('حسنًا، سنتوقف عن التعديل الآن.');
        return;
      }

      if (answer == null || answer.trim().isEmpty) {
        if (attempt < maxTries) {
          await speak('لم أسمع اسم الدواء. من فضلك قل الاسم بوضوح.');
          continue;
        } else {
          await speak('تم إلغاء التعديل.');
          return;
        }
      }

      targetMed = _selectMedicationFromUtterance(answer, meds);
      if (targetMed != null) break;

      if (attempt < maxTries) {
        await speak('لم أتعرف على اسم الدواء. حاول مرة أخرى.');
      } else {
        await speak('تم إلغاء التعديل.');
        return;
      }
    }

    if (targetMed == null) return;

    final confirm = await _askQuestion(
      'هل تريد تعديل ${targetMed.name}؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('حسنًا، سنتوقف عن التعديل.');
      return;
    }

    if (!_isYes(confirm)) {
      await speak('حسنًا، لن يتم تعديل الدواء.');
      return;
    }

    Medication currentMed = targetMed;
    bool continueEditing = true;

    while (continueEditing) {
      await speak(
        'ماذا تريد أن تعدل؟ يمكنك قول الاسم، الأيام، عدد المرات، الأوقات، الملاحظات، أو المدة.',
      );

      String? fieldToEdit;

      for (int attempt = 1; attempt <= 2; attempt++) {
        final fieldAnswer = await listenWhisper(seconds: 6);

        if (_isCancelUtterance(fieldAnswer)) {
          await speak('حسنًا، سنتوقف عن التعديل.');
          return;
        }

        if (fieldAnswer == null || fieldAnswer.isEmpty) {
          if (attempt < 2) {
            await speak(
              'من فضلك قل: الاسم أو الأيام أو عدد المرات أو الأوقات أو الملاحظات أو المدة.',
            );
            continue;
          } else {
            await speak('سنتوقف عن التعديل الآن.');
            continueEditing = false;
            break;
          }
        }

        fieldToEdit = _parseEditField(fieldAnswer);
        if (fieldToEdit != null) break;

        if (attempt < 2) {
          await speak(
            'لم أفهم المطلوب. قل الاسم أو الأيام أو عدد المرات أو الأوقات أو الملاحظات أو المدة.',
          );
        }
      }

      if (fieldToEdit == null) {
        continueEditing = false;
        break;
      }

      final updatedMed = await _editFieldByVoice(currentMed, fieldToEdit);

      if (updatedMed == null) {
        await speak('لم يتم تعديل هذا الحقل.');
      } else {
        currentMed = updatedMed;
        await speak('تم تعديل الحقل بنجاح.');
      }

      final continueAnswer = await _askQuestion(
        'هل تريد تعديل شيء آخر؟ قل نعم أو لا.',
        listenSeconds: 4,
      );

      if (_isCancelUtterance(continueAnswer)) {
        await speak('حسنًا، سنتوقف الآن.');
        continueEditing = false;
      } else if (!_isYes(continueAnswer)) {
        continueEditing = false;
      }
    }

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(elderlyId);

    try {
      final doc = await docRef.get();
      final List<dynamic> currentMedsList = doc.data()?['medsList'] ?? [];

      final List<Map<String, dynamic>> updatedMedsList = currentMedsList.map((
        med,
      ) {
        if (med['id'] == currentMed.id) {
          return currentMed.toMap();
        }
        return Map<String, dynamic>.from(med);
      }).toList();

      await docRef.update({'medsList': updatedMedsList});

      await speak('تم حفظ التعديلات على ${targetMed.name}.');
      await MedicationScheduler().scheduleAllMedications(elderlyId);
    } catch (e) {
      debugPrint('❌ Error saving edited medication: $e');
      await speak('عذرًا، لم أتمكن من حفظ التعديلات.');
    }
  }

  // =========================
  // EDIT HELPERS
  // =========================

  String? _parseEditField(String utterance) {
    final lower = _normalizeArabic(utterance.toLowerCase().trim());

    if (_containsAny(lower, ['name', 'الاسم', 'اسم', 'اسم الدواء'])) {
      return 'name';
    }
    if (_containsAny(lower, ['day', 'days', 'الايام', 'الأيام', 'يوم'])) {
      return 'days';
    }
    if (_containsAny(lower, [
      'frequency',
      'مرات',
      'عدد المرات',
      'كم مره',
      'كم مرة',
    ])) {
      return 'frequency';
    }
    if (_containsAny(lower, [
      'time',
      'times',
      'وقت',
      'الاوقات',
      'الأوقات',
      'ساعه',
      'ساعة',
    ])) {
      return 'times';
    }
    if (_containsAny(lower, ['note', 'notes', 'ملاحظات', 'تعليمات'])) {
      return 'notes';
    }
    if (_containsAny(lower, [
      'duration',
      'المده',
      'المدة',
      'مدة',
      'ينتهي',
      'مستمر',
    ])) {
      return 'duration';
    }

    return null;
  }

  Future<Medication?> _editFieldByVoice(
    Medication original,
    String field,
  ) async {
    switch (field) {
      case 'name':
        return await _editName(original);
      case 'days':
        return await _editDays(original);
      case 'frequency':
        return await _editFrequency(original);
      case 'times':
        return await _editTimes(original);
      case 'notes':
        return await _editNotes(original);
      case 'duration':
        return await _editDuration(original);
      default:
        return null;
    }
  }

  Future<Medication?> _editName(Medication original) async {
    await speak('ما الاسم الجديد للدواء؟');

    final newName = await listenWhisper(seconds: 6);

    if (_isCancelUtterance(newName)) {
      await speak('حسنًا، سنحتفظ بالاسم الحالي.');
      return null;
    }

    if (newName == null || newName.trim().isEmpty) {
      await speak('لم أسمع الاسم الجديد.');
      return null;
    }

    final confirm = await _askQuestion(
      'هل تريد تغيير الاسم إلى $newName؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (!_isYes(confirm)) {
      await speak('حسنًا، سنحتفظ بالاسم الحالي.');
      return null;
    }

    return Medication(
      id: original.id,
      name: newName.trim(),
      days: original.days,
      frequency: original.frequency,
      times: original.times,
      notes: original.notes,
      addedBy: original.addedBy,
      createdAt: original.createdAt,
      updatedAt: Timestamp.now(),
      endDate: original.endDate,
    );
  }

  Future<Medication?> _editDays(Medication original) async {
    await speak('ما الأيام الجديدة؟ يمكنك قول كل يوم أو ذكر أيام محددة.');

    final daysAnswer = await listenWhisper(seconds: 7);

    if (_isCancelUtterance(daysAnswer)) {
      await speak('حسنًا، سنحتفظ بالأيام الحالية.');
      return null;
    }

    if (daysAnswer == null || daysAnswer.isEmpty) {
      await speak('لم أسمع الأيام.');
      return null;
    }

    final parsedDays =
        await _structuredParser.parseDays(daysAnswer, _openAIApiKey);
    final newDays = parsedDays ?? original.days;
    final daysText = newDays.join('، ');

    final confirm = await _askQuestion(
      'هل تريد ضبط الأيام على: $daysText؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (!_isYes(confirm)) {
      await speak('حسنًا، سنحتفظ بالأيام الحالية.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      days: newDays,
      frequency: original.frequency,
      times: original.times,
      notes: original.notes,
      addedBy: original.addedBy,
      createdAt: original.createdAt,
      updatedAt: Timestamp.now(),
      endDate: original.endDate,
    );
  }

  Future<Medication?> _editFrequency(Medication original) async {
    await speak('كم مرة في اليوم تريد أخذ هذا الدواء؟');

    final freqAnswer = await listenWhisper(seconds: 6);

    if (_isCancelUtterance(freqAnswer)) {
      await speak('حسنًا، سنحتفظ بعدد المرات الحالي.');
      return null;
    }

    if (freqAnswer == null || freqAnswer.isEmpty) {
      await speak('لم أسمع عدد المرات.');
      return null;
    }

    final newFrequency =
        await _structuredParser.parseFrequency(freqAnswer, _openAIApiKey) ??
            original.frequency ??
            'Once a day';

    final confirm = await _askQuestion(
      'هل تريد تغيير عدد المرات إلى $newFrequency؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (!_isYes(confirm)) {
      await speak('حسنًا، سنحتفظ بعدد المرات الحالي.');
      return null;
    }

    final firstTime = original.times.isNotEmpty
        ? original.times.first
        : const TimeOfDay(hour: 8, minute: 0);

    final newTimes = expandTimesForFrequency(firstTime, newFrequency);

    return Medication(
      id: original.id,
      name: original.name,
      days: original.days,
      frequency: newFrequency,
      times: newTimes,
      notes: original.notes,
      addedBy: original.addedBy,
      createdAt: original.createdAt,
      updatedAt: Timestamp.now(),
      endDate: original.endDate,
    );
  }

  Future<Medication?> _editTimes(Medication original) async {
    await speak('ما وقت الجرعة الأولى الجديد؟');

    final timeAnswer = await listenWhisper(seconds: 7);

    if (_isCancelUtterance(timeAnswer)) {
      await speak('حسنًا، سنحتفظ بالأوقات الحالية.');
      return null;
    }

    if (timeAnswer == null || timeAnswer.isEmpty) {
      await speak('لم أسمع الوقت.');
      return null;
    }

    final parsedTime = await _structuredParser.parseTime(
      timeAnswer,
      _openAIApiKey,
    );
    if (parsedTime == null) {
      await speak('لم أتمكن من فهم الوقت الجديد.');
      return null;
    }

    final newFirstTime = TimeOfDay(
      hour: parsedTime['hour']!,
      minute: parsedTime['minute']!,
    );

    final frequency = original.frequency ?? 'Once a day';
    final newTimes = expandTimesForFrequency(newFirstTime, frequency);

    final timesText = newTimes
        .map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}')
        .join('، ');

    final confirm = await _askQuestion(
      'هل تريد ضبط الأوقات على: $timesText؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (!_isYes(confirm)) {
      await speak('حسنًا، سنحتفظ بالأوقات الحالية.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      days: original.days,
      frequency: original.frequency,
      times: newTimes,
      notes: original.notes,
      addedBy: original.addedBy,
      createdAt: original.createdAt,
      updatedAt: Timestamp.now(),
      endDate: original.endDate,
    );
  }

  Future<Medication?> _editNotes(Medication original) async {
    await speak('ما الملاحظات الجديدة؟ يمكنك أيضًا قول لا لإزالة الملاحظات.');

    final notesAnswer = await listenWhisper(seconds: 6);

    if (_isCancelUtterance(notesAnswer)) {
      await speak('حسنًا، سنحتفظ بالملاحظات الحالية.');
      return null;
    }

    String? newNotes;
    if (notesAnswer == null || notesAnswer.isEmpty || _isNo(notesAnswer)) {
      newNotes = null;
    } else {
      newNotes = notesAnswer.trim();
    }

    final confirm = await _askQuestion(
      newNotes != null
          ? 'هل تريد ضبط الملاحظات على: $newNotes؟ قل نعم أو لا.'
          : 'هل تريد إزالة جميع الملاحظات؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (!_isYes(confirm)) {
      await speak('حسنًا، سنحتفظ بالملاحظات الحالية.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      days: original.days,
      frequency: original.frequency,
      times: original.times,
      notes: newNotes,
      addedBy: original.addedBy,
      createdAt: original.createdAt,
      updatedAt: Timestamp.now(),
      endDate: original.endDate,
    );
  }

  Future<Medication?> _editDuration(Medication original) async {
    await speak(
      'هل هذا الدواء مستمر، أم له مدة محددة؟ يمكنك قول مستمر، أو خمسة أيام، أو شهرين، أو سنة.',
    );

    final durationAnswer = await listenWhisper(seconds: 7);

    if (_isCancelUtterance(durationAnswer)) {
      await speak('حسنًا، سنحتفظ بالمدة الحالية.');
      return null;
    }

    if (durationAnswer == null || durationAnswer.trim().isEmpty) {
      await speak('لم أسمع المدة الجديدة.');
      return null;
    }

    final parsedDuration = await _structuredParser.parseDuration(
      durationAnswer,
      _openAIApiKey,
    );
    if (parsedDuration == null) {
      await speak('لم أتمكن من فهم المدة الجديدة.');
      return null;
    }

    final mode = parsedDuration['mode']?.toString();
    final daysCount = (parsedDuration['days'] as num?)?.toInt() ?? 0;

    Timestamp? newEndDate;
    String readableDuration;

    if (mode == 'ongoing') {
      newEndDate = null;
      readableDuration = 'مستمر';
    } else {
      final end = DateTime.now().add(Duration(days: daysCount));
      newEndDate = Timestamp.fromDate(end);
      readableDuration = '$daysCount يوم';
    }

    final confirm = await _askQuestion(
      'هل تريد ضبط مدة الدواء إلى $readableDuration؟ قل نعم أو لا.',
      listenSeconds: 4,
    );

    if (!_isYes(confirm)) {
      await speak('حسنًا، سنحتفظ بالمدة الحالية.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      days: original.days,
      frequency: original.frequency,
      times: original.times,
      notes: original.notes,
      addedBy: original.addedBy,
      createdAt: original.createdAt,
      updatedAt: Timestamp.now(),
      endDate: newEndDate,
    );
  }

  // =========================
  // MED HELPERS
  // =========================

  Future<List<Medication>> _loadMedications(String elderlyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('medications')
          .doc(elderlyId)
          .get();

      if (!doc.exists) return [];

      final data = doc.data();
      final medsList = (data?['medsList'] as List?) ?? [];

      return medsList
          .map((m) => Medication.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading medications in Arabic voice service: $e');
      return [];
    }
  }

  Medication? _selectMedicationFromUtterance(
    String utterance,
    List<Medication> meds,
  ) {
    final lowerUtterance = utterance.toLowerCase().trim();
    if (lowerUtterance.isEmpty) return null;

    for (final m in meds) {
      final nameLower = m.name.toLowerCase();
      if (lowerUtterance.contains(nameLower)) {
        return m;
      }
    }

    final bestOnFull = _bestMedicationFuzzyMatch(lowerUtterance, meds);
    if (bestOnFull != null) return bestOnFull;

    final tokens = lowerUtterance.split(RegExp(r'\s+'));
    for (final token in tokens) {
      final bestOnToken = _bestMedicationFuzzyMatch(token, meds);
      if (bestOnToken != null) return bestOnToken;
    }

    return null;
  }

  Medication? _bestMedicationFuzzyMatch(
    String text,
    List<Medication> meds,
  ) {
    final cleanedText = _normalizeText(text);
    if (cleanedText.isEmpty || meds.isEmpty) return null;

    Medication? bestMed;
    double bestScore = -1.0;

    for (final m in meds) {
      final cleanedName = _normalizeText(m.name);
      if (cleanedName.isEmpty) continue;

      final score = _similarityScore(cleanedText, cleanedName);
      if (score > bestScore) {
        bestScore = score;
        bestMed = m;
      }
    }

    return bestMed;
  }

  String _normalizeText(String input) {
    final lower = _normalizeArabic(input.toLowerCase());
    return lower.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
  }

  double _similarityScore(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final dist = _levenshteinDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 0.0;
    return 1.0 - dist / maxLen;
  }

  int _levenshteinDistance(String s, String t) {
    final m = s.length;
    final n = t.length;

    if (m == 0) return n;
    if (n == 0) return m;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[m][n];
  }

  // =========================
  // GENERIC HELPERS
  // =========================

  Future<String?> _askQuestion(String prompt, {int listenSeconds = 6}) async {
    await speak(prompt);
    final answer = await listenWhisper(seconds: listenSeconds);

    if (_isCancelUtterance(answer)) {
      return null;
    }

    return answer;
  }

  bool _isYes(String? answer) {
    if (answer == null) return false;
    final lower = _normalizeArabic(answer.toLowerCase());

    return lower.contains('yes') ||
        lower.contains('yeah') ||
        lower.contains('sure') ||
        lower.contains('نعم') ||
        lower.contains('اي') ||
        lower.contains('ايوه') ||
        lower.contains('أيوه') ||
        lower.contains('اجل') ||
        lower.contains('أجل') ||
        lower.contains('تمام');
  }

  bool _isNo(String? answer) {
    if (answer == null) return false;
    final lower = _normalizeArabic(answer.toLowerCase());

    return lower.contains('no') ||
        lower.contains('not') ||
        lower.contains('cancel') ||
        lower.contains('لا') ||
        lower.contains('مو') ||
        lower.contains('خلاص');
  }

  bool _isCancelUtterance(String? answer) {
    if (answer == null) return false;
    final lower = _normalizeArabic(answer.toLowerCase());

    return lower.contains('stop') ||
        lower.contains('cancel') ||
        lower.contains('enough') ||
        lower.contains('خلاص') ||
        lower.contains('وقف') ||
        lower.contains('وقفي') ||
        lower.contains('بس') ||
        lower.contains('الغ') ||
        lower.contains('الغاء') ||
        lower.contains('إلغاء');
  }

  List<TimeOfDay> expandTimesForFrequency(
    TimeOfDay base,
    String frequencyLabel,
  ) {
    switch (frequencyLabel) {
      case 'Twice a day':
        return [base, _addHours(base, 12)];
      case 'Three times a day':
        return [base, _addHours(base, 8), _addHours(base, 16)];
      case 'Four times a day':
        return [
          base,
          _addHours(base, 6),
          _addHours(base, 12),
          _addHours(base, 18),
        ];
      case 'Once a day':
      default:
        return [base];
    }
  }

  TimeOfDay _fallbackTime() {
    return const TimeOfDay(hour: 8, minute: 0);
  }

  TimeOfDay _addHours(TimeOfDay time, int hoursToAdd) {
    final totalMinutes = time.hour * 60 + time.minute + hoursToAdd * 60;
    final wrappedMinutes = totalMinutes % (24 * 60);
    final h = wrappedMinutes ~/ 60;
    final m = wrappedMinutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> dispose() async {
    await _player.stop();
    await _player.dispose();
  }
}