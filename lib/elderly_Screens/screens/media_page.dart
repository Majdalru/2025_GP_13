import 'dart:math' as math; // ✅ Needed for rotation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Needed for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'audio_list_page.dart';
import 'Favoritespage.dart';
import 'audio_player_page.dart';

import '../../models/audio_item.dart';
import '../../services/voice_assistant_service.dart';
import 'package:flutter_application_1/models/voice_command.dart'; // ✅ NEW

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  static const kPrimary = Color(0xFF1B3A52);

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> with TickerProviderStateMixin {
  // ✅ Use the Singleton instance
  final VoiceAssistantService _voiceService = VoiceAssistantService();

  // 🔹 Animation Controllers
  late AnimationController _rippleController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  bool _isListeningState = false;
  bool _isSpeakingState = false;

  @override
  void initState() {
    super.initState();
    // Initialize Animations
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

    // ✅ Listen to voice service state changes
    _voiceService.setOnListeningStateChange(_handleVoiceStateChange);
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
    _voiceService.setOnListeningStateChange(null); // ✅ Cleanup
    super.dispose();
  }

  // 🔹 Helper to start visual effects
  void _startAnimations() {
    _rippleController.repeat();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  // 🔹 Helper to stop visual effects
  void _stopAnimations() {
    _rippleController.stop();
    _pulseController.stop();
    _rotateController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // 🔹 AppBar
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: const Color(0xFF1B3A52),
        title: const Text("Media"),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),

      // 🔹 Body
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Grid Categories
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 25,
                childAspectRatio: MediaQuery.of(context).size.width < 380
                    ? 0.68
                    : 0.8,
                children: [
                  _buildMediaCard(context, Icons.library_music, "Story"),
                  _buildMediaCard(context, Icons.menu_book, "Quran"),
                  _buildMediaCard(context, Icons.upload_file, "Caregiver"),
                  _buildMediaCard(context, Icons.favorite, "Health"),
                ],
              ),

              const SizedBox(height: 40),

              // 🔹 Favorites Button
              SizedBox(
                width: double.infinity,
                height: 90,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavoritesPage()),
                    );
                  },
                  icon: const Icon(
                    Icons.favorite,
                    size: 45,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Favorites",
                    style: TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MediaPage.kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

              // Add padding at bottom so the floating button doesn't cover content
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),

      // 🔊 CUSTOM ANIMATED VOICE BUTTON
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: GestureDetector(
        onTap: _startVoiceConversation,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Layer 1: Ripples (show when listening OR speaking)
              if (_isListeningState || _isSpeakingState)
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    // ✅ Dynamic color based on state
                    final rippleColor = _isListeningState
                        ? Colors.green
                        : Colors.red;

                    return CustomPaint(
                      size: const Size(100, 100),
                      painter: RipplePainter(
                        animation: _rippleController.value,
                        color: rippleColor,
                      ),
                    );
                  },
                ),

              // Layer 2: Button Background
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _rotateController,
                ]),
                builder: (context, child) {
                  final scale = (_isListeningState || _isSpeakingState)
                      ? 1.0 + (_pulseController.value * 0.15)
                      : 1.0;

                  // ✅ Determine button color
                  Color buttonColor;
                  if (_isListeningState) {
                    buttonColor = Colors.green;
                  } else if (_isSpeakingState) {
                    buttonColor = Colors.red;
                  } else {
                    buttonColor = const Color(0xFF1B3A52);
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
                          gradient: RadialGradient(
                            colors: [buttonColor, buttonColor.withOpacity(0.8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Layer 3: Icon (changes based on state)
              Icon(
                _isListeningState
                    ? Icons.mic
                    : _isSpeakingState
                    ? Icons.volume_up
                    : Icons.mic_none,
                color: Colors.white,
                size: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard(BuildContext context, IconData icon, String title) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: MediaPage.kPrimary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: MediaPage.kPrimary.withOpacity(0.9), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: MediaPage.kPrimary.withOpacity(0.15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AudioListPage(category: title)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: MediaPage.kPrimary),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: MediaPage.kPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ==============================================
  /// 🧠 ARABIC NORMALIZATION HELPERS
  /// ==============================================

  /// يشيل التشكيل ويوحّد بعض الحروف
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

  /// يرجع كلمة مفتاحية من اسم السورة بالعربي نستخدمها للبحث في fileName
  String? _quranFileKeywordFromUtterance(String normalizedUtter) {
    // الفاتحة
    if (_containsAnyNormalized(normalizedUtter, [
      'الفاتحه',
      'سوره الفاتحه',
      'فاتحه',
    ])) {
      return 'faatiha';
    }

    // الفلق
    if (_containsAnyNormalized(normalizedUtter, ['الفلق', 'سوره الفلق'])) {
      return 'falaq';
    }

    // الإخلاص
    if (_containsAnyNormalized(normalizedUtter, [
      'الاخلاص',
      'الإخلاص',
      'سوره الاخلاص',
      'سورة الإخلاص',
    ])) {
      return 'ikhlaas';
    }

    // الملك
    if (_containsAnyNormalized(normalizedUtter, ['الملك', 'سوره الملك'])) {
      return 'mulk';
    }

    // الناس
    if (_containsAnyNormalized(normalizedUtter, ['الناس', 'سوره الناس'])) {
      return 'naas';
    }

    return null;
  }

  /// ✅ هل الكلام يعتبر إلغاء للجلسة؟
  bool _isCancelUtterance(String? answer) {
    if (answer == null) return false;
    final lower = answer.toLowerCase();

    // إنجليزي
    if (lower.contains('stop') || lower.contains('cancel')) {
      return true;
    }

    // عربي مع تطبيع
    final norm = _normalizeArabic(lower);
    return norm.contains('خلاص') ||
        norm.contains('وقف') ||
        norm.contains('ستوب') ||
        norm.contains('بس') ||
        norm.contains('لا تكمل') ||
        norm.contains('الغاء') ||
        norm.contains('الغ');
  }

  /// ==============================================
  /// 🧠 GLOBAL INTENTS HANDLER (go to home / medications .. )
  /// ==============================================
  Future<void> _handleGlobalCommand(VoiceCommand cmd) async {
    switch (cmd) {
      case VoiceCommand.goToMedia:
        await _voiceService.speak('You are already on the media page.');
        break;

      case VoiceCommand.goToHome:
        await _voiceService.speak('Going back to the home page.');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;

      case VoiceCommand.goToMedication:
      case VoiceCommand.addMedication:
      case VoiceCommand.editMedication:
      case VoiceCommand.deleteMedication:
        await _voiceService.speak(
          'To manage your medications, please go back to the home page and open the medications section.',
        );
        break;

      case VoiceCommand.sos:
        await _voiceService.speak('Here we will start the SOS emergency flow.');
        // TODO: استدعاء منطق الـ SOS الحقيقي
        break;

      case VoiceCommand.goToSettings:
        await _voiceService.speak(
          'Settings are not available from the media page yet.',
        );
        break;
    }
  }

  /// ==============================================
  /// 🧠 CONVERSATIONAL LOGIC
  /// ==============================================
  Future<void> _startVoiceConversation() async {
    // Check if already running to avoid double taps
    if (_isListeningState) return;

    // 1. Start Animations & UI
    setState(() => _isListeningState = true);
    _startAnimations();
    HapticFeedback.mediumImpact();

    // 2. Initialize Service
    final ok = await _voiceService.initialize();
    if (!ok) {
      setState(() => _isListeningState = false);
      _stopAnimations();
      return;
    }

    try {
      // --- STEP 1: Ask Category ---
      await _voiceService.speak(
        "You are on your media page. What category do you want me to play something from? Choose Health , Quraan, Story , Caregiver or favorites",
      );

      String? categoryAnswer = await _voiceService.listenWhisper(seconds: 5);
      debugPrint("User said category: $categoryAnswer");

      // ✅ لو قال cancel / خلاص هنا نوقف الجلسة كاملة
      if (_isCancelUtterance(categoryAnswer)) {
        await _voiceService.speak("Okay, I will stop now.");
        _resetVoiceState();
        return;
      }

      // if (categoryAnswer != null && categoryAnswer.trim().isNotEmpty) {
      //   final globalCmd = await _voiceService.analyzeSmartCommand(
      //     categoryAnswer,
      //   );
      //   if (globalCmd != null) {
      //     await _handleGlobalCommand(globalCmd);
      //     _resetVoiceState();
      //     return;
      //   }
      // }

      if (categoryAnswer == null || categoryAnswer.trim().isEmpty) {
        await _voiceService.speak("Sorry, I didn't catch that.");
        _resetVoiceState();
        return;
      }

      String? matchedCategory = _detectCategory(categoryAnswer);

      if (matchedCategory == null) {
        await _voiceService.speak(
          "Sorry, I didn't understand that category. Please try again.",
        );
        _resetVoiceState();
        return;
      }

      // --- STEP 2: Ask Specific vs Random ---
      await _voiceService.speak(
        "Okay, $matchedCategory. Do you want to play something specific or random?",
      );

      String? modeAnswer = await _voiceService.listenWhisper(seconds: 5);
      debugPrint("User said mode: $modeAnswer");

      // ✅ إلغاء في خطوة المود
      if (_isCancelUtterance(modeAnswer)) {
        await _voiceService.speak("Okay, I will stop now.");
        _resetVoiceState();
        return;
      }

      final modeLower = (modeAnswer ?? "").toLowerCase();

      if (modeLower.contains("specific") ||
          modeLower.contains("choose") ||
          modeLower.contains("search") ||
          _containsAnyNormalized(modeLower, ['معين', 'سوره', 'سورة'])) {
        // --- STEP 3A: Handle Specific ---
        await _voiceService.speak(
          "Please say the name of the audio you want to hear.",
        );

        String? titleQuery = await _voiceService.listenWhisper(seconds: 5);
        debugPrint("User said title: $titleQuery");

        // ✅ إلغاء في اسم السورة / الصوت
        if (_isCancelUtterance(titleQuery)) {
          await _voiceService.speak("Okay, I will stop now.");
          _resetVoiceState();
          return;
        }

        if (titleQuery != null && titleQuery.isNotEmpty) {
          await _playSpecificAudio(matchedCategory, titleQuery);
        } else {
          await _voiceService.speak("I didn't hear a title.");
        }
      } else {
        // --- STEP 3B: Handle Random (Default) ---
        await _voiceService.speak(
          "Okay, playing something random from $matchedCategory.",
        );
        await _playRandomForCategory(matchedCategory);
      }
    } catch (e) {
      debugPrint("Voice Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Voice command failed, please try again."),
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

  /// Helper to map voice input to exact Category strings
  String? _detectCategory(String text) {
    final lower = text.toLowerCase();
    final norm = _normalizeArabic(lower);

    // ===== Quran =====
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

    // ===== Story =====
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

    // ===== Health =====
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

    // ===== Caregiver =====
    if (_containsAnyNormalized(norm, [
      'care',
      'family',
      'gift',
      'caregiver',
      'مقدم رعايه',
      'مقدم الرعاية',
      'ممرض',
      'ممرضه',
      'ممرضة',
      'ابنتي',
      'ابني',
      'بنتي',
    ])) {
      return "Caregiver";
    }

    // ===== Favorites =====
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

  /// 🎲 Logic to play a RANDOM item
  Future<void> _playRandomForCategory(String category) async {
    try {
      QuerySnapshot<Map<String, dynamic>> qs;

      if (category == 'Favorites') {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await _voiceService.speak("You must be logged in for favorites.");
          return;
        }
        qs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .get();
      } else {
        qs = await FirebaseFirestore.instance
            .collection('audioMedia')
            .where('category', isEqualTo: category)
            .get();
      }

      if (qs.docs.isEmpty) {
        await _voiceService.speak("No audio found for $category.");
        return;
      }

      final randomDoc = qs.docs[math.Random().nextInt(qs.docs.length)];
      final item = AudioItem.fromDoc(randomDoc);
      _navigateToPlayer(item);
    } catch (e) {
      debugPrint("Error playing random: $e");
      await _voiceService.speak("Something went wrong.");
    }
  }

  /// 🎯 Logic to play a SPECIFIC item based on title search
  Future<void> _playSpecificAudio(String category, String searchTitle) async {
    try {
      QuerySnapshot<Map<String, dynamic>> qs;

      // Fetch all items in category first
      if (category == 'Favorites') {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          await _voiceService.speak("You need to login.");
          return;
        }
        qs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .get();
      } else {
        qs = await FirebaseFirestore.instance
            .collection('audioMedia')
            .where('category', isEqualTo: category)
            .get();
      }

      // 🔎 نطبّع النص قبل المطابقة (عربي + إنجليزي)
      final searchLower = searchTitle.toLowerCase();
      final searchNorm = _normalizeArabic(searchLower);

      // ------ 1) نحاول بالمطابقة على العنوان ------
      final matchingDocs = qs.docs.where((doc) {
        final rawTitle = (doc.data()['title'] ?? '').toString();
        final titleLower = rawTitle.toLowerCase();
        final titleNorm = _normalizeArabic(titleLower);

        return titleLower.contains(searchLower) ||
            titleNorm.contains(searchNorm);
      }).toList();

      if (matchingDocs.isNotEmpty) {
        final item = AudioItem.fromDoc(matchingDocs.first);
        await _voiceService.speak("Playing ${item.title}");
        _navigateToPlayer(item);
        return;
      }

      // ------ 2) لو category = Quran نطيح على fileName بالكلمة المفتاحية ------
      if (category == 'Quran') {
        final keyword = _quranFileKeywordFromUtterance(searchNorm);
        if (keyword != null) {
          final quranDocs = qs.docs.where((doc) {
            final fileName = (doc.data()['fileName'] ?? '')
                .toString()
                .toLowerCase();
            return fileName.contains(keyword); // مثال: contains 'falaq'
          }).toList();

          if (quranDocs.isNotEmpty) {
            final item = AudioItem.fromDoc(quranDocs.first);
            await _voiceService.speak("Playing ${item.title}");
            _navigateToPlayer(item);
            return;
          }
        }
      }

      // ------ 3) لو لا عنوان ولا ملف طابقوا ------
      await _voiceService.speak(
        "I couldn't find any audio named $searchTitle in $category.",
      );
    } catch (e) {
      debugPrint("Error playing specific: $e");
      await _voiceService.speak("Something went wrong while searching.");
    }
  }

  void _navigateToPlayer(AudioItem item) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AudioPlayerPage(item: item)),
    );
  }
}

// 🖌️ PAINTER FOR THE RIPPLES
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
      final radius =
          40 + (progress * 50); // Starts at button radius, expands out
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
