import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MedicationScanResult {
  final String? name;
  final String? frequency; // Once a day | Twice a day | Three times a day | Four times a day | Custom
  final List<String> days; // ['Every day', 'Sunday', ...]
  final String? notes;
  final String rawText;

  MedicationScanResult({
    required this.rawText,
    this.name,
    this.frequency,
    this.days = const [],
    this.notes,
  });
}

class MedicationScanService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<MedicationScanResult> scanImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    final raw = recognized.text;
    return _parse(raw);
  }

  // -------------------------
  // MAIN PARSE
  // -------------------------
  MedicationScanResult _parse(String raw) {
    final text = raw.replaceAll('\r', '\n');

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final String? name = _cleanMedicationName(_extractMedicationName(lines));

    final _FreqParse freqParse = _extractFrequency(text);

    // Days logic: if we detect schedule/duration, default to Every day + all days
    final List<String> days = <String>[];
    final bool hasDurationDays = RegExp(
      r'(\bfor\s+\d+\s+days?\b)|(\b\d+\s*days?\b)|(\bلمدة\s*\d+\s*يوم\b)',
      caseSensitive: false,
    ).hasMatch(text);

    final bool hasSchedule =
        freqParse.frequency != null || freqParse.intervalHours != null || hasDurationDays;

    if (hasSchedule) {
      days.addAll(const [
        'Every day',
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ]);
    }

    final String? notes = _extractNotes(lines);

    return MedicationScanResult(
      rawText: raw,
      name: name,
      frequency: freqParse.frequency,
      days: days,
      notes: notes,
    );
  }

  // -------------------------
  // NAME: Extraction (SCORING)
  // fixes "Fusidic..." where line contains Apply
  // -------------------------
  String? _extractMedicationName(List<String> lines) {
    final doseRegex = RegExp(
      r'(\d+(\.\d+)?\s*(mg|mcg|g|ml|%))',
      caseSensitive: false,
    );

    final formRegex = RegExp(
      r'(tablet|tab|capsule|cap|ointment|cream|gel|syrup|solution|drops|drop|spray|patch|injection|inj)',
      caseSensitive: false,
    );

    bool isHardNoise(String l) {
      final lower = l.toLowerCase();

      // IDs / admin
      if (lower.startsWith('date') ||
          lower.startsWith('mr') ||
          lower.startsWith('mr#') ||
          lower.startsWith('rx') ||
          lower.startsWith('rx#') ||
          lower.startsWith('qty') ||
          lower.startsWith('refill') ||
          lower.contains('phone') ||
          lower.contains('ph:') ||
          lower.contains('rph')) return true;

      // hospital / people (common headers)
      if (lower.contains('king abdulaziz') ||
          lower.contains('medical city') ||
          lower.contains('riyadh') ||
          RegExp(r'\bdr\b', caseSensitive: false).hasMatch(lower) ||
          lower.contains('doctor')) return true;

      // Arabic headers
      if (l.contains('الرياض') ||
          l.contains('الكمية') ||
          l.contains('التكرار') ||
          l.contains('اسم') ||
          l.contains('دكتور') ||
          l.contains('د.')) return true;

      return false;
    }

    int scoreLine(String l) {
      if (isHardNoise(l)) return -1000;

      final lower = l.toLowerCase();
      int score = 0;

      // Strong positives
      if (doseRegex.hasMatch(l)) score += 8; // 2% / 500 mg / 15 g
      if (formRegex.hasMatch(l)) score += 8; // ointment/tablet/cream/etc

      // Bonus: looks like a medication line
      if (RegExp(r'\b[a-z]{4,}\b', caseSensitive: false).hasMatch(l)) score += 2;

      // Mild negatives (NOT fatal)
      if (lower.contains('apply') || lower.contains('take')) score -= 1;
      if (lower.contains('prn') || lower.contains('needed')) score -= 1;
      if (lower.contains('every') || lower.contains('hrs') || lower.contains('hours')) score -= 1;
      if (lower.contains('for ') || lower.contains('days')) score -= 1;

      // Penalize very short junk like "Ron"
      if (l.trim().length <= 4) score -= 6;

      return score;
    }

    String? best;
    int bestScore = -999999;

    for (final l in lines) {
      final s = scoreLine(l);
      if (s > bestScore) {
        bestScore = s;
        best = l;
      }
    }

    if (best == null) return null;

    // Require at least some signal
    final hasSignal = doseRegex.hasMatch(best) || formRegex.hasMatch(best);
    if (!hasSignal) return null;

    return best;
  }

  // -------------------------
  // NAME: Cleaning (shorten + remove Apply/LASA/Arabic noise)
  // -------------------------
  String? _cleanMedicationName(String? raw) {
    if (raw == null) return null;

    String s = raw.trim();

    // remove parentheses content: (Apply, دهان) (LASA) (Oral, ...)
    s = s.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    // remove common noise words
    s = s.replaceAll(
      RegExp(r'\b(lasa|oral|apply|take|film|coated|prn)\b', caseSensitive: false),
      '',
    );

    // remove common Arabic noise words (optional)
    s = s.replaceAll(RegExp(r'(دهان|موضعي|في\s+الفم|عن\s+طريق)', caseSensitive: false), '');

    // normalize spaces and commas
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    s = s.replaceAll(RegExp(r'\s*,\s*'), ', ').trim();

    // keep useful chunk: up to dose + form (if present)
    final cut = RegExp(
      r'^(.*?\b(\d+(\.\d+)?\s*(mg|mcg|g|ml|%))\b.*?\b(tablet|tab|capsule|cap|ointment|cream|gel|syrup|solution|drops|drop|spray|patch|inj|injection)\b)',
      caseSensitive: false,
    );
    final m = cut.firstMatch(s);
    if (m != null && (m.group(1) ?? '').trim().isNotEmpty) {
      s = (m.group(1) ?? s).trim();
    }

    // ✅ OPTIONAL: If you want ONLY the drug name (no strength/form)
    // Uncomment this block:
    
    final parts = s.split(' ');
    final keep = <String>[];
    for (final p in parts) {
      if (RegExp(r'^\d').hasMatch(p) || p.contains('%')) break;
      keep.add(p);
    }
    if (keep.isNotEmpty) s = keep.join(' ');
    

    return s.trim();
  }

  // ------------------------------
  // FREQUENCY (q8h / every 8 hours / once a day / Arabic)
  // ------------------------------
  _FreqParse _extractFrequency(String text) {
    final t = text.toLowerCase();

    // every/each X hours
    final everyHours = RegExp(
      r'(every|each)\s+(\d{1,2})\s*(h|hr|hrs|hour|hours)\b',
      caseSensitive: false,
    );

    // q8h / q12h
    final qHours = RegExp(r'\bq\s*(\d{1,2})\s*h\b', caseSensitive: false);

    // Arabic: كل ٨ ساعات
    final arHours = RegExp(r'كل\s*(\d{1,2})\s*ساع', caseSensitive: false);

    int? interval;

    final m1 = everyHours.firstMatch(t);
    if (m1 != null) interval = int.tryParse(m1.group(2) ?? '');

    final m2 = qHours.firstMatch(t);
    if (interval == null && m2 != null) {
      interval = int.tryParse(m2.group(1) ?? '');
    }

    final m3 = arHours.firstMatch(text);
    if (interval == null && m3 != null) {
      interval = int.tryParse(m3.group(1) ?? '');
    }

    if (interval != null && interval > 0 && interval <= 24) {
      final rawTimes = 24 / interval;
      final timesPerDay = max(1, min(4, rawTimes.round()));

      return _FreqParse(
        frequency: _mapTimesPerDayToUi(timesPerDay),
        intervalHours: interval,
      );
    }

    // once/twice/three/four times a day
    if (RegExp(r'\bonce\s+(a|per)\s+day\b').hasMatch(t)) {
      return _FreqParse(frequency: 'Once a day');
    }
    if (RegExp(r'\btwice\s+(a|per)\s+day\b').hasMatch(t)) {
      return _FreqParse(frequency: 'Twice a day');
    }
    if (RegExp(r'\bthree\s+times\s+(a|per)\s+day\b').hasMatch(t)) {
      return _FreqParse(frequency: 'Three times a day');
    }
    if (RegExp(r'\bfour\s+times\s+(a|per)\s+day\b').hasMatch(t)) {
      return _FreqParse(frequency: 'Four times a day');
    }

    // Arabic day frequency
    if (RegExp(r'(مرة\s+واحدة|مرة)\s+يوم').hasMatch(text)) {
      return _FreqParse(frequency: 'Once a day');
    }
    if (RegExp(r'مرتين\s+يوم').hasMatch(text)) {
      return _FreqParse(frequency: 'Twice a day');
    }
    if (RegExp(r'ثلاث\s+مرات\s+يوم').hasMatch(text)) {
      return _FreqParse(frequency: 'Three times a day');
    }
    if (RegExp(r'أربع\s+مرات\s+يوم').hasMatch(text)) {
      return _FreqParse(frequency: 'Four times a day');
    }

    return _FreqParse();
  }

  String _mapTimesPerDayToUi(int timesPerDay) {
    switch (timesPerDay) {
      case 1:
        return 'Once a day';
      case 2:
        return 'Twice a day';
      case 3:
        return 'Three times a day';
      case 4:
        return 'Four times a day';
      default:
        return 'Once a day';
    }
  }

  // -------------------------
  // NOTES (instructions lines)
  // -------------------------
  String? _extractNotes(List<String> lines) {
    final picked = <String>[];

    for (final l in lines) {
      final lower = l.toLowerCase();

      final isInstruction =
          lower.contains('apply') ||
          lower.contains('take') ||
          lower.contains('once') ||
          lower.contains('twice') ||
          lower.contains('every') ||
          lower.contains('hrs') ||
          lower.contains('hours') ||
          lower.contains('needed') ||
          lower.contains('prn') ||
          lower.contains('for ') ||
          lower.contains("don't take") ||
          lower.contains('do not take') ||
          l.contains('لمدة') ||
          l.contains('يوم') ||
          l.contains('ساعات') ||
          l.contains('ساعة') ||
          l.contains('كل');

      if (isInstruction) picked.add(l);
    }

    if (picked.isEmpty) return null;
    return picked.join('\n');
  }

  void dispose() {
    _recognizer.close();
  }
}

class _FreqParse {
  final String? frequency;
  final int? intervalHours;

  _FreqParse({this.frequency, this.intervalHours});
}
