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
  final String? doseForm;
  final String? doseStrength; // product concentration: "500 mg"
  final String? patientDose; // patient instruction: "1 tablet", "2 drops"
  final List<String> missingFields; // e.g. ['Medication Name', 'Frequency']
  final bool isLikelyMedLabel; // false if no med-related text found

  MedicationScanResult({
    required this.rawText,
    this.name,
    this.frequency,
    this.days = const [],
    this.notes,
    this.durationDays,
    this.doseForm,
    this.doseStrength,
    this.patientDose,
    this.missingFields = const [],
    this.isLikelyMedLabel = true,
  });
}

class MedicationScanService {
  final TextRecognizer _mlKitRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<MedicationScanResult> scanImage(File imageFile) async {
    String raw = '';

    raw = await _cloudVisionOCR(imageFile);

    if (raw.trim().isEmpty) {
      debugPrint('🔄 Cloud Vision returned empty, falling back to ML Kit...');
      try {
        final inputImage = InputImage.fromFile(imageFile);
        final recognized = await _mlKitRecognizer.processImage(inputImage);
        raw = recognized.text;
        debugPrint('📱 ML Kit OCR result:\n$raw');
      } catch (e) {
        debugPrint('❌ ML Kit fallback also failed: $e');
      }
    }

    return _parse(raw);
  }

  // ═══════════════════════════════════════════
  // CLOUD VISION API
  // ═══════════════════════════════════════════
  Future<String> _cloudVisionOCR(File imageFile) async {
    if (_cloudVisionApiKey.isEmpty) {
      debugPrint('⚠️ Cloud Vision API key is empty!');
      return '';
    }

    try {
      final bytes = await imageFile.readAsBytes();
      debugPrint('📦 Image size: ${bytes.length} bytes');
      final base64Image = base64Encode(bytes);

      final uri = Uri.parse(
        'https://vision.googleapis.com/v1/images:annotate?key=$_cloudVisionApiKey',
      );

      debugPrint('🌐 Calling Cloud Vision API...');
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

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responses = data['responses'] as List?;

        if (responses != null && responses.isNotEmpty) {
          final error = responses[0]['error'];
          if (error != null) {
            debugPrint('❌ Cloud Vision API error: $error');
            return '';
          }

          final annotations = responses[0]['textAnnotations'] as List?;
          if (annotations != null && annotations.isNotEmpty) {
            final text = annotations[0]['description'] as String? ?? '';
            debugPrint('✅ OCR found text, length: ${text.length}');
            debugPrint('📷 Cloud Vision OCR raw:\n$text');
            return text;
          }
        }
        debugPrint('⚠️ No text found in image');
        return '';
      } else {
        debugPrint('❌ Cloud Vision HTTP error: ${response.statusCode}');
        debugPrint(
          '❌ Response: ${response.body.substring(0, min(500, response.body.length))}',
        );
        return '';
      }
    } catch (e) {
      debugPrint('❌ Cloud Vision exception: $e');
      return '';
    }
  }

  // ═══════════════════════════════════════════
  // TEXT NORMALIZATION
  // ═══════════════════════════════════════════

  static String _normalizeArabicNumerals(String text) {
    const arabicDigits =
        '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    String result = text;
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }
    return result;
  }

  static String _stripDiacritics(String text) {
    return text.replaceAll(RegExp('[\u064B-\u065F\u0670]'), '');
  }

  static String _convertArabicWordNumbers(String text) {
    final wordToDigit = {
      '\u0648\u0627\u062d\u062f\u0647': '1',
      '\u0648\u0627\u062d\u062f': '1',
      '\u0627\u062b\u0646\u064a\u0646': '2',
      '\u0627\u062b\u0646\u062a\u064a\u0646': '2',
      '\u062b\u0644\u0627\u062b\u0647': '3',
      '\u062b\u0644\u0627\u062b': '3',
      '\u0627\u0631\u0628\u0639\u0647': '4',
      '\u0627\u0631\u0628\u0639': '4',
      '\u062e\u0645\u0633\u0647': '5',
      '\u062e\u0645\u0633': '5',
      '\u0633\u062a\u0647': '6',
      '\u0633\u062a': '6',
      '\u0633\u0628\u0639\u0647': '7',
      '\u0633\u0628\u0639': '7',
      '\u062b\u0645\u0627\u0646\u064a\u0647': '8',
      '\u062b\u0645\u0627\u0646\u064a': '8',
      '\u062b\u0645\u0627\u0646': '8',
      '\u062a\u0633\u0639\u0647': '9',
      '\u062a\u0633\u0639': '9',
      '\u0639\u0634\u0631\u0647': '10',
      '\u0639\u0634\u0631': '10',
    };

    String result = text;
    final sorted = wordToDigit.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in sorted) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _normalize(String text) {
    String s = _normalizeArabicNumerals(text);
    s = _stripDiacritics(s);
    s = s.replaceAll(RegExp('[\u0622\u0623\u0625]'), '\u0627');
    s = s.replaceAll('\u0629', '\u0647');
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
    final String? doseForm = _extractDoseForm(normalized);
    final String? doseStrength = _extractDoseStrength(normalized);
    final _PatientDoseParse patientDoseParse = _extractPatientDose(normalized);

    debugPrint(
      '🔍 Parsed: name=$name, freq=${freqParse.frequency}, '
      'duration=$durationDays, form=$doseForm, strength=$doseStrength, '
      'patientDose=${patientDoseParse.dose}, patientForm=${patientDoseParse.form}',
    );

    final List<String> days = <String>[];
    final String? notes = _extractNotes(originalLines);

    // ── Determine if this looks like a medication label ──
    final bool isLikelyMedLabel = _checkIsLikelyMedLabel(normalized);

    // ── Compute missing fields ──
    final List<String> missingFields = [];
    if (name == null || name.isEmpty) missingFields.add('Medication Name');
    // Use patient dose form if doseForm wasn't found from product keywords
    final effectiveForm = doseForm ?? patientDoseParse.form;
    if (effectiveForm == null) missingFields.add('Medication Form');
    if (doseStrength == null && patientDoseParse.dose == null) {
      missingFields.add('Dose / Strength');
    }
    if (freqParse.frequency == null) missingFields.add('Frequency');
    if (durationDays == null) missingFields.add('Duration');

    return MedicationScanResult(
      rawText: raw,
      name: name,
      frequency: freqParse.frequency,
      days: days,
      notes: notes,
      durationDays: durationDays,
      doseForm: effectiveForm,
      doseStrength: doseStrength,
      patientDose: patientDoseParse.dose,
      missingFields: missingFields,
      isLikelyMedLabel: isLikelyMedLabel,
    );
  }

  // ═══════════════════════════════════════════
  // IS LIKELY MEDICATION LABEL?
  // ═══════════════════════════════════════════
  bool _checkIsLikelyMedLabel(String text) {
    final t = text.toLowerCase();
    int score = 0;

    // English medication keywords
    if (RegExp(
      r'\b(mg|mcg|ml|tablet|capsule|syrup|cream|ointment|drops|spray|injection|dose|rx)\b',
      caseSensitive: false,
    ).hasMatch(t))
      score += 3;
    if (RegExp(
      r'\b(take|apply|once|twice|daily|every|oral|topical|prn)\b',
      caseSensitive: false,
    ).hasMatch(t))
      score += 2;
    if (RegExp(
      r'\b(pharmacy|hospital|clinic|prescription|refill|qty|dispense)\b',
      caseSensitive: false,
    ).hasMatch(t))
      score += 2;
    if (RegExp(r'\d+\s*(mg|mcg|ml|g|%)\b', caseSensitive: false).hasMatch(t))
      score += 3;

    // Arabic medication keywords
    // حبوب/اقراص/كبسول/شراب/مرهم/قطره/بخاخ/حقنه
    if (text.contains('\u062d\u0628\u0648\u0628') ||
        text.contains('\u0627\u0642\u0631\u0627\u0635') ||
        text.contains('\u0643\u0628\u0633\u0648\u0644') ||
        text.contains('\u0634\u0631\u0627\u0628') ||
        text.contains('\u0645\u0631\u0647\u0645') ||
        text.contains('\u0642\u0637\u0631\u0647') ||
        text.contains('\u0628\u062e\u0627\u062e') ||
        text.contains('\u062d\u0642\u0646\u0647'))
      score += 3;
    // مره/مرتين/يوميا/يوم
    if (text.contains('\u0645\u0631\u0647') ||
        text.contains('\u0645\u0631\u062a\u064a\u0646') ||
        text.contains('\u064a\u0648\u0645\u064a\u0627') ||
        text.contains('\u064a\u0648\u0645'))
      score += 2;
    // حبه (pill/tablet)
    if (text.contains('\u062d\u0628\u0647')) score += 2;
    // صيدليه/مستشفى/عياده
    if (text.contains('\u0635\u064a\u062f\u0644\u064a\u0647') ||
        text.contains('\u0645\u0633\u062a\u0634\u0641\u0649') ||
        text.contains('\u0639\u064a\u0627\u062f\u0647'))
      score += 1;

    return score >= 2;
  }

  // ═══════════════════════════════════════════
  // PATIENT DOSE EXTRACTION
  //   Extracts the *patient's* dosage instruction
  //   e.g. "take 1 tablet", "حبه واحده", "2 capsules"
  //   This is DIFFERENT from product strength (500mg)
  // ═══════════════════════════════════════════
  _PatientDoseParse _extractPatientDose(String text) {
    final t = text.toLowerCase();

    // ── English: "take 1 tablet", "2 capsules", "one tablet" ──
    final enWordNums = <String, String>{
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'half': '0.5',
      'a': '1',
    };

    // Pattern: (take|use)? (number|word) (form)
    final enDoseRegex = RegExp(
      r'(?:take|use|apply)?\s*(\d+(?:\.\d+)?|one|two|three|four|half|a)\s+'
      r'(tablet|tablets|tab|tabs|capsule|capsules|cap|caps|pill|pills|'
      r'drop|drops|puff|puffs|spray|sprays|ml|teaspoon|tablespoon|'
      r'suppository|suppositories|patch|patches|sachet|sachets)',
      caseSensitive: false,
    );
    final enMatch = enDoseRegex.firstMatch(t);
    if (enMatch != null) {
      final rawNum = enMatch.group(1)!.toLowerCase();
      final amount = enWordNums[rawNum] ?? rawNum;
      final rawForm = enMatch.group(2)!.toLowerCase();
      final form = _mapEnglishFormWord(rawForm);
      return _PatientDoseParse(
        dose: '$amount ${_singularize(rawForm)}',
        form: form,
      );
    }

    // ── Arabic patient dose patterns (normalized: ة→ه) ──

    // حبه واحده / ١ حبه / حبتين / ٢ حبات
    // Match: (number)? حبه|حبتين|حبات
    final arPillRegex = RegExp(
      '(\\d+)?\\s*(\u062d\u0628\u0647|\u062d\u0628\u062a\u064a\u0646|\u062d\u0628\u0627\u062a)',
    );
    final arPillMatch = arPillRegex.firstMatch(text);
    if (arPillMatch != null) {
      final numStr = arPillMatch.group(1);
      final word = arPillMatch.group(2) ?? '';
      String amount;
      if (numStr != null) {
        amount = numStr;
      } else if (word.contains('\u062d\u0628\u062a\u064a\u0646')) {
        amount = '2'; // حبتين = 2
      } else {
        // Check for واحده before حبه
        if (RegExp(
              '\u062d\u0628\u0647\\s+\u0648\u0627\u062d\u062f\u0647',
            ).hasMatch(text) ||
            RegExp(
              '\u0648\u0627\u062d\u062f\u0647\\s+\u062d\u0628\u0647',
            ).hasMatch(text)) {
          amount = '1';
        } else {
          amount = '1';
        }
      }
      return _PatientDoseParse(dose: '$amount capsule', form: 'Capsule');
    }

    // قرص واحد / اقراص / ٢ قرص
    final arTabletRegex = RegExp(
      '(\\d+)?\\s*(\u0642\u0631\u0635|\u0627\u0642\u0631\u0627\u0635|\u0642\u0631\u0635\u064a\u0646)',
    );
    final arTabletMatch = arTabletRegex.firstMatch(text);
    if (arTabletMatch != null) {
      final numStr = arTabletMatch.group(1);
      final word = arTabletMatch.group(2) ?? '';
      String amount;
      if (numStr != null) {
        amount = numStr;
      } else if (word.contains('\u0642\u0631\u0635\u064a\u0646')) {
        amount = '2';
      } else {
        amount = '1';
      }
      return _PatientDoseParse(dose: '$amount tablet', form: 'Capsule');
    }

    // كبسوله واحده / كبسولتين / ٢ كبسولات
    final arCapsuleRegex = RegExp(
      '(\\d+)?\\s*(\u0643\u0628\u0633\u0648\u0644\u0647|\u0643\u0628\u0633\u0648\u0644\u062a\u064a\u0646|\u0643\u0628\u0633\u0648\u0644\u0627\u062a)',
    );
    final arCapsMatch = arCapsuleRegex.firstMatch(text);
    if (arCapsMatch != null) {
      final numStr = arCapsMatch.group(1);
      final word = arCapsMatch.group(2) ?? '';
      String amount;
      if (numStr != null) {
        amount = numStr;
      } else if (word.contains(
        '\u0643\u0628\u0633\u0648\u0644\u062a\u064a\u0646',
      )) {
        amount = '2';
      } else {
        amount = '1';
      }
      return _PatientDoseParse(dose: '$amount capsule', form: 'Capsule');
    }

    // قطره / قطرتين / ٢ قطرات (drops)
    final arDropsRegex = RegExp(
      '(\\d+)?\\s*(\u0642\u0637\u0631\u0647|\u0642\u0637\u0631\u062a\u064a\u0646|\u0642\u0637\u0631\u0627\u062a)',
    );
    final arDropsMatch = arDropsRegex.firstMatch(text);
    if (arDropsMatch != null) {
      final numStr = arDropsMatch.group(1);
      final word = arDropsMatch.group(2) ?? '';
      String amount;
      if (numStr != null) {
        amount = numStr;
      } else if (word.contains('\u0642\u0637\u0631\u062a\u064a\u0646')) {
        amount = '2';
      } else {
        amount = '1';
      }
      // Form will be determined by context (eye/ear/nasal) in _extractDoseForm
      return _PatientDoseParse(dose: '$amount drop');
    }

    // ملعقه / ملعقتين / ٢ ملاعق (spoon → syrup)
    final arSpoonRegex = RegExp(
      '(\\d+)?\\s*(\u0645\u0644\u0639\u0642\u0647|\u0645\u0644\u0639\u0642\u062a\u064a\u0646|\u0645\u0644\u0627\u0639\u0642)',
    );
    final arSpoonMatch = arSpoonRegex.firstMatch(text);
    if (arSpoonMatch != null) {
      final numStr = arSpoonMatch.group(1);
      final word = arSpoonMatch.group(2) ?? '';
      String amount;
      if (numStr != null) {
        amount = numStr;
      } else if (word.contains('\u0645\u0644\u0639\u0642\u062a\u064a\u0646')) {
        amount = '2';
      } else {
        amount = '1';
      }
      return _PatientDoseParse(dose: '$amount spoon', form: 'Syrup');
    }

    // بخه / بختين / ٢ بخات (puff → inhaler/nasal)
    final arPuffRegex = RegExp(
      '(\\d+)?\\s*(\u0628\u062e\u0647|\u0628\u062e\u062a\u064a\u0646|\u0628\u062e\u0627\u062a)',
    );
    final arPuffMatch = arPuffRegex.firstMatch(text);
    if (arPuffMatch != null) {
      final numStr = arPuffMatch.group(1);
      final word = arPuffMatch.group(2) ?? '';
      String amount;
      if (numStr != null) {
        amount = numStr;
      } else if (word.contains('\u0628\u062e\u062a\u064a\u0646')) {
        amount = '2';
      } else {
        amount = '1';
      }
      return _PatientDoseParse(dose: '$amount puff');
    }

    // Arabic ml dosage: ٥ مل
    final arMlRegex = RegExp('(\\d+(?:\\.\\d+)?)\\s*\u0645\u0644(?!\\u063a)');
    final arMlMatch = arMlRegex.firstMatch(text);
    if (arMlMatch != null) {
      final amount = arMlMatch.group(1) ?? '';
      return _PatientDoseParse(dose: '$amount ml', form: 'Syrup');
    }

    return _PatientDoseParse();
  }

  /// Map English form words to our UI labels
  String? _mapEnglishFormWord(String word) {
    final w = word.toLowerCase().replaceAll(RegExp(r's$'), ''); // remove plural
    switch (w) {
      case 'tablet':
      case 'tab':
      case 'pill':
        return 'Capsule';
      case 'capsule':
      case 'cap':
        return 'Capsule';
      case 'drop':
        return null; // could be eye/ear/nasal
      case 'puff':
      case 'spray':
        return null; // could be inhaler/nasal
      case 'ml':
      case 'teaspoon':
      case 'tablespoon':
        return 'Syrup';
      case 'suppository':
        return null;
      case 'patch':
        return null;
      case 'sachet':
        return null;
      default:
        return null;
    }
  }

  String _singularize(String word) {
    final w = word.toLowerCase();
    if (w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.endsWith('ses') || w.endsWith('ches'))
      return w.substring(0, w.length - 2);
    if (w.endsWith('s') && !w.endsWith('ss'))
      return w.substring(0, w.length - 1);
    return w;
  }

  String? _extractDoseForm(String text) {
    final t = text.toLowerCase();

    // English form keywords → mapped to our UI labels
    final formPatterns = <String, List<String>>{
      'Tablet': [r'\b(tablet|tab|tabs|film.?coated)\b'],
      'Capsule': [r'\b(capsule|cap|caps)\b'],
      'Syrup': [r'\b(syrup|suspension|oral\s*solution|elixir|liquid)\b'],
      'Cream/Ointment': [r'\b(cream|ointment|oint|topical|gel|lotion)\b'],
      'Eye Drops': [r'\b(eye\s*drops?|ophthalmic)\b'],
      'Ear Drops': [r'\b(ear\s*drops?|otic)\b'],
      'Nasal Spray': [r'\b(nasal\s*spray|nasal\s*drops?)\b'],
      'Inhaler': [r'\b(inhaler|inhalation|puff|mdi|hfa)\b'],
      'Injection': [
        r'\b(injection|inj|injectable|syringe|pen|subcutaneous|intramuscular|iv\b)\b',
      ],
      'Patch': [r'\b(patch|transdermal)\b'],
      'Suppository': [r'\b(suppository|suppositories|rectal)\b'],
      'Powder/Sachet': [r'\b(powder|sachet|granules|effervescent)\b'],
    };

    for (final entry in formPatterns.entries) {
      for (final pattern in entry.value) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(t)) {
          return entry.key;
        }
      }
    }

    // Arabic form keywords (on normalized text: ة→ه)
    // أقراص / حبوب → Tablet
    if (t.contains('\u0627\u0642\u0631\u0627\u0635') ||
        t.contains('\u062d\u0628\u0648\u0628'))
      return 'Tablet';
    // كبسولات / كبسوله → Capsule
    if (t.contains('\u0643\u0628\u0633\u0648\u0644')) return 'Capsule';
    // شراب / محلول → Syrup
    if (t.contains('\u0634\u0631\u0627\u0628') ||
        t.contains('\u0645\u062d\u0644\u0648\u0644'))
      return 'Syrup';
    // كريم / مرهم / جل → Cream/Ointment
    if (t.contains('\u0643\u0631\u064a\u0645') ||
        t.contains('\u0645\u0631\u0647\u0645') ||
        t.contains('\u062c\u0644'))
      return 'Cream/Ointment';
    // قطره عين → Eye Drops
    if (t.contains('\u0642\u0637\u0631\u0647') &&
        t.contains('\u0639\u064a\u0646'))
      return 'Eye Drops';
    // قطره اذن → Ear Drops
    if (t.contains('\u0642\u0637\u0631\u0647') &&
        t.contains('\u0627\u0630\u0646'))
      return 'Ear Drops';
    // بخاخ انف → Nasal Spray
    if (t.contains('\u0628\u062e\u0627\u062e') &&
        t.contains('\u0627\u0646\u0641'))
      return 'Nasal Spray';
    // بخاخ (generic) → Inhaler
    if (t.contains('\u0628\u062e\u0627\u062e')) return 'Inhaler';
    // حقنه / ابره → Injection
    if (t.contains('\u062d\u0642\u0646\u0647') ||
        t.contains('\u0627\u0628\u0631\u0647'))
      return 'Injection';
    // لصقه → Patch
    if (t.contains('\u0644\u0635\u0642\u0647')) return 'Patch';
    // تحاميل → Suppository
    if (t.contains('\u062a\u062d\u0627\u0645\u064a\u0644'))
      return 'Suppository';
    // بودره / اكياس → Powder/Sachet
    if (t.contains('\u0628\u0648\u062f\u0631\u0647') ||
        t.contains('\u0627\u0643\u064a\u0627\u0633'))
      return 'Powder/Sachet';

    return null;
  }

  // ═══════════════════════════════════════════
  // DOSE STRENGTH EXTRACTION (NEW)
  // ═══════════════════════════════════════════
  String? _extractDoseStrength(String text) {
    // Match patterns like: 500mg, 500 mg, 0.5%, 250mcg, 10ml, 5 g, 100 units
    final strengthRegex = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|%|units?|iu)\b',
      caseSensitive: false,
    );

    final match = strengthRegex.firstMatch(text);
    if (match != null) {
      final amount = match.group(1) ?? '';
      final unit = (match.group(2) ?? '').toLowerCase();
      return '$amount $unit'.trim();
    }

    // Arabic: ملغ (milligram), مل (ml)
    final arStrength = RegExp(
      r'(\d+(?:\.\d+)?)\s*(\u0645\u0644\u063a|\u0645\u0644|\u0648\u062d\u062f\u0647)',
    ).firstMatch(text);
    if (arStrength != null) {
      final amount = arStrength.group(1) ?? '';
      final unit = arStrength.group(2) ?? '';
      final mappedUnit = unit.contains('\u0645\u0644\u063a')
          ? 'mg'
          : unit.contains('\u0645\u0644')
          ? 'ml'
          : 'units';
      return '$amount $mappedUnit'.trim();
    }

    return null;
  }

  // ═══════════════════════════════════════════
  // DURATION EXTRACTION
  // ═══════════════════════════════════════════
  int? _extractDuration(String text) {
    final t = text.toLowerCase();

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

    // Arabic
    final arDays = RegExp(
      '\u0644\u0645\u062f\u0647\\s*(\\d{1,3})\\s*(\u064a\u0648\u0645|\u0627\u064a\u0627\u0645)',
    ).firstMatch(text);
    if (arDays != null) {
      final d = int.tryParse(arDays.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    final arStandalone = RegExp(
      '(\\d{1,3})\\s*(\u0627\u064a\u0627\u0645|\u064a\u0648\u0645)',
    ).firstMatch(text);
    if (arStandalone != null) {
      final d = int.tryParse(arStandalone.group(1) ?? '');
      if (d != null && d > 0 && d <= 365) return d;
    }

    if (RegExp(
      '\u0644\u0645\u062f\u0647\\s*\u0627\u0633\u0628\u0648\u0639\u064a\u0646',
    ).hasMatch(text))
      return 14;
    if (RegExp(
      '\u0644\u0645\u062f\u0647\\s*\u0627\u0633\u0628\u0648\u0639',
    ).hasMatch(text))
      return 7;
    if (text.contains('\u0627\u0633\u0628\u0648\u0639\u064a\u0646')) return 14;

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

    if (RegExp(r'\bonce\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Once a day');
    if (RegExp(r'\btwice\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Twice a day');
    if (RegExp(r'\bthree\s+times\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Three times a day');
    if (RegExp(r'\bfour\s+times\s+(a|per)\s+day\b').hasMatch(t))
      return _FreqParse(frequency: 'Four times a day');

    final dailySuffix =
        '(\u064a\u0648\u0645|\u064a\u0648\u0645\u064a\u0627|\u0641\u064a\\s+\u0627\u0644\u064a\u0648\u0645|\u0628\u0627\u0644\u064a\u0648\u0645)';

    if (RegExp(
      '(\u0645\u0631\u0647\\s+\u0648\u0627\u062d\u062f\u0647|\u0645\u0631\u0647)\\s+$dailySuffix',
    ).hasMatch(text))
      return _FreqParse(frequency: 'Once a day');
    if (RegExp('\u0645\u0631\u062a\u064a\u0646\\s+$dailySuffix').hasMatch(text))
      return _FreqParse(frequency: 'Twice a day');
    if (RegExp(
      '(\u062b\u0644\u0627\u062b|3)\\s*\u0645\u0631\u0627\u062a\\s*$dailySuffix',
    ).hasMatch(text))
      return _FreqParse(frequency: 'Three times a day');
    if (RegExp(
      '(\u0627\u0631\u0628\u0639|4)\\s*\u0645\u0631\u0627\u062a\\s*$dailySuffix',
    ).hasMatch(text))
      return _FreqParse(frequency: 'Four times a day');

    final arNumTimes = RegExp(
      '(\\d)\\s*\u0645\u0631\u0627\u062a',
    ).firstMatch(text);
    if (arNumTimes != null) {
      final n = int.tryParse(arNumTimes.group(1) ?? '');
      if (n != null && n >= 1 && n <= 4)
        return _FreqParse(frequency: _mapTimesPerDayToUi(n));
    }

    final arEvery = RegExp(
      '\u0645\u0631\u0647\\s+\u0643\u0644\\s*(\\d{1,2})\\s*\u0633\u0627\u0639',
    ).firstMatch(text);
    if (arEvery != null) {
      final hr = int.tryParse(arEvery.group(1) ?? '');
      if (hr != null && hr > 0 && hr <= 24)
        return _FreqParse(
          frequency: _mapTimesPerDayToUi(max(1, min(4, (24 / hr).round()))),
          intervalHours: hr,
        );
    }

    if (text.contains('\u0645\u0631\u062a\u064a\u0646') &&
        !text.contains('\u0627\u0633\u0628\u0648\u0639'))
      return _FreqParse(frequency: 'Twice a day');

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
        '\u062f\u0647\u0627\u0646|\u0645\u0648\u0636\u0639\u064a|\u0641\u064a\\s+\u0627\u0644\u0641\u0645|\u0639\u0646\\s+\u0637\u0631\u064a\u0642',
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
    if (m != null && (m.group(1) ?? '').trim().isNotEmpty)
      s = (m.group(1) ?? s).trim();

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

class _PatientDoseParse {
  final String? dose; // e.g. "1 tablet", "2 drops"
  final String? form; // e.g. "Capsule", "Syrup" — null if ambiguous
  _PatientDoseParse({this.dose, this.form});
}
