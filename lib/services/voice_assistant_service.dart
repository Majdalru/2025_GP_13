import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/voice_command.dart';
import '../models/medication.dart';
import 'medication_scheduler.dart';
import 'whisper_service.dart';

/// حطي الـ API KEY هنا
const String _openAIApiKey = 'iهنا حطي الكي';

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
    debugPrint('✅ VoiceAssistantService initialized (Whisper)');
    return true;
  }

  String getGreeting() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    if (displayName.isNotEmpty) {
      return 'Hi $displayName, how can I help you?';
    }
    return 'Hi, how can I help you today?';
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    debugPrint('🗣️ TTS: $text');

    _isSpeaking = true;
    await _tts.stop();
    await _tts.speak(text);
    _isSpeaking = false;
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  // =========================
  //  LISTEN (Whisper)
  // =========================

  /// يسجل صوت ٤ ثواني ويرسله لـ Whisper ويرجع النص
  Future<String?> listenWhisper({int seconds = 4}) async {
    final ok = await initialize();
    if (!ok) return null;

    final whisper = WhisperService();
    final file = await whisper.recordAudio(seconds: seconds);

    if (file == null) {
      debugPrint('❌ No audio file recorded');
      return null;
    }

    final text = await whisper.transcribeAudio(file, _openAIApiKey);

    if (text == null || text.trim().isEmpty) {
      debugPrint('❌ Whisper returned empty text');
      return null;
    }

    final cleaned = text.trim();
    debugPrint('🧠 Whisper text: "$cleaned"');
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

    if (answer == null || answer.trim().isEmpty) {
      await speak(
        'Sorry, I did not hear anything. You can try again later.',
      );
      return;
    }

    debugPrint('🧠 User said (conversation): "$answer"');

    final command = await analyzeSmartCommand(answer);
    if (command != null) {
      onCommand(command);
    } else {
      await speak(
        'Sorry, I could not understand. You can say medications, media, home, or SOS.',
      );
    }
  }

  Future<VoiceCommand?> analyzeSmartCommand(String text) async {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    debugPrint('🧠 analyzeSmartCommand: "$lower"');

    return analyzeCommandLocally(lower);
  }

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
      'medication',
      'medications',
      'medicine',
      'pill',
      'دواء',
      'الأدوية',
      'ادوية',
      'دوائي',
    ])) {
      return VoiceCommand.goToMedication;
    }

    if (_containsAny(lower, [
      'media',
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
      'home',
      'main page',
      'الصفحة الرئيسية',
      'الرئيسية',
      'هوم',
    ])) {
      return VoiceCommand.goToHome;
    }

    if (_containsAny(lower, [
      'settings',
      'اعدادات',
      'الإعدادات',
    ])) {
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

    return null;
  }

  bool _containsAny(String text, List<String> patterns) {
    for (final p in patterns) {
      if (text.contains(p.toLowerCase())) return true;
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
      'First, what is the medication name?',
      listenSeconds: 5,
    );
    if (name == null || name.isEmpty) {
      await speak('I did not catch the name. We will stop for now.');
      return;
    }

    final confirmName = await _askQuestion(
      'You said "$name". Is that correct? Say yes or no.',
      listenSeconds: 3,
    );
    if (_isNo(confirmName)) {
      await speak('Okay, we will cancel adding the medication.');
      return;
    }

    // 2) Days
    final daysAnswer = await _askQuestion(
      'On which days do you take $name? You can say every day, or mention specific days like Sunday and Wednesday.',
      listenSeconds: 6,
    );
    final days = parseDaysFromSpeech(daysAnswer ?? '');

    // 3) Frequency
    final freqAnswer = await _askQuestion(
      'How many times per day do you take $name? Say once, twice, three times, or four times.',
      listenSeconds: 4,
    );
    final frequency = parseFrequencyFromSpeech(freqAnswer ?? '');
    final finalFrequency = frequency ?? 'Once daily';

    // 4) First time
    final timeAnswer = await _askQuestion(
      'At what time do you usually take the first dose? For example, eight a.m. or nine thirty p.m.',
      listenSeconds: 5,
    );
    final firstTime = (timeAnswer == null || timeAnswer.isEmpty)
        ? _fallbackTime()
        : parseTimeFromSpeech(timeAnswer);
    final times = expandTimesForFrequency(firstTime, finalFrequency);

    // 5) Notes
    final notesAnswer = await _askQuestion(
      'Do you want to add any notes, like before food or after food?',
      listenSeconds: 5,
    );
    final notes = (notesAnswer != null &&
            notesAnswer.toLowerCase().trim() != 'no')
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
    );

    final docRef =
        FirebaseFirestore.instance.collection('medications').doc(elderlyId);

    try {
      await docRef.set({
        'medsList': FieldValue.arrayUnion([newMed.toMap()]),
      }, SetOptions(merge: true));

      await MedicationScheduler().scheduleAllMedications(elderlyId);

      await speak('Got it. I added $name to your medications.');
    } catch (e) {
      debugPrint('❌ Error saving medication by voice: $e');
      await speak(
        'Sorry, I could not save the medication due to an error.',
      );
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
      'Which medication do you want to delete? You can say a sentence like "delete Panadol", '
      'or just say the medication name.',
    );

    Medication? target;
    const maxTries = 3;

    for (int attempt = 1; attempt <= maxTries; attempt++) {
      final answer = await listenWhisper(seconds: 4);
      debugPrint('🎧 delete utterance (try $attempt): "$answer"');

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
          'I could not match this to any medication. Please say the medication name clearly, like "delete Panadol".',
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
    if (!_isYes(confirm)) {
      await speak('Okay, I will not delete it.');
      return;
    }

    final docRef =
        FirebaseFirestore.instance.collection('medications').doc(elderlyId);

    try {
      await docRef.update({
        'medsList': FieldValue.arrayRemove([target.toMap()]),
      });

      await MedicationScheduler().scheduleAllMedications(elderlyId);

      await speak('The medication ${target.name} has been deleted.');
    } catch (e) {
      debugPrint('❌ Error deleting medication: $e');
      await speak(
        'Sorry, I could not delete the medication because of an error.',
      );
    }
  }

  Future<Medication?> pickMedicationForEdit(String elderlyId) async {
    final ok = await initialize();
    if (!ok) return null;

    final meds = await _loadMedications(elderlyId);
    if (meds.isEmpty) {
      await speak('You do not have any medications to edit.');
      return null;
    }

    final namesText = meds.map((m) => m.name).join(', ');
    await speak(
      'You have the following medications: $namesText. '
      'Which medication do you want to edit? You can say "edit Panadol", '
      'or just say the medication name.',
    );

    Medication? target;
    const maxTries = 3;

    for (int attempt = 1; attempt <= maxTries; attempt++) {
      final answer = await listenWhisper(seconds: 4);
      debugPrint('🎧 edit utterance (try $attempt): "$answer"');

      if (answer == null || answer.trim().isEmpty) {
        if (attempt < maxTries) {
          await speak(
            'I did not hear anything. Please say the medication name, for example "edit Panadol".',
          );
          continue;
        } else {
          await speak(
            'I still could not hear a name. We will cancel editing for now.',
          );
          return null;
        }
      }

      target = _selectMedicationFromUtterance(answer, meds);

      if (target != null) break;
      if (attempt < maxTries) {
        await speak(
          'I could not match this to any medication. Please say the medication name clearly, like "edit Panadol".',
        );
      } else {
        await speak(
          'I still could not find any medication that matches. We will cancel editing for now.',
        );
        return null;
      }
    }

    if (target == null) {
      await speak('We will cancel editing for now.');
      return null;
    }

    final confirm = await _askQuestion(
      'I think you mean "${target.name}". Do you want to edit it? Say yes or no.',
      listenSeconds: 3,
    );
    if (!_isYes(confirm)) {
      await speak('Okay, I will not open the edit page.');
      return null;
    }

    await speak('Opening the edit page for ${target.name}.');
    return target;
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

    debugPrint(
      '✅ Fuzzy picked medication: ${bestMed.name} (score=$bestScore)',
    );
    return bestMed;
  }

  String _normalizeText(String input) {
    final lower = input.toLowerCase();
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

    final dp = List.generate(
      m + 1,
      (_) => List<int>.filled(n + 1, 0),
    );

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

  Future<String?> _askQuestion(
    String prompt, {
    int listenSeconds = 4,
  }) async {
    await speak(prompt);
    final answer = await listenWhisper(seconds: listenSeconds);
    debugPrint('🧠 Answer to "$prompt": "$answer"');
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
        lower.contains('am') || lower.contains('صباح') || lower.contains('صباحا');

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
      return 'Once daily';
    }
    if (lower.contains('twice') ||
        lower.contains('two times') ||
        lower.contains('مرتين')) {
      return 'Twice daily';
    }
    if (lower.contains('three') || lower.contains('ثلاث')) {
      return 'Three times daily';
    }
    if (lower.contains('four') || lower.contains('أربع')) {
      return 'Four times daily';
    }
    return null;
  }

  List<TimeOfDay> expandTimesForFrequency(
    TimeOfDay base,
    String frequencyLabel,
  ) {
    switch (frequencyLabel) {
      case 'Twice daily':
        return [base, _addHours(base, 12)];
      case 'Three times daily':
        return [base, _addHours(base, 8), _addHours(base, 16)];
      case 'Four times daily':
        return [
          base,
          _addHours(base, 6),
          _addHours(base, 12),
          _addHours(base, 18),
        ];
      case 'Once daily':
      default:
        return [base];
    }
  }

  TimeOfDay _fallbackTime() {
    return const TimeOfDay(hour: 8, minute: 0);
  }

  TimeOfDay _addHours(TimeOfDay time, int hoursToAdd) {
    final totalMinutes =
        time.hour * 60 + time.minute + hoursToAdd * 60;
    final wrappedMinutes = totalMinutes % (24 * 60);
    final h = wrappedMinutes ~/ 60;
    final m = wrappedMinutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
