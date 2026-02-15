import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Google Cloud Vision API Key
const String _cloudVisionApiKey = '';

class MedicationScanResult {
  final String? name;
  final String? frequency;
  final List<String> days;
  final String? notes;
  final String rawText;
  final int? durationDays;

  MedicationScanResult({
    required this.rawText,
    this.name,
    this.frequency,
    this.days = const [],
    this.notes,
    this.durationDays,
  });
}

class MedicationScanService {
  /// ML Kit fallback for English-only (on-device, no internet needed)
  final TextRecognizer _mlKitRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Try Cloud Vision first (Arabic + English), fall back to ML Kit (English only)
  Future<MedicationScanResult> scanImage(File imageFile) async {
    String raw = '';

    // 1) Try Cloud Vision API (handles Arabic + English)
    raw = await _cloudVisionOCR(imageFile);

    // 2) If Cloud Vision failed, fall back to ML Kit (English only, offline)
    if (raw.trim().isEmpty) {
      debugPrint(
        '\u{1F504} Cloud Vision returned empty, falling back to ML Kit...',
      );
      try {
        final inputImage = InputImage.fromFile(imageFile);
        final recognized = await _mlKitRecognizer.processImage(inputImage);
        raw = recognized.text;
        debugPrint('\u{1F4F1} ML Kit OCR result:\n$raw');
      } catch (e) {
        debugPrint('\u{274C} ML Kit fallback also failed: $e');
      }
    }

    return _parse(raw);
  }

  // ═══════════════════════════════════════════
  // CLOUD VISION API
  // ═══════════════════════════════════════════
  Future<String> _cloudVisionOCR(File imageFile) async {
    if (_cloudVisionApiKey.isEmpty) {
      debugPrint('\u{26A0}\u{FE0F} Cloud Vision API key is empty!');
      return '';
    }

    try {
      final bytes = await imageFile.readAsBytes();
      debugPrint('\u{1F4E6} Image size: ${bytes.length} bytes');
      final base64Image = base64Encode(bytes);

      final uri = Uri.parse(
        'https://vision.googleapis.com/v1/images:annotate?key=$_cloudVisionApiKey',
      );

      debugPrint('\u{1F310} Calling Cloud Vision API...');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'TEXT_DETECTION', 'maxResults': 1},
              ],
              'imageContext': {
                'languageHints': ['ar', 'en'],
              },
            },
          ],
        }),
      );

      debugPrint('\u{1F4E1} Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responses = data['responses'] as List?;

        if (responses != null && responses.isNotEmpty) {
          final error = responses[0]['error'];
          if (error != null) {
            debugPrint('\u{274C} Cloud Vision API error: $error');
            return '';
          }

          final annotations = responses[0]['textAnnotations'] as List?;
          if (annotations != null && annotations.isNotEmpty) {
            final text = annotations[0]['description'] as String? ?? '';
            debugPrint('\u{2705} OCR found text, length: ${text.length}');
            debugPrint('\u{1F4F7} Cloud Vision OCR raw:\n$text');
            return text;
          }
        }
        debugPrint('\u{26A0}\u{FE0F} No text found in image');
        return '';
      } else {
        debugPrint('\u{274C} Cloud Vision HTTP error: ${response.statusCode}');
        debugPrint(
          '\u{274C} Response: ${response.body.substring(0, min(500, response.body.length))}',
        );
        return '';
      }
    } catch (e) {
      debugPrint('\u{274C} Cloud Vision exception: $e');
      return '';
    }
  }

  // ═══════════════════════════════════════════
  // TEXT NORMALIZATION
  // ═══════════════════════════════════════════

  /// Convert Arabic-Indic numerals ٠-٩ to Western 0-9
  static String _normalizeArabicNumerals(String text) {
    const arabicDigits =
        '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    String result = text;
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }
    return result;
  }

  /// Remove Arabic diacritics (tashkeel)
  static String _stripDiacritics(String text) {
    return text.replaceAll(RegExp('[\u064B-\u065F\u0670]'), '');
  }

  /// Convert Arabic spelled-out numbers to digits
  /// e.g. "كل ست ساعات" → "كل 6 ساعات"
  static String _convertArabicWordNumbers(String text) {
    // Normalized forms (ة→ه already applied)
    final wordToDigit = {
      '\u0648\u0627\u062d\u062f\u0647': '1', // واحده
      '\u0648\u0627\u062d\u062f': '1', // واحد
      '\u0627\u062b\u0646\u064a\u0646': '2', // اثنين
      '\u0627\u062b\u0646\u062a\u064a\u0646': '2', // اثنتين
      '\u062b\u0644\u0627\u062b\u0647': '3', // ثلاثه
      '\u062b\u0644\u0627\u062b': '3', // ثلاث
      '\u0627\u0631\u0628\u0639\u0647': '4', // اربعه
      '\u0627\u0631\u0628\u0639': '4', // اربع
      '\u062e\u0645\u0633\u0647': '5', // خمسه
      '\u062e\u0645\u0633': '5', // خمس
      '\u0633\u062a\u0647': '6', // سته
      '\u0633\u062a': '6', // ست
      '\u0633\u0628\u0639\u0647': '7', // سبعه
      '\u0633\u0628\u0639': '7', // سبع
      '\u062b\u0645\u0627\u0646\u064a\u0647': '8', // ثمانيه
      '\u062b\u0645\u0627\u0646\u064a': '8', // ثماني
      '\u062b\u0645\u0627\u0646': '8', // ثمان
      '\u062a\u0633\u0639\u0647': '9', // تسعه
      '\u062a\u0633\u0639': '9', // تسع
      '\u0639\u0634\u0631\u0647': '10', // عشره
      '\u0639\u0634\u0631': '10', // عشر
    };

    String result = text;
    // Sort by length descending so longer words match first (e.g. "سته" before "ست")
    final sorted = wordToDigit.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sorted) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Full normalization pipeline
  static String _normalize(String text) {
    String s = _normalizeArabicNumerals(text);
    s = _stripDiacritics(s);
    s = s.replaceAll(RegExp('[\u0622\u0623\u0625]'), '\u0627'); // آأإ → ا
    s = s.replaceAll('\u0629', '\u0647'); // ة → ه
    s = _convertArabicWordNumbers(s);
    return s;
  }

  // ═══════════════════════════════════════════
  // MAIN PARSE
  // ═══════════════════════════════════════════
  MedicationScanResult _parse(String raw) {
    final normalized = _normalize(raw.replaceAll('\r', '\n'));
    final original = raw.replaceAll('\r', '\n');

    final lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final originalLines = original
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final String? name = _cleanMedicationName(_extractMedicationName(lines));
    final _FreqParse freqParse = _extractFrequency(normalized);
    final int? durationDays = _extractDuration(normalized);

    debugPrint(
      '\u{1F50D} Parsed: name=$name, freq=${freqParse.frequency}, duration=$durationDays',
    );

    // Days are NOT auto-filled — user picks them in the scan preview or Step 3
    final List<String> days = <String>[];

    final String? notes = _extractNotes(originalLines);

    return MedicationScanResult(
      rawText: raw,
      name: name,
      frequency: freqParse.frequency,
      days: days,
      notes: notes,
      durationDays: durationDays,
    );
  }

  // ═══════════════════════════════════════════
  // DURATION EXTRACTION
  // ═══════════════════════════════════════════
  int? _extractDuration(String text) {
    final t = text.toLowerCase();

    // --- English patterns ---
    final m1 = RegExp(
      r'(?:for|x|duration[:\s]*)\s*(\d{1,3})\s*days?\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (m1 != null) {
      final d = int.tryParse(m1.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    final m1b = RegExp(
      r'(\d{1,3})\s*days?\s*(?:course|supply|treatment|duration)?',
      caseSensitive: false,
    ).firstMatch(t);
    if (m1b != null) {
      final d = int.tryParse(m1b.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    final m2 = RegExp(
      r'(?:for|x|duration[:\s]*)\s*(\d{1,2})\s*weeks?\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (m2 != null) {
      final w = int.tryParse(m2.group(1) ?? '');
      if (w != null && w > 0 && w <= 52) return w * 7;
    }

    final m3 = RegExp(
      r'(?:for|x|duration[:\s]*)\s*(\d{1,2})\s*months?\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (m3 != null) {
      final mo = int.tryParse(m3.group(1) ?? '');
      if (mo != null && mo > 0 && mo <= 12) return mo * 30;
    }

    // --- Arabic patterns (on normalized text: ة→ه, word numbers→digits) ---
    // لمده X يوم/ايام
    final arDays = RegExp(
      '\u0644\u0645\u062f\u0647\\s*(\\d{1,3})\\s*(\u064a\u0648\u0645|\u0627\u064a\u0627\u0645)',
    ).firstMatch(text);
    if (arDays != null) {
      final d = int.tryParse(arDays.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    // X ايام / X يوم (standalone Arabic)
    final arStandalone = RegExp(
      '(\\d{1,3})\\s*(\u0627\u064a\u0627\u0645|\u064a\u0648\u0645)',
    ).firstMatch(text);
    if (arStandalone != null) {
      final d = int.tryParse(arStandalone.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    // لمده اسبوعين / اسبوع
    if (RegExp(
      '\u0644\u0645\u062f\u0647\\s*\u0627\u0633\u0628\u0648\u0639\u064a\u0646',
    ).hasMatch(text))
      return 14;
    if (RegExp(
      '\u0644\u0645\u062f\u0647\\s*\u0627\u0633\u0628\u0648\u0639',
    ).hasMatch(text))
      return 7;
    if (text.contains('\u0627\u0633\u0628\u0648\u0639\u064a\u0646')) return 14;

    // لمده شهرين / شهر
    if (RegExp(
      '\u0644\u0645\u062f\u0647\\s*\u0634\u0647\u0631\u064a\u0646',
    ).hasMatch(text))
      return 60;
    if (RegExp('\u0644\u0645\u062f\u0647\\s*\u0634\u0647\u0631').hasMatch(text))
      return 30;

    return null;
  }

  // ═══════════════════════════════════════════
  // FREQUENCY EXTRACTION
  // ═══════════════════════════════════════════
  _FreqParse _extractFrequency(String text) {
    final t = text.toLowerCase();

    // --- English: every X hours / qXh ---
    int? interval;

    final m1 = RegExp(
      r'(every|each)\s+(\d{1,2})\s*(h|hr|hrs|hour|hours)\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (m1 != null) interval = int.tryParse(m1.group(2) ?? '');

    final m2 = RegExp(
      r'\bq\s*(\d{1,2})\s*h\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (interval == null && m2 != null)
      interval = int.tryParse(m2.group(1) ?? '');

    // Arabic: كل X ساع (normalized: word numbers already converted to digits)
    final m3 = RegExp(
      '\u0643\u0644\\s*(\\d{1,2})\\s*\u0633\u0627\u0639',
    ).firstMatch(text);
    if (interval == null && m3 != null)
      interval = int.tryParse(m3.group(1) ?? '');

    if (interval != null && interval > 0 && interval <= 24) {
      final timesPerDay = max(1, min(4, (24 / interval).round()));
      return _FreqParse(
        frequency: _mapTimesPerDayToUi(timesPerDay),
        intervalHours: interval,
      );
    }

    // --- English: once/twice/three/four times a day ---
    if (RegExp(r'\bonce\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Once a day');
    if (RegExp(r'\btwice\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Twice a day');
    if (RegExp(r'\bthree\s+times\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Three times a day');
    if (RegExp(r'\bfour\s+times\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Four times a day');

    // --- Arabic frequency (normalized: ة→ه, word numbers→digits) ---
    final dailySuffix =
        '(\u064a\u0648\u0645|\u064a\u0648\u0645\u064a\u0627|\u0641\u064a\\s+\u0627\u0644\u064a\u0648\u0645|\u0628\u0627\u0644\u064a\u0648\u0645)';

    // مره واحده / مره يوميا / مره في اليوم
    if (RegExp(
      '(\u0645\u0631\u0647\\s+\u0648\u0627\u062d\u062f\u0647|\u0645\u0631\u0647)\\s+$dailySuffix',
    ).hasMatch(text)) {
      return _FreqParse(frequency: 'Once a day');
    }
    // مرتين يوميا / مرتين في اليوم
    if (RegExp(
      '\u0645\u0631\u062a\u064a\u0646\\s+$dailySuffix',
    ).hasMatch(text)) {
      return _FreqParse(frequency: 'Twice a day');
    }
    // ثلاث/3 مرات يوميا
    if (RegExp(
      '(\u062b\u0644\u0627\u062b|3)\\s*\u0645\u0631\u0627\u062a\\s*$dailySuffix',
    ).hasMatch(text)) {
      return _FreqParse(frequency: 'Three times a day');
    }
    // اربع/4 مرات يوميا
    if (RegExp(
      '(\u0627\u0631\u0628\u0639|4)\\s*\u0645\u0631\u0627\u062a\\s*$dailySuffix',
    ).hasMatch(text)) {
      return _FreqParse(frequency: 'Four times a day');
    }

    // X مرات (with digit, no daily suffix needed)
    final arNumTimes = RegExp(
      '(\\d)\\s*\u0645\u0631\u0627\u062a',
    ).firstMatch(text);
    if (arNumTimes != null) {
      final n = int.tryParse(arNumTimes.group(1) ?? '');
      if (n != null && n >= 1 && n <= 4)
        return _FreqParse(frequency: _mapTimesPerDayToUi(n));
    }

    // مره كل X ساعات
    final arEvery = RegExp(
      '\u0645\u0631\u0647\\s+\u0643\u0644\\s*(\\d{1,2})\\s*\u0633\u0627\u0639',
    ).firstMatch(text);
    if (arEvery != null) {
      final hr = int.tryParse(arEvery.group(1) ?? '');
      if (hr != null && hr > 0 && hr <= 24) {
        return _FreqParse(
          frequency: _mapTimesPerDayToUi(max(1, min(4, (24 / hr).round()))),
          intervalHours: hr,
        );
      }
    }

    // Standalone مرتين (without suffix) → likely twice a day
    if (text.contains('\u0645\u0631\u062a\u064a\u0646') &&
        !text.contains('\u0627\u0633\u0628\u0648\u0639')) {
      return _FreqParse(frequency: 'Twice a day');
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

  // ═══════════════════════════════════════════
  // NAME: Extraction (SCORING)
  // ═══════════════════════════════════════════
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

      if (lower.startsWith('date') ||
          lower.startsWith('mr') ||
          lower.startsWith('mr#') ||
          lower.startsWith('rx') ||
          lower.startsWith('rx#') ||
          lower.startsWith('qty') ||
          lower.startsWith('refill') ||
          lower.contains('phone') ||
          lower.contains('ph:') ||
          lower.contains('rph'))
        return true;

      if (lower.contains('king abdulaziz') ||
          lower.contains('medical city') ||
          lower.contains('riyadh') ||
          RegExp(r'\bdr\b', caseSensitive: false).hasMatch(lower) ||
          lower.contains('doctor'))
        return true;

      // Arabic noise (normalized)
      if (l.contains('\u0627\u0644\u0631\u064a\u0627\u0636') ||
          l.contains('\u0627\u0644\u0643\u0645\u064a\u0647') ||
          l.contains('\u0627\u0644\u062a\u0643\u0631\u0627\u0631') ||
          l.contains('\u0627\u0633\u0645') ||
          l.contains('\u062f\u0643\u062a\u0648\u0631') ||
          l.contains('\u062f.') ||
          l.contains('\u0645\u0633\u062a\u0634\u0641\u0649') ||
          l.contains('\u0645\u062f\u064a\u0646\u0647'))
        return true;

      return false;
    }

    int scoreLine(String l) {
      if (isHardNoise(l)) return -1000;
      final lower = l.toLowerCase();
      int score = 0;

      if (doseRegex.hasMatch(l)) score += 8;
      if (formRegex.hasMatch(l)) score += 8;
      if (RegExp(r'\b[a-z]{4,}\b', caseSensitive: false).hasMatch(l))
        score += 2;
      if (lower.contains('apply') || lower.contains('take')) score -= 1;
      if (lower.contains('prn') || lower.contains('needed')) score -= 1;
      if (lower.contains('every') ||
          lower.contains('hrs') ||
          lower.contains('hours'))
        score -= 1;
      if (lower.contains('for ') || lower.contains('days')) score -= 1;

      // Penalize Arabic instruction lines
      if (l.contains('\u0645\u0631\u0647') ||
          l.contains('\u0645\u0631\u062a\u064a\u0646') ||
          l.contains('\u0643\u0644') ||
          l.contains('\u0644\u0645\u062f\u0647') ||
          l.contains('\u064a\u0648\u0645') ||
          l.contains('\u0633\u0627\u0639'))
        score -= 2;

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
    if (!doseRegex.hasMatch(best) && !formRegex.hasMatch(best)) return null;
    return best;
  }

  // ═══════════════════════════════════════════
  // NAME: Cleaning
  // ═══════════════════════════════════════════
  String? _cleanMedicationName(String? raw) {
    if (raw == null) return null;
    String s = raw.trim();

    s = s.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    s = s.replaceAll(
      RegExp(
        r'\b(lasa|oral|apply|take|film|coated|prn)\b',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(
      RegExp(
        '(\u062f\u0647\u0627\u0646|\u0645\u0648\u0636\u0639\u064a|\u0641\u064a\\s+\u0627\u0644\u0641\u0645|\u0639\u0646\\s+\u0637\u0631\u064a\u0642)',
      ),
      '',
    );

    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    s = s.replaceAll(RegExp(r'\s*,\s*'), ', ').trim();

    final cut = RegExp(
      r'^(.*?\b(\d+(\.\d+)?\s*(mg|mcg|g|ml|%))\b.*?\b(tablet|tab|capsule|cap|ointment|cream|gel|syrup|solution|drops|drop|spray|patch|inj|injection)\b)',
      caseSensitive: false,
    );
    final m = cut.firstMatch(s);
    if (m != null && (m.group(1) ?? '').trim().isNotEmpty) {
      s = (m.group(1) ?? s).trim();
    }

    final parts = s.split(' ');
    final keep = <String>[];
    for (final p in parts) {
      if (RegExp(r'^\d').hasMatch(p) || p.contains('%')) break;
      keep.add(p);
    }
    if (keep.isNotEmpty) s = keep.join(' ');
    return s.trim();
  }

  // ═══════════════════════════════════════════
  // NOTES EXTRACTION
  // ═══════════════════════════════════════════
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
          l.contains('\u0644\u0645\u062f\u0629') ||
          l.contains('\u0644\u0645\u062f\u0647') ||
          l.contains('\u064a\u0648\u0645') ||
          l.contains('\u0633\u0627\u0639') ||
          l.contains('\u0643\u0644') ||
          l.contains('\u0645\u0631\u0629') ||
          l.contains('\u0645\u0631\u0647') ||
          l.contains('\u0645\u0631\u062a\u064a\u0646') ||
          l.contains('\u062f\u0647\u0627\u0646') ||
          l.contains('\u0642\u0628\u0644') ||
          l.contains('\u0628\u0639\u062f') ||
          l.contains('\u0627\u0644\u0623\u0643\u0644') ||
          l.contains('\u0627\u0644\u0627\u0643\u0644') ||
          l.contains('\u0645\u0639\u062f\u0629') ||
          l.contains('\u0645\u0639\u062f\u0647') ||
          l.contains('\u0627\u0644\u0645\u0627\u0621');

      if (isInstruction) picked.add(l);
    }

    if (picked.isEmpty) return null;
    return picked.join('\n');
  }

  void dispose() {
    _mlKitRecognizer.close();
  }
}

class _FreqParse {
  final String? frequency;
  final int? intervalHours;
  _FreqParse({this.frequency, this.intervalHours});
}
