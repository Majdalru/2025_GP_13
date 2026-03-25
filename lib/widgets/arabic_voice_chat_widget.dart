import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/voice_command.dart';
import '../services/arabic_voice_assistant_service.dart';

class ArabicVoiceChatWidget extends StatefulWidget {
  final Function(VoiceCommand) onCommand;

  const ArabicVoiceChatWidget({super.key, required this.onCommand});

  @override
  State<ArabicVoiceChatWidget> createState() => _ArabicVoiceChatWidgetState();
}

class _ArabicVoiceChatWidgetState extends State<ArabicVoiceChatWidget>
    with TickerProviderStateMixin {
  final ArabicVoiceAssistantService _assistant =
      ArabicVoiceAssistantService();

  bool _isListening = false;
  bool _isSpeaking = false;
  String _statusText = '';
  AnimationController? _waveController;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initializeAndStart();
  }

  Future<void> _initializeAndStart() async {
    setState(() {
      _statusText = 'جاري التهيئة...';
    });

    final initialized = await _assistant.initialize();
    if (!initialized) {
      if (mounted) {
        setState(() {
          _statusText = 'تعذر تشغيل المساعد الصوتي';
        });
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
      }
      return;
    }

    await _startConversation();
  }

  Future<void> _startConversation() async {
    setState(() {
      _isSpeaking = true;
      _statusText = _assistant.getGreeting();
    });

    _waveController?.repeat();

    await _assistant.startConversation(
      context: context,
      onCommand: (command) {
        _waveController?.stop();
        widget.onCommand(command);
        Navigator.pop(context);
      },
    );

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _statusText = 'اضغط على الميكروفون للتحدث';
      });
      _waveController?.stop();
    }
  }

  Future<void> _listen() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _statusText = 'جاري الاستماع...';
    });

    _waveController?.repeat();

    final result = await _assistant.listenWhisper(seconds: 4);

    _waveController?.stop();

    if (result != null && result.isNotEmpty) {
      setState(() {
        _statusText = 'جاري المعالجة...';
      });

      final command = await _assistant.analyzeSmartCommand(result);

      if (command != null) {
        setState(() {
          _isSpeaking = true;
          _statusText = 'جاري تنفيذ طلبك...';
        });
        _waveController?.repeat();

        await _assistant.speak("حسنًا، سأنتقل بك الآن.");
        await Future.delayed(const Duration(seconds: 1));

        _waveController?.stop();
        widget.onCommand(command);
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      setState(() {
        _isSpeaking = true;
        _statusText =
            "أستطيع مساعدتك في التنقل. جرّب قول الأدوية أو الوسائط أو الصفحة الرئيسية.";
      });

      _waveController?.repeat();

      await _assistant.speak(
        "أستطيع مساعدتك في الانتقال إلى الأدوية أو الوسائط أو الصفحة الرئيسية. ماذا تريد؟",
      );

      _waveController?.stop();

      setState(() {
        _isSpeaking = false;
        _statusText = 'اضغط على الميكروفون للتحدث';
      });
    } else {
      setState(() {
        _statusText = 'اضغط على الميكروفون للتحدث';
      });
    }

    setState(() {
      _isListening = false;
    });
  }

  @override
  void dispose() {
    _waveController?.dispose();
    _pulseController?.dispose();
    _assistant.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1B3A52),
              const Color(0xFF1B3A52).withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () {
                    _waveController?.stop();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 200,
              child: Center(
                child: (_waveController != null)
                    ? AnimatedBuilder(
                        animation: _waveController!,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(300, 200),
                            painter: _WavePainter(
                              animation: _waveController!.value,
                              isActive: _isListening || _isSpeaking,
                            ),
                          );
                        },
                      )
                    : const SizedBox(),
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: (_isListening || _isSpeaking) ? null : _listen,
              child: (_pulseController != null)
                  ? AnimatedBuilder(
                      animation: _pulseController!,
                      builder: (context, child) {
                        final scale = _isListening || _isSpeaking
                            ? 1.0 + (_pulseController!.value * 0.1)
                            : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isListening || _isSpeaking)
                                  ? Colors.red
                                  : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: ((_isListening || _isSpeaking)
                                          ? Colors.red
                                          : Colors.white)
                                      .withOpacity(0.5),
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
                              color: (_isListening || _isSpeaking)
                                  ? Colors.white
                                  : const Color(0xFF1B3A52),
                              size: 50,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.mic_none,
                        color: Color(0xFF1B3A52),
                        size: 50,
                      ),
                    ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _isListening
                    ? 'جاري الاستماع إلى طلبك...'
                    : _isSpeaking
                        ? 'جاري التحدث...'
                        : 'اضغط على الميكروفون للتحدث',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animation;
  final bool isActive;

  _WavePainter({required this.animation, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final centerY = size.height / 2;

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final opacity = 1.0 - (i * 0.15);
      final amplitude = 30.0 - (i * 5);
      final frequency = 2.0 + (i * 0.3);
      final phase = animation * 2 * math.pi + (i * math.pi / 4);

      paint.color = Colors.white.withOpacity(opacity);

      path.moveTo(0, centerY);

      for (double x = 0; x <= size.width; x += 1) {
        final y =
            centerY +
            amplitude *
                math.sin((x / size.width) * frequency * 2 * math.pi + phase);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }

    final circlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final radius = 8.0 + (i * 4);
      final opacity = 0.6 - (i * 0.15);
      final xPos =
          (size.width / 2) +
          (50 * math.cos(animation * 2 * math.pi + (i * math.pi / 3)));

      circlePaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(xPos, centerY), radius, circlePaint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.isActive != isActive;
  }
}