import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/voice_command.dart';
import '../services/arabic_voice_assistant_service.dart';

class ArabicFloatingVoiceButton extends StatefulWidget {
  final Function(VoiceCommand) onCommand;
  final Function(String)? onAnswer;
  final bool isAnswerMode;
  final String? customGreeting;
  final String? customErrorResponse;

  const ArabicFloatingVoiceButton({
    super.key,
    required this.onCommand,
    this.onAnswer,
    this.isAnswerMode = false,
    this.customGreeting,
    this.customErrorResponse,
  });

  @override
  State<ArabicFloatingVoiceButton> createState() =>
      _ArabicFloatingVoiceButtonState();
}

class _ArabicFloatingVoiceButtonState extends State<ArabicFloatingVoiceButton>
    with TickerProviderStateMixin {
  final ArabicVoiceAssistantService _voiceService =
      ArabicVoiceAssistantService();
  final AudioPlayer _beepPlayer = AudioPlayer();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String? _userName;

  late AnimationController _rippleController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

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

    _voiceService.setOnListeningStateChange(_handleServiceStateChange);

    _loadUserInfo();
  }

  void _handleServiceStateChange(bool isListening, bool isSpeaking) {
    if (!mounted) return;

    setState(() {
      _isListening = isListening;
      _isSpeaking = isSpeaking;
    });

    if (isListening || isSpeaking) {
      _startAnimations();
    } else {
      _stopAnimations();
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final first = (data['firstName'] ?? '').toString().trim();
          setState(() {
            _userName = first.isNotEmpty ? first : null;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user info: $e');
    }
  }

  Future<void> _initialize() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('❌ Microphone permission not granted');
        return;
      }

      _isInitialized = await _voiceService.initialize();

      debugPrint(
        '✅ Arabic voice assistant initialized (Whisper + ChatGPT + Google TTS): $_isInitialized',
      );
    } catch (e) {
      debugPrint('❌ Initialize error: $e');
    }
  }

  Future<void> _toggleVoice() async {
    if (!_isInitialized) {
      await _initialize();
      if (!_isInitialized) return;
    }

    if (_isListening || _isSpeaking) {
      await _voiceService.stopSpeaking();
      _stopAnimations();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
      return;
    }

    await _startConversation();
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

  Future<void> _playBeep() async {
    try {
      await _beepPlayer.stop();
      await _beepPlayer.play(AssetSource('sounds/beep.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('❌ Beep error: $e');
    }
  }

  Future<void> _startConversation() async {
    if (widget.isAnswerMode) {
      _startAnimations();
      HapticFeedback.mediumImpact();
      setState(() {
        _isSpeaking = false;
        _isListening = true;
      });
      await _startListening();
      return;
    }

    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });

    _startAnimations();
    HapticFeedback.mediumImpact();

    if (widget.customGreeting != null) {
      await _speak(widget.customGreeting!);
    } else {
      final hour = DateTime.now().hour;
      String greeting;

      if (hour < 12) {
        greeting = _userName != null
            ? "صباح الخير يا $_userName، كيف استطيع مساعدتك"
            : "صباح الخير، كيف أقدر أساعدك؟";
      } else if (hour < 17) {
        greeting = _userName != null
            ? "مساء الخير يا $_userName، ماذا تريد؟"
            : "مساء الخير، ماذا تريد؟";
      } else {
        greeting = _userName != null
            ? "مساء الخير يا $_userName، كيف أقدر أخدمك؟"
            : "مساء الخير، كيف أقدر أخدمك؟";
      }

      await _speak(greeting);
      await _speak(
        "أستطيع مساعدتك في معرفة الطقس او التنقل داخل التطبيق. ",
      );
    }

    await _startListening();
  }

  Future<void> _speak(String text) async {
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    await _voiceService.speak(text);
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _isSpeaking = false;
    });

    await _playBeep();

    try {
      debugPrint('🎤 Starting to listen with Whisper...');

      final result = await _voiceService.listenWhisper(seconds: 5);

      debugPrint('🎤 Whisper result: "$result"');

      if (result != null && result.trim().isNotEmpty) {
        await _processCommand(result);
      } else {
        await _handleNoResponse();
      }
    } catch (e) {
      debugPrint('❌ Listen error: $e');
      _stopAnimations();
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _processCommand(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await _handleNoResponse();
      return;
    }

    if (widget.isAnswerMode && widget.onAnswer != null) {
      debugPrint("🎤 Voice answer mode: $trimmed");
      _stopAnimations();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
      widget.onAnswer!(trimmed);
      return;
    }

    setState(() {
      _isListening = false;
      _isSpeaking = true;
    });

    final command = await _voiceService.analyzeSmartCommand(trimmed);

    if (command != null) {
      final confirmation = _getConfirmation(command);
      HapticFeedback.heavyImpact();
      await _speak(confirmation);

      _stopAnimations();

      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isListening = false;
        });

        widget.onCommand(command);
      }
    } else {
      final String errorMessage =
          widget.customErrorResponse ??
          "لم أفهم طلبك. جرّب السؤال عن الطقس او قول الأدوية أو الوسائط أو الصفحة الرئيسية.";

      await _speak(errorMessage);

      setState(() {
        _isSpeaking = false;
      });

      _stopAnimations();
    }
  }

  Future<void> _handleNoResponse() async {
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });

    await _speak("لم أسمعك. حاول مرة أخرى.");

    _stopAnimations();

    setState(() {
      _isSpeaking = false;
    });
  }

  String _getConfirmation(VoiceCommand command) {
    switch (command) {
      case VoiceCommand.goToMedication:
        return "جاري فتح صفحة الأدوية.";
      case VoiceCommand.addMedication:
        return "حسنًا، لنضف دواءً جديدًا.";
      case VoiceCommand.editMedication:
        return "حسنًا، لنعدل دواءً.";
      case VoiceCommand.deleteMedication:
        return "حسنًا، ما الدواء الذي تريد حذفه؟";
      case VoiceCommand.goToMedia:
        return "جاري فتح الوسائط.";
      case VoiceCommand.goToHome:
        return "جاري الانتقال إلى الصفحة الرئيسية.";
      case VoiceCommand.sos:
        return "جاري تفعيل الطوارئ.";
      case VoiceCommand.goToSettings:
        return "جاري فتح الإعدادات.";
      case VoiceCommand.weather:
        return "جاري معرفة حالة الطقس.";
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _beepPlayer.dispose();
    _voiceService.stopSpeaking();
    _voiceService.setOnListeningStateChange(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const idleColor = Color(0xFF1B3A52);
    final speakingColor = Colors.red;
    final listeningColor = Colors.green;

    Color micColor;
    if (_isListening) {
      micColor = listeningColor;
    } else if (_isSpeaking) {
      micColor = speakingColor;
    } else {
      micColor = idleColor;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: _toggleVoice,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening || _isSpeaking) ...[
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(100, 100),
                      painter: RipplePainter(
                        animation: _rippleController.value,
                        color: micColor,
                      ),
                    );
                  },
                ),
              ],
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _rotateController,
                ]),
                builder: (context, child) {
                  final scale = (_isListening || _isSpeaking)
                      ? 1.0 + (_pulseController.value * 0.15)
                      : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: (_isListening || _isSpeaking)
                          ? _rotateController.value * 2 * math.pi
                          : 0,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [micColor, micColor.withOpacity(0.8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: micColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic
                              : _isSpeaking
                                  ? Icons.volume_up
                                  : Icons.mic_none,
                          color: Colors.white,
                          size: 40,
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