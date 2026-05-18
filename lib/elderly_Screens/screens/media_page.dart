import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'audio_list_page.dart';
import 'Favoritespage.dart';
import 'audio_player_page.dart';
import 'shared_media_list_page.dart';

import '../../models/audio_item.dart';
import '../../services/voice_assistant_service.dart';
import '../../services/arabic_voice_assistant_service.dart';
import '../../providers/locale_provider.dart';
import 'package:flutter_application_1/models/voice_command.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'youtube_player_page.dart';

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  static const kPrimary = Color(0xFF1B3A52);

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> with TickerProviderStateMixin {
  String _localizedCategoryName(String category) {
    final loc = AppLocalizations.of(context)!;

    switch (category) {
      case 'Story':
        return loc.story;
      case 'Quran':
        return loc.quran;
      case 'Health':
        return loc.health;
      // case 'Caregiver':
      //   return loc.caregiver;
      case 'Favorites':
        return loc.favorites;
      default:
        return category;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getMediaByCategory(
    String category,
  ) {
    final lang = Localizations.localeOf(context).languageCode;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('audioMedia')
        .where('category', isEqualTo: category);

    if ((category == 'Story' || category == 'Health') && lang == 'ar') {
      query = query.where('language', isEqualTo: 'ar');
    }

    return query.get();
  }

  final VoiceAssistantService _voiceService = VoiceAssistantService();
  final ArabicVoiceAssistantService _arabicVoiceService =
      ArabicVoiceAssistantService();

  late AnimationController _rippleController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  bool _isListeningState = false;
  bool _isSpeakingState = false;

  bool get _isArabic {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return localeProvider.isArabic;
  }

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _voiceService.setOnListeningStateChange(_handleVoiceStateChange);
    _arabicVoiceService.setOnListeningStateChange(_handleVoiceStateChange);
  }

  void _handleVoiceStateChange(bool isListening, bool isSpeaking) {
    if (!mounted) return;

    setState(() {
      _isListeningState = isListening;
      _isSpeakingState = isSpeaking;
    });

    if (isListening || isSpeaking) {
      _startAnimations();
    } else {
      _stopAnimations();
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _voiceService.setOnListeningStateChange(null);
    _arabicVoiceService.setOnListeningStateChange(null);
    super.dispose();
  }

  void _startAnimations() {
    _rippleController.repeat();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  void _stopAnimations() {
    _rippleController.stop();
    _pulseController.stop();
    _rotateController.stop();
  }

  Future<void> _speak(String text) async {
    if (_isArabic) {
      await _arabicVoiceService.speak(text);
    } else {
      await _voiceService.speak(text);
    }
  }

  Future<bool> _initializeVoice() async {
    if (_isArabic) {
      return _arabicVoiceService.initialize();
    }
    return _voiceService.initialize();
  }

  Future<String?> _listen({int seconds = 5}) async {
    if (_isArabic) {
      return _arabicVoiceService.listenWhisper(seconds: seconds);
    }
    return _voiceService.listenWhisper(seconds: seconds);
  }

  Future<VoiceCommand?> _analyzeCommand(String text) async {
    if (_isArabic) {
      return _arabicVoiceService.analyzeSmartCommand(text);
    }
    return _voiceService.analyzeSmartCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.isArabic;
    const kBg = Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 50, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: Color(0xFF1A2340),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 184, 214, 217),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.media,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                      Text(
                        isArabic
                            ? 'القرآن والقصص والصحة'
                            : 'Quran, Stories & Health',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(isArabic ? 'الأقسام' : 'Categories'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.95,
                      children: [
                        _buildMediaCard(
                          context,
                          Icons.auto_stories_outlined,
                          'Story',
                          AppLocalizations.of(context)!.story,
                          const Color(0xFF102E50),
                          const Color(0xFFD6E4EE),
                        ),
                        _buildMediaCard(
                          context,
                          Icons.menu_book_outlined,
                          'Quran',
                          AppLocalizations.of(context)!.quran,
                          const Color(0xFFF5C35D),
                          const Color(0xFFFEF3D7),
                        ),
                        _buildMediaCard(
                          context,
                          Icons.medical_services_outlined,
                          'Health',
                          AppLocalizations.of(context)!.health,
                          const Color(0xFF3A8C78),
                          const Color(0xFFE8F7F2),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FavoritesPage(),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDEF0EC),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.favorite_outline,
                                      color: Color(0xFF4E949C),
                                      size: 36,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    AppLocalizations.of(context)!.favorites,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A2340),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Voice FAB ───────────────────────────────────────────
      floatingActionButton: GestureDetector(
        onTap: _startVoiceConversation,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isListeningState || _isSpeakingState)
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(100, 100),
                      painter: RipplePainter(
                        animation: _rippleController.value,
                        color: _isListeningState ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _rotateController,
                ]),
                builder: (context, child) {
                  final scale = (_isListeningState || _isSpeakingState)
                      ? 1.0 + (_pulseController.value * 0.15)
                      : 1.0;
                  Color buttonColor;
                  if (_isListeningState) {
                    buttonColor = Colors.green;
                  } else if (_isSpeakingState) {
                    buttonColor = Colors.red;
                  } else {
                    buttonColor = const Color(0xFF1A2340);
                  }
                  return Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: (_isListeningState || _isSpeakingState)
                          ? _rotateController.value * 2 * math.pi
                          : 0,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: buttonColor,
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListeningState
                              ? Icons.mic
                              : _isSpeakingState
                              ? Icons.volume_up
                              : Icons.mic_none,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    IconData icon,
    String categoryKey,
    String title,
    Color iconColor,
    Color iconBg,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AudioListPage(category: categoryKey)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2340),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeArabic(String input) {
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

  bool _containsAnyNormalized(String text, List<String> patterns) {
    final lower = text.toLowerCase();
    final normText = _normalizeArabic(lower);

    for (final p in patterns) {
      final lowerP = p.toLowerCase();
      final normP = _normalizeArabic(lowerP);
      if (lower.contains(lowerP) || normText.contains(normP)) {
        return true;
      }
    }
    return false;
  }

  String? _quranFileKeywordFromUtterance(String normalizedUtter) {
    if (_containsAnyNormalized(normalizedUtter, [
      'الفاتحه',
      'سوره الفاتحه',
      'فاتحه',
    ])) {
      return 'faatiha';
    }

    if (_containsAnyNormalized(normalizedUtter, ['الفلق', 'سوره الفلق'])) {
      return 'falaq';
    }

    if (_containsAnyNormalized(normalizedUtter, [
      'الاخلاص',
      'الإخلاص',
      'سوره الاخلاص',
      'سورة الإخلاص',
    ])) {
      return 'ikhlaas';
    }

    if (_containsAnyNormalized(normalizedUtter, ['الملك', 'سوره الملك'])) {
      return 'mulk';
    }

    if (_containsAnyNormalized(normalizedUtter, ['الناس', 'سوره الناس'])) {
      return 'naas';
    }

    return null;
  }

  String? _healthFileKeywordFromUtterance(String normalizedUtter) {
    if (_containsAnyNormalized(normalizedUtter, [
      'exercise',
      'exercises',
      'Five Exercises in Home',
      'رياضه',
      'رياضة',
      'تحرك',
      'حركه',
      'movement',
    ])) {
      return 'Exercises';
    }

    if (_containsAnyNormalized(normalizedUtter, [
      'sleep',
      'sleeping',
      'نوم',
      'وضعية نوم',
      'وضعية النوم',
      'النوم',
    ])) {
      return 'sleep';
    }

    if (_containsAnyNormalized(normalizedUtter, [
      'self care',
      'care',
      'العنايه',
      'العناية',
      'نفسي',
      'صحه نفسيه',
      'نصائح',
      'كبار السن',
      'النفسية',
      'تعزيز',
    ])) {
      return 'الصحة النفسية';
    }

    if (_containsAnyNormalized(normalizedUtter, [
      'diet',
      'food',
      'nutrition',
      'The Ideal Diet for Senior',
      'غذاء',
      'حمية',
      'رجيم',
      'كبار السن',
      'senior',
    ])) {
      return 'diet';
    }

    return null;
  }

  String? _storyFileKeywordFromUtterance(String normalizedUtter) {
    if (_containsAnyNormalized(normalizedUtter, [
      'muhammad',
      'النبي محمد',
      'رسول الله',
      'سيدنا محمد',
      'prophet muhammad',
      'Muhammad',
      'محمد',
    ])) {
      return 'muhammad';
    }

    if (_containsAnyNormalized(normalizedUtter, [
      'noah',
      'النبي نوح',
      'سيدنا نوح',
      'prophet noah',
      'Noah',
    ])) {
      return 'noah';
    }
    if (_containsAnyNormalized(normalizedUtter, [
      'نوح',
      'سيدنا نوح',
      'قصة نوح',
      'قصة سيدنا نوح',
    ])) {
      return 'نوح'; //  عربي
    }

    if (_containsAnyNormalized(normalizedUtter, [
      'زهران',
      'القاضي زهران',
      'قصة القاضي',
      'قصة القاضي زهران',
    ])) {
      return 'زهران'; //  عربي
    }

    return null;
  }

  bool _isCancelUtterance(String? answer) {
    if (answer == null) return false;
    final lower = answer.toLowerCase();

    if (lower.contains('stop') || lower.contains('cancel')) {
      return true;
    }

    final norm = _normalizeArabic(lower);
    return norm.contains('خلاص') ||
        norm.contains('وقف') ||
        norm.contains('ستوب') ||
        norm.contains('بس') ||
        norm.contains('لا تكمل') ||
        norm.contains('الغاء') ||
        norm.contains('الغ');
  }

  Future<void> _handleGlobalCommand(VoiceCommand cmd) async {
    switch (cmd) {
      case VoiceCommand.goToFamilyMessages:
        await _speak(
          _isArabic ? 'جاري فتح رسائل العائلة.' : 'Opening family messages.',
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SharedMediaListPage()),
        );
        break;

      case VoiceCommand.goToMedia:
        await _speak(AppLocalizations.of(context)!.alreadyOnMediaPage);
        break;

      case VoiceCommand.goToHome:
      case VoiceCommand.weather:
      case VoiceCommand.news:
      case VoiceCommand.goToDailyLibrary:
        await _speak(AppLocalizations.of(context)!.goingBackToHome);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;

      case VoiceCommand.goToMedication:
      case VoiceCommand.addMedication:
      case VoiceCommand.editMedication:
      case VoiceCommand.deleteMedication:
        await _speak(
          AppLocalizations.of(context)!.manageMedicationsInstruction,
        );
        break;

      case VoiceCommand.sos:
        await _speak(AppLocalizations.of(context)!.startingSosFlow);
        break;

      case VoiceCommand.goToSettings:
        await _speak(AppLocalizations.of(context)!.settingsNotAvailableHere);
        break;

      case VoiceCommand.todayMedications:
        await _speak(AppLocalizations.of(context)!.goingBackToHome);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;
    }
  }

  Future<void> _startVoiceConversation() async {
    if (_isListeningState) return;

    setState(() => _isListeningState = true);
    _startAnimations();
    HapticFeedback.mediumImpact();

    final ok = await _initializeVoice();
    if (!ok) {
      setState(() => _isListeningState = false);
      _stopAnimations();
      return;
    }

    try {
      await _speak(AppLocalizations.of(context)!.mediaCategoryPrompt);

      String? categoryAnswer = await _listen(seconds: 6);
      debugPrint("User said category: $categoryAnswer");

      if (_isCancelUtterance(categoryAnswer)) {
        await _speak(AppLocalizations.of(context)!.stoppingVoiceAssistant);
        _resetVoiceState();
        return;
      }

      if (categoryAnswer != null && categoryAnswer.trim().isNotEmpty) {
        final globalCmd = await _analyzeCommand(categoryAnswer);
        if (globalCmd != null &&
            (globalCmd == VoiceCommand.goToHome ||
                globalCmd == VoiceCommand.goToMedication ||
                globalCmd == VoiceCommand.addMedication ||
                globalCmd == VoiceCommand.editMedication ||
                globalCmd == VoiceCommand.deleteMedication ||
                globalCmd == VoiceCommand.sos ||
                globalCmd == VoiceCommand.goToSettings ||
                globalCmd == VoiceCommand.goToFamilyMessages)) {
          await _handleGlobalCommand(globalCmd);
          _resetVoiceState();
          return;
        }
      }

      if (categoryAnswer == null || categoryAnswer.trim().isEmpty) {
        await _speak(AppLocalizations.of(context)!.didNotCatchThat);
        _resetVoiceState();
        return;
      }

      String? matchedCategory = _detectCategory(categoryAnswer);

      if (matchedCategory == null) {
        await _speak(AppLocalizations.of(context)!.categoryNotUnderstood);
        _resetVoiceState();
        return;
      }

      final spokenCategory = _localizedCategoryName(matchedCategory);

      await _speak(
        AppLocalizations.of(context)!.specificOrRandomPrompt(spokenCategory),
      );

      String? modeAnswer = await _listen(seconds: 6);
      debugPrint("User said mode: $modeAnswer");

      if (_isCancelUtterance(modeAnswer)) {
        await _speak(AppLocalizations.of(context)!.stoppingVoiceAssistant);
        _resetVoiceState();
        return;
      }

      final modeLower = (modeAnswer ?? "").toLowerCase();

      if (modeLower.contains("specific") ||
          modeLower.contains("choose") ||
          modeLower.contains("search") ||
          _containsAnyNormalized(modeLower, [
            'معين',
            'سوره',
            'مشي',
            'محدد',
            'قصة',
            'نصيحة',
            'شي محدد',
            'شي معين',
            'ابغى',
            'اريد',
          ])) {
        await _speak(AppLocalizations.of(context)!.sayAudioOrVideoName);

        String? titleQuery = await _listen(seconds: 6);
        debugPrint("User said title: $titleQuery");

        if (_isCancelUtterance(titleQuery)) {
          await _speak(AppLocalizations.of(context)!.stoppingVoiceAssistant);
          _resetVoiceState();
          return;
        }

        if (titleQuery != null && titleQuery.isNotEmpty) {
          await _playSpecificAudio(matchedCategory, titleQuery);
        } else {
          await _speak(AppLocalizations.of(context)!.didNotHearTitle);
        }
      } else {
        await _speak(
          AppLocalizations.of(
            context,
          )!.playingRandomFromCategory(spokenCategory),
        );

        await _playRandomForCategory(matchedCategory);
      }
    } catch (e) {
      debugPrint("Voice Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.voiceCommandFailed),
        ),
      );
    } finally {
      _resetVoiceState();
    }
  }

  void _resetVoiceState() {
    if (mounted) {
      _stopAnimations();
      setState(() => _isListeningState = false);
    }
  }

  String? _detectCategory(String text) {
    final lower = text.toLowerCase();
    final norm = _normalizeArabic(lower);

    if (_containsAnyNormalized(norm, [
      'quran',
      'qur\'an',
      'قران',
      'القران',
      'قرآن',
      'القرآن',
      'سوره القران',
      'سور القران',
      'شغل القران',
      'شغل القرآن',
      'ابي اسمع القران',
      'ابي اسمع قرآن',
    ])) {
      return "Quran";
    }

    if (_containsAnyNormalized(norm, [
      'story',
      'stories',
      'قصه',
      'قصة',
      'قصص',
      'حكاية',
    ])) {
      return "Story";
    }

    if (_containsAnyNormalized(norm, [
      'health',
      'exercise',
      'movement',
      'صحه',
      'صحة',
      'صحيه',
      'رياضه',
      'رياضة',
      'اكل',
      'طعام',
    ])) {
      return "Health";
    }

    // if (_containsAnyNormalized(norm, [
    //   'care',
    //   'family',
    //   'gift',
    //   'caregiver',
    //   'مقدم رعايه',
    //   'مقدم الرعاية',
    //   'ممرض',
    //   'ممرضه',
    //   'ممرضة',
    //   'ابنتي',
    //   'ابني',
    //   'بنتي',
    // ])) {
    //   return "Caregiver";
    // }

    if (_containsAnyNormalized(norm, [
      'favorite',
      'favorites',
      'love',
      'المفضله',
      'المفضلة',
      'مفضل',
    ])) {
      return "Favorites";
    }

    return null;
  }

  Future<void> _playRandomForCategory(String category) async {
    try {
      QuerySnapshot<Map<String, dynamic>> qs;

      if (category == 'Favorites') {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await _speak(
            AppLocalizations.of(context)!.mustBeLoggedInForFavorites,
          );
          return;
        }
        qs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .where('category', whereIn: ['Quran', 'Story', 'Health'])
            .get();
      } else {
        qs = await _getMediaByCategory(category);
      }

      if (qs.docs.isEmpty) {
        await _speak(
          AppLocalizations.of(context)!.noAudioFoundForCategory(category),
        );
        return;
      }

      final randomDoc = qs.docs[math.Random().nextInt(qs.docs.length)];
      final item = AudioItem.fromDoc(randomDoc);
      _navigateToPlayer(item);
    } catch (e) {
      debugPrint("Error playing random: $e");
      await _speak(AppLocalizations.of(context)!.somethingWentWrong);
    }
  }

  Future<void> _playSpecificAudio(String category, String searchTitle) async {
    try {
      QuerySnapshot<Map<String, dynamic>> qs;

      if (category == 'Favorites') {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await _speak(
            AppLocalizations.of(context)!.mustBeLoggedInForFavorites,
          );
          return;
        }
        qs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .where('category', whereIn: ['Quran', 'Story', 'Health'])
            .get();
      } else {
        qs = await _getMediaByCategory(category);
      }

      final searchLower = searchTitle.toLowerCase();
      final searchNorm = _normalizeArabic(searchLower);

      final matchingDocs = qs.docs.where((doc) {
        final rawTitle = (doc.data()['title'] ?? '').toString();
        final titleLower = rawTitle.toLowerCase();
        final titleNorm = _normalizeArabic(titleLower);

        return titleLower.contains(searchLower) ||
            titleNorm.contains(searchNorm);
      }).toList();

      if (matchingDocs.isNotEmpty) {
        final item = AudioItem.fromDoc(matchingDocs.first);
        await _speak(AppLocalizations.of(context)!.playingItem(item.title));
        _navigateToPlayer(item);
        return;
      }

      if (category == 'Quran') {
        final keyword = _quranFileKeywordFromUtterance(searchNorm);
        if (keyword != null) {
          final quranDocs = qs.docs.where((doc) {
            final fileName = (doc.data()['fileName'] ?? '')
                .toString()
                .toLowerCase();
            return fileName.contains(keyword);
          }).toList();

          if (quranDocs.isNotEmpty) {
            final item = AudioItem.fromDoc(quranDocs.first);
            await _speak(AppLocalizations.of(context)!.playingItem(item.title));
            _navigateToPlayer(item);
            return;
          }
        }
      }

      if (category == 'Health') {
        String? keyword = _healthFileKeywordFromUtterance(searchNorm);
        if (keyword != null) {
          keyword = keyword.toLowerCase();

          final healthDocs = qs.docs.where((doc) {
            final data = doc.data();

            final rawTitle = (data['title'] ?? '').toString();
            final titleLower = rawTitle.toLowerCase();
            final titleNorm = _normalizeArabic(titleLower);

            final rawTag = (data['tag'] ?? '').toString();
            final tagLower = rawTag.toLowerCase();
            final tagNorm = _normalizeArabic(tagLower);

            return titleLower.contains(keyword!) ||
                titleNorm.contains(keyword) ||
                tagLower.contains(keyword) ||
                tagNorm.contains(keyword);
          }).toList();

          if (healthDocs.isNotEmpty) {
            final item = AudioItem.fromDoc(healthDocs.first);
            await _speak(AppLocalizations.of(context)!.playingItem(item.title));
            _navigateToPlayer(item);
            return;
          }
        }
      }

      if (category == 'Story') {
        String? keyword = _storyFileKeywordFromUtterance(searchNorm);
        if (keyword != null) {
          keyword = keyword.toLowerCase();

          final storyDocs = qs.docs.where((doc) {
            final data = doc.data();

            final rawTitle = (data['title'] ?? '').toString();
            final titleLower = rawTitle.toLowerCase();
            final titleNorm = _normalizeArabic(titleLower);

            final rawTag = (data['tag'] ?? '').toString();
            final tagLower = rawTag.toLowerCase();
            final tagNorm = _normalizeArabic(tagLower);

            return titleLower.contains(keyword!) ||
                titleNorm.contains(keyword) ||
                tagLower.contains(keyword) ||
                tagNorm.contains(keyword);
          }).toList();

          if (storyDocs.isNotEmpty) {
            final item = AudioItem.fromDoc(storyDocs.first);
            await _speak(AppLocalizations.of(context)!.playingItem(item.title));
            _navigateToPlayer(item);
            return;
          }
        }
      }

      await _speak(
        AppLocalizations.of(
          context,
        )!.couldNotFindAudioNamed(searchTitle, category),
      );
    } catch (e) {
      debugPrint("Error playing specific: $e");
      await _speak(
        AppLocalizations.of(context)!.somethingWentWrongWhileSearching,
      );
    }
  }

  void _navigateToPlayer(AudioItem item) {
    if (!mounted) return;

    if (item.type == 'youtube' && item.url != null && item.url!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => YouTubePlayerPage(item: item)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AudioPlayerPage(item: item)),
      );
    }
  }
}

class RipplePainter extends CustomPainter {
  final double animation;
  final Color color;

  RipplePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < 3; i++) {
      final progress = (animation + (i * 0.33)) % 1.0;
      final radius = 40 + (progress * 50);
      final opacity = 1.0 - progress;

      paint.color = color.withOpacity(opacity * 0.6);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}
