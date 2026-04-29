import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/voice_command.dart';
import '../models/medication.dart';
import 'medication_scheduler.dart';
import 'whisper_service.dart';

/// API KEY
const String _openAIApiKey =''; // TODO: Add your API Key here safely (e.g. environment variable)

class VoiceAssistantService {
  // ===== Singleton =====
  static final VoiceAssistantService _instance =
      VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final FlutterTts _tts = FlutterTts();

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

  // =========================
  //  INIT / TTS
  // =========================

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('🎙️ Microphone permission not granted');
      return false;
    }

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _isInitialized = true;
    debugPrint('✅ VoiceAssistantService initialized (Whisper + ChatGPT)');
    return true;
  }

  String getGreeting() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    if (displayName.isNotEmpty) {
      return 'Hi $displayName, how can I help you? ';
    }
    return 'Hi, how can I help you today?';
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    debugPrint('🗣️ TTS: $text');

    _isSpeaking = true;
    _notifyState(listening: false, speaking: true);

    await _tts.stop();
    await _tts.speak(text);

    _isSpeaking = false;
    _notifyState(listening: false, speaking: false);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    _notifyState(listening: false, speaking: false);
  }

  // =========================
  //  BEEP
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
  //  LISTEN (Whisper)
  // =========================

  Future<String?> listenWhisper({int seconds = 4}) async {
    final ok = await initialize();
    if (!ok) return null;

    _notifyState(listening: true, speaking: false);

    // 🔔
    await _playBeep();

    final whisper = WhisperService();
    final file = await whisper.recordAudio(seconds: seconds);

    if (file == null) {
      debugPrint('❌ No audio file recorded');
      _notifyState(listening: false, speaking: false);
      return null;
    }

    final text = await whisper.transcribeAudio(file, _openAIApiKey);

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
  //  MAIN CHAT FLOW
  // =========================

  Future<void> startConversation({
    required BuildContext context,
    required void Function(VoiceCommand) onCommand,
  }) async {
    final ok = await initialize();
    if (!ok) return;

    await speak(getGreeting());

    final answer = await listenWhisper(seconds: 5);

    if (_isCancelUtterance(answer)) {
      await speak('Okay, I will stop now.');
      return;
    }

    if (answer == null || answer.trim().isEmpty) {
      await speak('Sorry, I did not hear anything. You can try again later.');
      return;
    }

    debugPrint('🧠 User said (conversation): "$answer"');

    final command = await analyzeSmartCommand(answer);
    if (command != null) {
      onCommand(command);
    } else {
      await speak(
        'Sorry, I could not understand. You can ask about the weather or  say medications, media, home, or SOS.',
      );
    }
  }

  // =========================
  //  SMART INTENT (ChatGPT + local backup)
  // =========================

  Future<VoiceCommand?> analyzeSmartCommand(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;
    debugPrint('🧠 analyzeSmartCommand input: "$cleaned"');

    VoiceCommand? fromChat;

    if (_openAIApiKey.isNotEmpty) {
      fromChat = await _analyzeWithChatGPT(cleaned);
      if (fromChat != null) {
        debugPrint('🤖 ChatGPT intent → $fromChat');
        return fromChat;
      }
    } else {
      debugPrint('⚠️ OPENAI_API_KEY is empty, skipping ChatGPT intent.');
    }

    final local = analyzeCommandLocally(cleaned.toLowerCase());
    debugPrint('🧩 Local intent → $local');
    return local;
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
                  'User may speak English or Arabic. '
                  'Valid intents are: goToMedication, addMedication, editMedication, deleteMedication, '
                  'goToMedia, goToHome, sos, goToSettings, goToDailyLibrary,weather, news, todayMedications, none. '
                  'You MUST respond ONLY with pure JSON like {"intent":"addMedication"}.',
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
      final content = (decoded['choices'][0]['message']['content'] as String)
          .trim();

      debugPrint('📦 ChatGPT raw content: $content');

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

      if (jsonIntent == null) {
        debugPrint('⚠️ Could not parse JSON intent from content.');
        return null;
      }

      final intentString = (jsonIntent['intent'] ?? jsonIntent['Intent'] ?? '')
          .toString();

      return _intentFromString(intentString);
    } catch (e) {
      debugPrint('❌ ChatGPT intent error: $e');
      return null;
    }
  }

  VoiceCommand? _intentFromString(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();

    switch (lower) {
      case 'gotomedication':
      case 'gotomed':
      case 'med':
      case 'medication':
      case 'goToMedication':
        return VoiceCommand.goToMedication;

      case 'weather':
      case 'getweather':
      case 'weathertoday':
        return VoiceCommand.weather;

      case 'news':
      case 'latestnews':
      case 'headlines':
      case 'getnews':
      case 'newstoday':
        return VoiceCommand.news;

      case 'addmedication':
      case 'add_medication':
      case 'add_med':
      case 'add':
        return VoiceCommand.addMedication;

      case 'editmedication':
      case 'edit_medication':
      case 'edit_med':
      case 'edit':
        return VoiceCommand.editMedication;

      case 'deletemedication':
      case 'delete_medication':
      case 'delete_med':
      case 'delete':
        return VoiceCommand.deleteMedication;

      case 'gotomedia':
      case 'media':
      case 'goToMedia':
        return VoiceCommand.goToMedia;

      case 'gotohome':
      case 'home':
      case 'goToHome':
        return VoiceCommand.goToHome;

      case 'sos':
      case 'emergency':
        return VoiceCommand.sos;
      case 'gotodailylibrary':
      case 'daily_library':
      case 'dailylibrary':
      case 'daily':
       return VoiceCommand.goToDailyLibrary;

      case 'gotosettings':
      case 'settings':
      case 'goToSettings':
        return VoiceCommand.goToSettings;

      case 'todaymedications': //  insert from here
      case 'today_medications':
      case 'today_meds':
      case 'mymedications':
      case 'todaymeds':
        return VoiceCommand.todayMedications; //  to here

      case 'none':
      default:
        return null;
    }
  }

  // =========================
  //  LOCAL COMMAND ANALYZER (backup)
  // =========================

  VoiceCommand? analyzeCommandLocally(String text) {
    final lower = text.toLowerCase();

    if (_containsAny(lower, [
      'sos',
      'emergency',
      'help me',
      'call help',
      'استغاثة',
      'طوارئ',
      'ساعد',
      'نجدة',
    ])) {
      return VoiceCommand.sos;
    }

    if (_containsAny(lower, [
      'media',
      'media libarary',
      
      'Media',
      'audio',
      'song',
      'قرآن',
      'سورة',
      'surah',
      'video',
    ])) {
      return VoiceCommand.goToMedia;
    }

    if (_containsAny(lower, [
      'medication',
      'medications',
      'medicine',
      'med',
      'meds',
      'pill',
      'دواء',
      'الأدوية',
      'ادوية',
      'دوائي',
    ])) {
      return VoiceCommand.goToMedication;
    }

    if (_containsAny(lower, [
      'home',
      'main page',
      'الصفحة الرئيسية',
      'الرئيسية',
      'هوم',
    ])) {
      return VoiceCommand.goToHome;
    }

    if (_containsAny(lower, ['settings', 'اعدادات', 'الإعدادات'])) {
      return VoiceCommand.goToSettings;
    }

    if (_containsAny(lower, [
      'add medicine',
      'add medication',
      'new medicine',
      'add a medicine',
      'add a medication',
      'أضف دواء',
      'دواء جديد',
      'إضافة دواء',
      'اضيف دواء',
      'ابي اضيف دواء',
    ])) {
      return VoiceCommand.addMedication;
    }

    if (_containsAny(lower, [
      'delete medicine',
      'remove medicine',
      'حذف دواء',
      'احذف الدواء',
      'شيل الدواء',
    ])) {
      return VoiceCommand.deleteMedication;
    }

    if (_containsAny(lower, [
      'edit medicine',
      'change medicine',
      'تعديل دواء',
      'غير الدواء',
      'عدّل الدواء',
    ])) {
      return VoiceCommand.editMedication;
    }




    if (_containsAny(lower, [
  'daily library',
  'daily',
        'weather',
      'today weather',
      'forecast',
      'temperature',
      'climate',
      'how is the weather',
      'what is the weather',
  'library',
        'news',
      'latest news',
  'المكتبه اليوميه',
  'المكتبة اليومية',
  'مكتبه يوميه',
  'مكتبة يومية',
        'news',
      'latest news',
      'headlines',
      'اخبار',
      'الأخبار',
      'خبر',
])) {
  return VoiceCommand.goToDailyLibrary;
}

    if (_containsAny(lower, [
      // 👈 insert from here
      'today medications',
      'my medications today',
      'what medications',
      'medications today',
      'my meds today',
      'what meds',
      'which medications',
      'did i take',
      'have i taken',
      'medications left',
      'what do i have today',
      'ادويتي اليوم',
      'دوائي اليوم',
      'ماذا اخذت',
      'ما اخذت',
      'الدواء اليوم',
    ])) {
      return VoiceCommand.todayMedications;
    } // 👈 to here

    return null;
  }

  bool _containsAny(String text, List<String> patterns) {
    for (final p in patterns) {
      final pLower = p.toLowerCase();
      // Arabic chars don't work with \b word boundary — use .contains()
      final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(pLower);
      if (hasArabic) {
        if (text.contains(pLower)) return true;
      } else {
        // Latin: try word-boundary first, fallback to contains
        final pattern = r'\b' + RegExp.escape(pLower) + r'\b';
        if (RegExp(pattern).hasMatch(text)) return true;
        // Also match if the whole utterance IS the word (e.g. user just says "dose")
        if (text.trim() == pLower) return true;
      }
    }
    return false;
  }
  // =========================
  //  MEDICATION FLOWS
  // =========================

  Future<void> runAddMedicationFlow(String elderlyId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await speak('You must be logged in to add a medication.');
      return;
    }

    final ok = await initialize();
    if (!ok) return;

    await speak(
      'Okay, let\'s add a new medication. I will ask you a few questions.',
    );

    // 1) Name
    final name = await _askQuestion(
      'First, what is the medication name? Please say it in English.',
      listenSeconds: 5,
    );
    if (_isCancelUtterance(name)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    if (name == null || name.isEmpty) {
      await speak('I did not catch the name. We will stop for now.');
      return;
    }

    final confirmName = await _askQuestion(
      'You said "$name". Is that correct? Say yes or no.',
      listenSeconds: 3,
    );
    if (_isCancelUtterance(confirmName)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    if (_isNo(confirmName)) {
      await speak('Okay, we will cancel adding the medication.');
      return;
    }

    // 2) Duration
    final durationAnswer = await _askQuestion(
      'How long do you need to take $name? '
      'You can say a number of days like three days, or one month, '
      'or a specific date like March seventh. Say ongoing if there is no end date.',
      listenSeconds: 6,
    );
    if (_isCancelUtterance(durationAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    final int? durationDays = parseDurationFromSpeech(durationAnswer ?? '');
    DateTime? endDate;
    if (durationDays != null && durationDays > 0) {
      endDate = DateTime.now().add(Duration(days: durationDays));
    }

    // 3) Days
    final daysAnswer = await _askQuestion(
      'On which days do you take $name? You can say every day, or mention specific days like Sunday and Wednesday.',
      listenSeconds: 6,
    );
    if (_isCancelUtterance(daysAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    final days = parseDaysFromSpeech(daysAnswer ?? '');

    // 4) Frequency
    final freqAnswer = await _askQuestion(
      'How many times per day do you take $name? Say once, twice, three or four times.',
      listenSeconds: 4,
    );
    if (_isCancelUtterance(freqAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    final frequency = parseFrequencyFromSpeech(freqAnswer ?? '');
    final finalFrequency = frequency ?? 'Once a day';

    // 5) Dose form
    final doseFormAnswer = await _askQuestion(
      'What form is this medication? '
      'For example, say capsule, syrup, injection, or other.',
      listenSeconds: 5,
    );
    if (_isCancelUtterance(doseFormAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    final String? doseForm = parseDoseFormFromSpeech(doseFormAnswer ?? '');

    // 6) Dose strength
    final doseStrengthAnswer = await _askQuestion(
      'How much do you take each time? '
      'For example, say 1 capsule, 2 drops, or 5 ml.',
      listenSeconds: 5,
    );
    if (_isCancelUtterance(doseStrengthAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    String? doseStrength;
    if (doseStrengthAnswer != null &&
        doseStrengthAnswer.trim().isNotEmpty &&
        !_isNoNotes(doseStrengthAnswer)) {
      doseStrength = doseStrengthAnswer.trim();
    }

    // 7) First time
    final timeAnswer = await _askQuestion(
      'At what time do you usually take the first dose? For example, eight am or nine thirty pm',
      listenSeconds: 5,
    );
    if (_isCancelUtterance(timeAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    final firstTime = (timeAnswer == null || timeAnswer.isEmpty)
        ? _fallbackTime()
        : parseTimeFromSpeech(timeAnswer);
    final times = expandTimesForFrequency(firstTime, finalFrequency);

    // 8) Notes
    final notesAnswer = await _askQuestion(
      'Do you want to add any special notes? '
      'For example, take before food or take after food. Say no if you have none.',
      listenSeconds: 5,
    );
    if (_isCancelUtterance(notesAnswer)) {
      await speak('Okay, we will stop adding the medication.');
      return;
    }
    final notes = _isNoNotes(notesAnswer) ? null : notesAnswer!.trim();

    final newMed = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      doseForm: doseForm,
      doseStrength: doseStrength,
      days: days,
      frequency: finalFrequency,
      times: times,
      notes: notes,
      addedBy: currentUser.uid,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      endDate: endDate != null ? Timestamp.fromDate(endDate) : null,
    );
    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(elderlyId);

    try {
      await docRef.set({
        'medsList': FieldValue.arrayUnion([newMed.toMap()]),
      }, SetOptions(merge: true));

      await speak('Got it. I added $name to your medications.');

      await MedicationScheduler().scheduleAllMedications(elderlyId);
    } catch (e) {
      debugPrint('❌ Error saving medication by voice: $e');
      await speak('Sorry, I could not save the medication due to an error.');
    }
  }

  Future<void> runDeleteMedicationFlow(String elderlyId) async {
    final ok = await initialize();
    if (!ok) return;

    final meds = await _loadMedications(elderlyId);
    if (meds.isEmpty) {
      await speak('You do not have any medications saved yet.');
      return;
    }

    final namesText = meds.map((m) => m.name).join(', ');
    await speak(
      'You have the following medications: $namesText. '
      'Which medication do you want to delete? Please say the medication name in English, for example "delete Panadol".',
    );

    Medication? target;
    const maxTries = 3;

    for (int attempt = 1; attempt <= maxTries; attempt++) {
      final answer = await listenWhisper(seconds: 4);
      debugPrint('🎧 delete utterance (try $attempt): "$answer"');

      if (_isCancelUtterance(answer)) {
        await speak('Okay, we will stop deleting for now.');
        return;
      }

      if (answer == null || answer.trim().isEmpty) {
        if (attempt < maxTries) {
          await speak(
            'I did not hear anything. Please say the medication name, for example "delete Panadol".',
          );
          continue;
        } else {
          await speak(
            'I still could not hear a name. We will cancel deleting for now.',
          );
          return;
        }
      }

      target = _selectMedicationFromUtterance(answer, meds);

      if (target != null) break;
      if (attempt < maxTries) {
        await speak(
          'I could not match this to any medication. Please say the medication name clearly, in English.',
        );
      } else {
        await speak(
          'I still could not find any medication that matches. We will cancel deleting for now.',
        );
        return;
      }
    }

    if (target == null) {
      await speak('We will cancel deleting for now.');
      return;
    }

    final confirm = await _askQuestion(
      'I think you mean "${target.name}". Do you want to delete it? Say yes or no.',
      listenSeconds: 3,
    );
    if (_isCancelUtterance(confirm)) {
      await speak('Okay, we will stop deleting for now.');
      return;
    }
    if (!_isYes(confirm)) {
      await speak('Okay, I will not delete it.');
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(elderlyId);

    try {
      await docRef.update({
        'medsList': FieldValue.arrayRemove([target.toMap()]),
      });

      await speak('The medication ${target.name} has been deleted.');

      await MedicationScheduler().scheduleAllMedications(elderlyId);
    } catch (e) {
      debugPrint('❌ Error deleting medication: $e');
      await speak(
        'Sorry, I could not delete the medication because of an error.',
      );
    }
  }

  Future<void> runTodayMedicationsFlow(String elderlyId) async {
    final ok = await initialize();
    if (!ok) return;

    try {
      final allMeds = await _loadMedications(elderlyId);
      if (allMeds.isEmpty) {
        await speak('You have no medications saved yet.');
        return;
      }

      final now = DateTime.now();
      final todayName = _dayName(now.weekday);

      final todayMeds = allMeds.where((m) {
        if (m.days == null || m.days!.isEmpty) return false;
        return m.days!.any((d) => d.toLowerCase() == todayName.toLowerCase());
      }).toList();

      if (todayMeds.isEmpty) {
        await speak('You have no medications scheduled for today.');
        return;
      }

      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Fetch the single daily log document
      final logDoc = await FirebaseFirestore.instance
          .collection('medication_log')
          .doc(elderlyId)
          .collection('daily_log')
          .doc(todayKey)
          .get();

      final logData = logDoc.exists ? (logDoc.data() ?? {}) : {};

      final takenParts = <String>[];
      final remainingParts = <String>[];

      for (final med in todayMeds) {
        for (int i = 0; i < (med.times ?? []).length; i++) {
          final t = med.times![i];
          final logKey = '${med.id}_$i';
          final label = '${med.name} at ${_formatTime(t)}';
          final doseLog = logData[logKey] as Map<String, dynamic>?;
          final status = doseLog?['status'] as String? ?? '';
          if (status == 'taken_on_time' || status == 'taken_late') {
            takenParts.add(label);
          } else {
            remainingParts.add(label);
          }
        }
      }

      final buffer = StringBuffer();
      final total = takenParts.length + remainingParts.length;

      if (remainingParts.isEmpty) {
        buffer.write(
          'Great job! You have taken all $total of your medications for today.',
        );
      } else if (takenParts.isEmpty) {
        buffer.write(
          'You have $total medication${total > 1 ? 's' : ''} today, none taken yet. '
          'You need to take: ${remainingParts.join(', ')}.',
        );
      } else {
        buffer.write(
          'You have ${remainingParts.length} medication${remainingParts.length > 1 ? 's' : ''} left to take: '
          '${remainingParts.join(', ')}. '
          'Already taken: ${takenParts.join(', ')}.',
        );
      }

      await speak(buffer.toString());
    } catch (e) {
      debugPrint('❌ runTodayMedicationsFlow error: $e');
      await speak('Sorry, I could not load your medications right now.');
    }
  }

  String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Complete voice-controlled edit flow with multiple field editing
  Future<void> runEditMedicationFlow(String elderlyId) async {
    final ok = await initialize();
    if (!ok) return;

    final meds = await _loadMedications(elderlyId);
    if (meds.isEmpty) {
      await speak('You do not have any medications to edit.');
      return;
    }

    await speak('Which medication would you like to edit?');
    final namesText = meds.map((m) => m.name).join(', ');
    await speak('You have: $namesText');

    Medication? targetMed;
    const maxTries = 3;

    for (int attempt = 1; attempt <= maxTries; attempt++) {
      final answer = await listenWhisper(seconds: 4);
      debugPrint('🎧 Edit medication selection (try $attempt): "$answer"');

      if (_isCancelUtterance(answer)) {
        await speak('Okay, we will stop editing for now.');
        return;
      }

      if (answer == null || answer.trim().isEmpty) {
        if (attempt < maxTries) {
          await speak(
            'I did not hear anything. Please say the medication name.',
          );
          continue;
        } else {
          await speak('We will cancel editing for now.');
          return;
        }
      }

      targetMed = _selectMedicationFromUtterance(answer, meds);
      if (targetMed != null) break;

      if (attempt < maxTries) {
        await speak(
          'I could not match that. Please say the medication name clearly.',
        );
      } else {
        await speak('We will cancel editing for now.');
        return;
      }
    }

    if (targetMed == null) return;

    final confirm = await _askQuestion(
      'You want to edit ${targetMed.name}. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, we will stop editing for now.');
      return;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, we will not edit it.');
      return;
    }

    Medication currentMed = targetMed;
    bool continueEditing = true;

    while (continueEditing) {
      await speak(
        'What would you like to edit? You can say: name, duration, days, frequency, dose, times, or notes.',
      );

      String? fieldToEdit;
      for (int attempt = 1; attempt <= 2; attempt++) {
        final fieldAnswer = await listenWhisper(seconds: 4);
        debugPrint('🎧 Field selection: "$fieldAnswer"');

        if (_isCancelUtterance(fieldAnswer)) {
          await speak('Okay, we will stop editing for now.');
          return;
        }

        if (fieldAnswer == null || fieldAnswer.isEmpty) {
          if (attempt < 2) {
            await speak(
              'Please say which field: name, duration, days, frequency, dose, times, or notes.',
            );
            continue;
          } else {
            await speak('We will stop editing now.');
            continueEditing = false;
            break;
          }
        }

        fieldToEdit = _parseEditField(fieldAnswer);
        if (fieldToEdit != null) break;

        if (attempt < 2) {
          await speak(
            'I did not understand. Please say: name, duration, days, frequency, dose, times, or notes.',
          );
        }
      }

      if (fieldToEdit == null) {
        continueEditing = false;
        break;
      }

      final updatedMed = await _editFieldByVoice(currentMed, fieldToEdit);

      if (updatedMed == null) {
        await speak('That field was not changed.');
      } else {
        currentMed = updatedMed;
        await speak('Field updated successfully.');
      }

      final continueAnswer = await _askQuestion(
        'Would you like to edit another field? Say yes or no.',
        listenSeconds: 3,
      );

      if (_isCancelUtterance(continueAnswer)) {
        await speak('Okay, we will stop editing now.');
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
        return med as Map<String, dynamic>;
      }).toList();

      await docRef.update({'medsList': updatedMedsList});

      await speak(
        'Perfect! I have updated ${targetMed.name} for you. All changes are saved.',
      );

      await MedicationScheduler().scheduleAllMedications(elderlyId);
    } catch (e) {
      debugPrint('❌ Error saving edited medication: $e');
      await speak('Sorry, I could not save the changes due to an error.');
    }
  }

  // ===== Helpers for Edit Flow =====

  String? _parseEditField(String utterance) {
    final lower = utterance.toLowerCase().trim();

    if (_containsAny(lower, ['name', 'medication name', 'title', 'الاسم'])) {
      return 'name';
    }
    if (_containsAny(lower, [
      'duration',
      'how long',
      'end date',
      'period',
      'length',
      'مدة',
      'لمدة',
      'فتره',
      'فترة',
      'متى ينتهي',
    ])) {
      return 'duration';
    }
    if (_containsAny(lower, [
      'dose',
      'dosage',
      'form',
      'strength',
      'milligram',
      'mg',
      'tablet',
      'capsule',
      'syrup',
      'drops',
      'جرعه',
      'جرعة',
      'شكل',
      'الجرعه',
      'الجرعة',
    ])) {
      return 'dose';
    }
    if (_containsAny(lower, [
      'day',
      'days',
      'when',
      'schedule',
      'أيام',
      'يوم',
    ])) {
      return 'days';
    }
    if (_containsAny(lower, [
      'frequency',
      'how many',
      'how often',
      'times per day',
      'مرات',
    ])) {
      return 'frequency';
    }
    if (_containsAny(lower, [
      'time',
      'times',
      'clock',
      'hour',
      'وقت',
      'ساعة',
    ])) {
      return 'times';
    }
    if (_containsAny(lower, [
      'note',
      'notes',
      'instruction',
      'ملاحظات',
      'تعليمات',
    ])) {
      return 'notes';
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
      case 'duration':
        return await _editDuration(original);
      case 'days':
        return await _editDays(original);
      case 'frequency':
        return await _editFrequency(original);
      case 'dose':
        return await _editDose(original);
      case 'times':
        return await _editTimes(original);
      case 'notes':
        return await _editNotes(original);
      default:
        return null;
    }
  }

  Future<Medication?> _editName(Medication original) async {
    await speak('What is the new name for this medication?');

    final newName = await listenWhisper(seconds: 5);

    if (_isCancelUtterance(newName)) {
      await speak('Okay, we will keep the original name.');
      return null;
    }

    if (newName == null || newName.trim().isEmpty) {
      await speak('I did not hear a name. Keeping the old name.');
      return null;
    }

    final confirm = await _askQuestion(
      'Change the name to $newName. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original name.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original name.');
      return null;
    }

    return Medication(
      id: original.id,
      name: newName.trim(),
      doseForm: original.doseForm,
      doseStrength: original.doseStrength,
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

  Future<Medication?> _editDuration(Medication original) async {
    await speak(
      'How long should you take this medication? '
      'You can say a number of days like seven days, two weeks '
      'or a specific date like March seventh.or  Say ongoing if there is no end date.',
    );

    final durationAnswer = await listenWhisper(seconds: 5);

    if (_isCancelUtterance(durationAnswer)) {
      await speak('Okay, keeping the original duration.');
      return null;
    }

    if (durationAnswer == null || durationAnswer.isEmpty) {
      await speak('I did not hear a duration. Keeping the old duration.');
      return null;
    }

    final int? newDuration = parseDurationFromSpeech(durationAnswer);
    Timestamp? newEndDate;

    if (newDuration != null && newDuration > 0) {
      final end = DateTime.now().add(Duration(days: newDuration));
      newEndDate = Timestamp.fromDate(end);
    }

    final durationText = newDuration != null ? '$newDuration days' : 'ongoing';
    final confirm = await _askQuestion(
      'Set the duration to $durationText. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original duration.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original duration.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      doseForm: original.doseForm,
      doseStrength: original.doseStrength,
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

  Future<Medication?> _editDose(Medication original) async {
    // Ask for form
    await speak(
      'What form is this medication? '
      'For example, say capsule, syrup, injection, or other.',
    );

    final formAnswer = await listenWhisper(seconds: 5);

    if (_isCancelUtterance(formAnswer)) {
      await speak('Okay, keeping the original dose.');
      return null;
    }

    String? newForm;
    if (formAnswer != null && formAnswer.isNotEmpty) {
      newForm = parseDoseFormFromSpeech(formAnswer);
    }
    newForm ??= original.doseForm;

    // Ask for strength
    await speak(
      'How much do you take each time? '
      'For example, say 1 capsule, 2 drops, or 5 ml. ',
    );

    final strengthAnswer = await listenWhisper(seconds: 5);

    if (_isCancelUtterance(strengthAnswer)) {
      await speak('Okay, keeping the original dose.');
      return null;
    }

    String? newStrength = original.doseStrength;
    if (strengthAnswer != null &&
        strengthAnswer.trim().isNotEmpty &&
        !_isNoNotes(strengthAnswer) &&
        !strengthAnswer.toLowerCase().contains('keep')) {
      newStrength = strengthAnswer.trim();
    }

    final formLabel = newForm ?? 'not set';
    final strengthLabel = (newStrength != null && newStrength.isNotEmpty)
        ? newStrength
        : 'not set';
    final confirm = await _askQuestion(
      'Set the dose to $formLabel, $strengthLabel. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original dose.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original dose.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      doseForm: newForm,
      doseStrength: newStrength,
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
    await speak(
      'On which days should you take this medication? '
      'You can say every day, or mention specific days like Sunday and Wednesday.',
    );

    final daysAnswer = await listenWhisper(seconds: 6);

    if (_isCancelUtterance(daysAnswer)) {
      await speak('Okay, keeping the original days.');
      return null;
    }

    if (daysAnswer == null || daysAnswer.isEmpty) {
      await speak('I did not hear any days. Keeping the old schedule.');
      return null;
    }

    final newDays = parseDaysFromSpeech(daysAnswer);

    final daysText = newDays.join(', ');
    final confirm = await _askQuestion(
      'Set the days to: $daysText. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original days.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original days.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      doseForm: original.doseForm,
      doseStrength: original.doseStrength,
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
    await speak(
      'How many times per day should you take this medication? '
      'Say once, twice, three times, or four times.',
    );

    final freqAnswer = await listenWhisper(seconds: 4);

    if (_isCancelUtterance(freqAnswer)) {
      await speak('Okay, keeping the original frequency.');
      return null;
    }

    if (freqAnswer == null || freqAnswer.isEmpty) {
      await speak('I did not hear a frequency. Keeping the old frequency.');
      return null;
    }

    final newFrequency = parseFrequencyFromSpeech(freqAnswer) ?? 'Once daily';

    final confirm = await _askQuestion(
      'Change frequency to $newFrequency. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original frequency.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original frequency.');
      return null;
    }

    final firstTime = original.times.isNotEmpty
        ? original.times.first
        : const TimeOfDay(hour: 8, minute: 0);

    final newTimes = expandTimesForFrequency(firstTime, newFrequency);

    return Medication(
      id: original.id,
      name: original.name,
      doseForm: original.doseForm,
      doseStrength: original.doseStrength,
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
    await speak(
      'At what time should you take the first dose? '
      'For example, say eight am or nine thirty pm.',
    );

    final timeAnswer = await listenWhisper(seconds: 5);

    if (_isCancelUtterance(timeAnswer)) {
      await speak('Okay, keeping the original times.');
      return null;
    }

    if (timeAnswer == null || timeAnswer.isEmpty) {
      await speak('I did not hear a time. Keeping the old times.');
      return null;
    }

    final newFirstTime = parseTimeFromSpeech(timeAnswer);
    final frequency = original.frequency ?? 'Once daily';
    final newTimes = expandTimesForFrequency(newFirstTime, frequency);

    final timesText = newTimes
        .map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}')
        .join(', ');
    final confirm = await _askQuestion(
      'Set the times to: $timesText. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original times.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original times.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      doseForm: original.doseForm,
      doseStrength: original.doseStrength,
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
    await speak(
      'What are the new Notes? '
      'For example, you can say: take with food, or take before bed. '
      'Say no or none to remove all notes.',
    );

    final notesAnswer = await listenWhisper(seconds: 6);

    if (_isCancelUtterance(notesAnswer)) {
      await speak('Okay, keeping the original notes.');
      return null;
    }

    String? newNotes;
    if (_isNoNotes(notesAnswer)) {
      newNotes = null;
    } else {
      newNotes = notesAnswer!.trim();
    }

    final confirm = await _askQuestion(
      newNotes != null
          ? 'Set the notes to: $newNotes. Is that correct? Say yes or no.'
          : 'Remove all notes. Is that correct? Say yes or no.',
      listenSeconds: 3,
    );

    if (_isCancelUtterance(confirm)) {
      await speak('Okay, keeping the original notes.');
      return null;
    }

    if (!_isYes(confirm)) {
      await speak('Okay, keeping the original notes.');
      return null;
    }

    return Medication(
      id: original.id,
      name: original.name,
      doseForm: original.doseForm,
      doseStrength: original.doseStrength,
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
  // ===== Helpers for medication data =====

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
      debugPrint('❌ Error loading medications in voice service: $e');
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
        debugPrint('🔍 Direct match for medication: ${m.name}');
        return m;
      }
    }

    final bestOnFull = _bestMedicationFuzzyMatch(lowerUtterance, meds);
    if (bestOnFull != null) return bestOnFull;

    final tokens = lowerUtterance.split(RegExp(r'\s+'));
    for (final token in tokens) {
      final bestOnToken = _bestMedicationFuzzyMatch(token, meds);
      if (bestOnToken != null) {
        return bestOnToken;
      }
    }

    return null;
  }

  Medication? _bestMedicationFuzzyMatch(
    String text,
    List<Medication> meds, {
    double threshold = 0.0,
  }) {
    final cleanedText = _normalizeText(text);
    if (cleanedText.isEmpty) return null;
    if (meds.isEmpty) return null;

    Medication? bestMed;
    double bestScore = -1.0;

    for (final m in meds) {
      final cleanedName = _normalizeText(m.name);
      if (cleanedName.isEmpty) continue;

      final score = _similarityScore(cleanedText, cleanedName);
      debugPrint('🔎 fuzzy score("$cleanedText", "$cleanedName") = $score');

      if (score > bestScore) {
        bestScore = score;
        bestMed = m;
      }
    }

    if (bestMed == null) return null;

    debugPrint('✅ Fuzzy picked medication: ${bestMed.name} (score=$bestScore)');
    return bestMed;
  }

  String _normalizeText(String input) {
    final lower = input.toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '');
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

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

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
  //  Generic helpers
  // =========================

  Future<String?> _askQuestion(String prompt, {int listenSeconds = 4}) async {
    await speak(prompt);
    final answer = await listenWhisper(seconds: listenSeconds);
    debugPrint('🧠 Answer to "$prompt": "$answer"');

    if (_isCancelUtterance(answer)) {
      debugPrint('🛑 Cancel utterance detected inside _askQuestion.');
      return null;
    }

    return answer;
  }

  bool _isYes(String? answer) {
    if (answer == null) return false;
    final lower = answer.toLowerCase();
    return lower.contains('yes') ||
        lower.contains('yeah') ||
        lower.contains('sure') ||
        lower.contains('تمام') ||
        lower.contains('اي') ||
        lower.contains('أجل');
  }

  bool _isNo(String? answer) {
    if (answer == null) return false;
    final lower = answer.toLowerCase();
    return lower.contains('no') ||
        lower.contains('not') ||
        lower.contains('cancel') ||
        lower.contains('لا') ||
        lower.contains('مو لازم') ||
        lower.contains('خلاص');
  }

  /// Detects when the user means "no notes / nothing to add" rather than
  /// dictating actual note content.  Catches: "no", "nope", "none",
  /// "nothing", "that's it", "that is it", "I'm done", "no notes",
  /// "not really", "all good", Arabic equivalents, etc.
  bool _isNoNotes(String? answer) {
    if (answer == null) return true;
    final lower = answer.toLowerCase().trim();
    if (lower.isEmpty) return true;

    // Exact short phrases that clearly mean "no notes"
    const noPatterns = [
      'no', 'nope', 'none', 'nothing', 'nah', 'not really',
      'no notes', 'no note', 'no thanks', 'no thank you',
      "that's it", 'that is it', "that's all", 'that is all',
      "i'm done", 'i am done', 'done', 'all done',
      'all good', "i'm good", 'i am good', 'good',
      'not now', 'no instructions', 'skip', 'next',
      // Arabic
      'لا', 'خلاص', 'بس', 'مافي', 'ما في', 'لا شي',
      'لا شيء', 'ماعندي', 'ما عندي', 'تمام', 'انتهيت',
      'مو لازم', 'لا ملاحظات',
    ];

    for (final p in noPatterns) {
      if (lower == p || lower == '$p.' || lower == '$p!') return true;
    }

    // Also match if the entire utterance is very short (≤3 words)
    // and starts with "no" or "not" — e.g. "no I don't", "not really"
    final words = lower.split(RegExp(r'\s+'));
    if (words.length <= 4 &&
        (lower.startsWith('no') ||
            lower.startsWith('not') ||
            lower.startsWith('nah') ||
            lower.startsWith('لا') ||
            lower.startsWith('خلاص') ||
            lower.startsWith('بس'))) {
      return true;
    }

    return false;
  }

  // ====== Global Voice Cancellation ======
  String _normalizeArabicForCancel(String input) {
    // Remove diacritics
    final diacritics = RegExp(
      r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
    );
    var out = input.replaceAll(diacritics, '');
    out = out
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    return out;
  }

  bool _isCancelUtterance(String? answer) {
    if (answer == null) return false;
    final lower = answer.toLowerCase();

    if (lower.contains('stop') ||
        lower.contains('cancel') ||
        lower.contains('enough')) {
      return true;
    }

    // Arabic with/without diacritics
    final norm = _normalizeArabicForCancel(lower);

    return norm.contains('خلاص') ||
        norm.contains('وقف') ||
        norm.contains('وقفي') ||
        norm.contains('ستوب') ||
        norm.contains('بس') ||
        norm.contains('لا تكمل') ||
        norm.contains('الغ') ||
        norm.contains('الغاء');
  }

  TimeOfDay parseTimeFromSpeech(String speech) {
    final now = TimeOfDay.now();
    final lower = speech.toLowerCase();

    int hour = now.hour;
    int minute = 0;

    final regex = RegExp(r'(\d{1,2})(:(\d{1,2}))?');
    final match = regex.firstMatch(lower);
    if (match != null) {
      final hStr = match.group(1);
      final mStr = match.group(3);
      if (hStr != null) {
        hour = int.tryParse(hStr) ?? now.hour;
      }
      if (mStr != null) {
        minute = int.tryParse(mStr) ?? 0;
      }
    }

    final isPm =
        lower.contains('pm') || lower.contains('مساء') || lower.contains('ليل');
    final isAm =
        lower.contains('am') ||
        lower.contains('صباح') ||
        lower.contains('صباحا');

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  List<String> parseDaysFromSpeech(String speech) {
    final lower = speech.toLowerCase();
    if (lower.contains('every day') || lower.contains('كل يوم')) {
      return const [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ];
    }

    final Map<String, String> dayMap = {
      'sunday': 'Sunday',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'الأحد': 'Sunday',
      'اﻷحد': 'Sunday',
      'الاثنين': 'Monday',
      'الإثنين': 'Monday',
      'الثلاثاء': 'Tuesday',
      'الاربعاء': 'Wednesday',
      'الأربعاء': 'Wednesday',
      'الخميس': 'Thursday',
      'الجمعة': 'Friday',
      'السبت': 'Saturday',
    };

    final result = <String>[];
    for (final entry in dayMap.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        result.add(entry.value);
      }
    }

    if (result.isEmpty) {
      return const [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ];
    }

    return result.toSet().toList();
  }

  String? parseFrequencyFromSpeech(String speech) {
    final lower = speech.toLowerCase();
    if (lower.contains('once') ||
        lower.contains('one time') ||
        lower.contains('مرة واحدة')) {
      return 'Once a day';
    }
    if (lower.contains('twice') ||
        lower.contains('two times') ||
        lower.contains('مرتين')) {
      return 'Twice a day';
    }
    if (lower.contains('three') || lower.contains('ثلاث')) {
      return 'Three times a day';
    }
    if (lower.contains('four') || lower.contains('أربع')) {
      return 'Four times a day';
    }
    return null;
  }

  /// Parse dose form from speech (English + Arabic)
  String? parseDoseFormFromSpeech(String speech) {
    final lower = speech.toLowerCase();

    // English
    if (lower.contains('capsule') || lower.contains('cap')) return 'Capsule';
    if (lower.contains('syrup') ||
        lower.contains('liquid') ||
        lower.contains('solution'))
      return 'Syrup';
    if (lower.contains('cream') ||
        lower.contains('ointment') ||
        lower.contains('gel'))
      return 'Cream/Ointment';
    if (lower.contains('eye drop')) return 'Eye Drops';
    if (lower.contains('ear drop')) return 'Ear Drops';
    if (lower.contains('nasal') || lower.contains('nose spray'))
      return 'Nasal Spray';
    if (lower.contains('injection') ||
        lower.contains('inject') ||
        lower.contains('needle'))
      return 'Injection';
    if (lower.contains('other')) return 'Other';
    // Generic 'drop' after specific eye/ear/nasal
    if (lower.contains('drop')) return 'Eye Drops';

    // Arabic (normalized)
    if (speech.contains('كبسول')) return 'Capsule';
    if (speech.contains('حبوب') ||
        speech.contains('حبه') ||
        speech.contains('اقراص') ||
        speech.contains('قرص'))
      return 'Capsule';
    if (speech.contains('شراب') || speech.contains('محلول')) return 'Syrup';
    if (speech.contains('كريم') ||
        speech.contains('مرهم') ||
        speech.contains('جل'))
      return 'Cream/Ointment';
    if (speech.contains('قطره') && speech.contains('عين')) return 'Eye Drops';
    if (speech.contains('قطره') && speech.contains('اذن')) return 'Ear Drops';
    if (speech.contains('بخاخ') && speech.contains('انف')) return 'Nasal Spray';
    if (speech.contains('قطره')) return 'Eye Drops';
    if (speech.contains('حقنه') || speech.contains('ابره')) return 'Injection';
    if (speech.contains('بخاخ')) return 'Nasal Spray';

    return null;
  }

  /// Parse duration from speech → number of days (or null for ongoing).
  /// Supports relative ("7 days", "two weeks") AND specific dates
  /// ("7 of March", "March 7th", "until the tenth of april", "٧ مارس").
  int? parseDurationFromSpeech(String speech) {
    final lower = speech.toLowerCase();

    // "ongoing", "forever", "no end", "لا يوجد" → null means ongoing
    if (lower.contains('ongoing') ||
        lower.contains('forever') ||
        lower.contains('no end') ||
        lower.contains('مستمر') ||
        lower.contains('لا يوجد')) {
      return null;
    }

    // ── Try specific date first ("7 of March", "March 7th", "٧ مارس") ──
    final dateResult = _parseDateFromSpeech(speech);
    if (dateResult != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = dateResult.difference(today).inDays;
      if (diff > 0 && diff <= 365) {
        debugPrint('📅 Parsed date: $dateResult → $diff days from today');
        return diff;
      }
    }

    // ── Relative durations ──

    // English: "7 days", "two weeks", "1 month"
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(lower);
    if (daysMatch != null) {
      final d = int.tryParse(daysMatch.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    final weeksMatch = RegExp(r'(\d+)\s*weeks?').firstMatch(lower);
    if (weeksMatch != null) {
      final w = int.tryParse(weeksMatch.group(1) ?? '');
      if (w != null && w > 0 && w <= 52) return w * 7;
    }

    final monthsMatch = RegExp(r'(\d+)\s*months?').firstMatch(lower);
    if (monthsMatch != null) {
      final m = int.tryParse(monthsMatch.group(1) ?? '');
      if (m != null && m > 0 && m <= 12) return m * 30;
    }

    // Word numbers
    if (lower.contains('one week') || lower.contains('a week')) return 7;
    if (lower.contains('two week')) return 14;
    if (lower.contains('three week')) return 21;
    if (lower.contains('one month') || lower.contains('a month')) return 30;
    if (lower.contains('two month')) return 60;
    if (lower.contains('three day')) return 3;
    if (lower.contains('five day')) return 5;
    if (lower.contains('ten day')) return 10;

    // Arabic
    if (speech.contains('اسبوعين')) return 14;
    if (speech.contains('اسبوع')) return 7;
    if (speech.contains('شهرين')) return 60;
    if (speech.contains('شهر')) return 30;

    final arDaysMatch = RegExp(r'(\d+)\s*(يوم|ايام)').firstMatch(speech);
    if (arDaysMatch != null) {
      final d = int.tryParse(arDaysMatch.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    return null; // default ongoing
  }

  /// Parse a specific date from speech like "7 of March", "March 7th",
  /// "7th March", "the seventh of march", "until march 7", "٧ مارس"
  DateTime? _parseDateFromSpeech(String speech) {
    final lower = speech.toLowerCase().trim();

    const monthMap = {
      // English
      'january': 1, 'jan': 1, 'february': 2, 'feb': 2,
      'march': 3, 'mar': 3, 'april': 4, 'apr': 4,
      'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
      'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
      // Arabic
      'يناير': 1, 'فبراير': 2, 'مارس': 3, 'ابريل': 4, 'أبريل': 4,
      'مايو': 5, 'يونيو': 6, 'يوليو': 7, 'اغسطس': 8, 'أغسطس': 8,
      'سبتمبر': 9, 'اكتوبر': 10, 'أكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
    };

    const ordinalMap = {
      'first': 1,
      'second': 2,
      'third': 3,
      'fourth': 4,
      'fifth': 5,
      'sixth': 6,
      'seventh': 7,
      'eighth': 8,
      'ninth': 9,
      'tenth': 10,
      'eleventh': 11,
      'twelfth': 12,
      'thirteenth': 13,
      'fourteenth': 14,
      'fifteenth': 15,
      'sixteenth': 16,
      'seventeenth': 17,
      'eighteenth': 18,
      'nineteenth': 19,
      'twentieth': 20,
      'twenty first': 21,
      'twenty second': 22,
      'twenty third': 23,
      'twenty fourth': 24,
      'twenty fifth': 25,
      'twenty sixth': 26,
      'twenty seventh': 27,
      'twenty eighth': 28,
      'twenty ninth': 29,
      'thirtieth': 30,
      'thirty first': 31,
    };

    // Find which month
    int? month;
    for (final entry in monthMap.entries) {
      if (lower.contains(entry.key) || speech.contains(entry.key)) {
        month = entry.value;
        break;
      }
    }
    if (month == null) return null;

    // Find the day number
    int? day;

    // Word ordinals ("seventh of march")
    for (final entry in ordinalMap.entries) {
      if (lower.contains(entry.key)) {
        day = entry.value;
        break;
      }
    }

    // Digit patterns: "7 of march", "7th march", "march 7"
    if (day == null) {
      // Convert Arabic-Indic numerals to Western
      String normalized = speech;
      const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < arabicDigits.length; i++) {
        normalized = normalized.replaceAll(arabicDigits[i], '$i');
      }

      final digitMatch = RegExp(r'(\d{1,2})').firstMatch(normalized);
      if (digitMatch != null) {
        final d = int.tryParse(digitMatch.group(1) ?? '');
        if (d != null && d >= 1 && d <= 31) day = d;
      }
    }

    if (day == null) return null;

    // Build date, roll to next year if in the past
    final now = DateTime.now();
    int year = now.year;
    var candidate = DateTime(year, month, day);
    if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
      candidate = DateTime(year + 1, month, day);
    }

    return candidate;
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
    await _tts.stop();
  }
}
