import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class FloatingVoiceButton extends StatefulWidget {
  final Function(VoiceCommand) onCommand;

  const FloatingVoiceButton({
    super.key,
    required this.onCommand,
  });

  @override
  State<FloatingVoiceButton> createState() => _FloatingVoiceButtonState();
}

class _FloatingVoiceButtonState extends State<FloatingVoiceButton>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
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
    
    _loadUserInfo();
    _initialize();
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
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _initialize() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        return;
      }

      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            _stopAnimations();
          }
        },
      );

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.1);

      debugPrint('Voice assistant initialized: $_isInitialized');
    } catch (e) {
      debugPrint('Initialize error: $e');
    }
  }

  Future<void> _toggleVoice() async {
    if (!_isInitialized) {
      await _initialize();
      if (!_isInitialized) return;
    }

    if (_isListening || _isSpeaking) {
      // إيقاف
      await _speech.stop();
      await _tts.stop();
      _stopAnimations();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
      return;
    }

    // بدء المحادثة
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

  Future<void> _startConversation() async {
    setState(() {
      _isSpeaking = true;
    });
    
    _startAnimations();
    HapticFeedback.mediumImpact();

    // رسالة ترحيب
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour < 12) {
      greeting = _userName != null 
          ? "Good morning, $_userName! How can I help you?" 
          : "Good morning! How can I help you?";
    } else if (hour < 17) {
      greeting = _userName != null 
          ? "Good afternoon, $_userName! What would you like?" 
          : "Good afternoon! What would you like?";
    } else {
      greeting = _userName != null 
          ? "Good evening, $_userName! How can I assist you?" 
          : "Good evening! How can I assist you?";
    }
    
    await _speak(greeting);
    
    // بدء الاستماع
    await _startListening();
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
    await Future.delayed(Duration(milliseconds: text.length * 70));
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _isSpeaking = false;
    });

    try {
      bool gotFinalResult = false;
      
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          
          if (result.finalResult && !gotFinalResult) {
            gotFinalResult = true;
            _processCommand(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      await Future.delayed(const Duration(seconds: 8));
      
      if (mounted && _isListening && !gotFinalResult) {
        await _speech.stop();
        await _handleNoResponse();
      }
    } catch (e) {
      debugPrint('Listen error: $e');
      _stopAnimations();
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _processCommand(String text) async {
    if (text.trim().isEmpty) {
      await _handleNoResponse();
      return;
    }

    setState(() {
      _isListening = false;
      _isSpeaking = true;
    });

    final command = _analyzeCommand(text);
    
    if (command != null) {
      String confirmation = _getConfirmation(command);
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
      await _speak("I'm not sure what you mean. Try saying: medications, media, or home.");
      
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
    
    await _speak("I didn't hear you. Please try again.");
    
    _stopAnimations();
    
    setState(() {
      _isSpeaking = false;
    });
  }

  VoiceCommand? _analyzeCommand(String text) {
    final lower = text.toLowerCase().trim();
    
    if (_containsAny(lower, [
      'medication', 'medicine', 'med', 'pill', 'drug',
      'دواء', 'أدوية', 'حبوب'
    ])) {
      return VoiceCommand.goToMedication;
    }
    
    if (_containsAny(lower, [
      'media', 'video', 'music', 'watch', 'listen',
      'ميديا', 'فيديو'
    ])) {
      return VoiceCommand.goToMedia;
    }
    
    if (_containsAny(lower, [
      'home', 'main', 'back',
      'رئيسية', 'رجوع'
    ])) {
      return VoiceCommand.goToHome;
    }
    
    if (_containsAny(lower, [
      'sos', 'emergency', 'help',
      'طوارئ', 'مساعدة'
    ])) {
      return VoiceCommand.sos;
    }
    
    return null;
  }

  String _getConfirmation(VoiceCommand command) {
    switch (command) {
      case VoiceCommand.goToMedication:
        return "Opening your medications.";
      case VoiceCommand.addMedication:
        return "Adding a new medication.";
      case VoiceCommand.goToMedia:
        return "Opening your media.";
      case VoiceCommand.goToHome:
        return "Going to home.";
      case VoiceCommand.sos:
        return "Activating emergency!";
      default:
        return "Got it!";
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleVoice,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple Rings
            if (_isListening || _isSpeaking) ...[
              AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(100, 100),
                    painter: RipplePainter(
                      animation: _rippleController.value,
                      color: (_isListening ? Colors.red : Colors.blue),
                    ),
                  );
                },
              ),
            ],
            
            // Main Button
            AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _rotateController]),
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
                          colors: [
                            (_isListening || _isSpeaking)
                                ? Colors.red
                                : const Color(0xFF1B3A52),
                            (_isListening || _isSpeaking)
                                ? Colors.red.shade700
                                : const Color(0xFF2C5F7D),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ((_isListening || _isSpeaking)
                                    ? Colors.red
                                    : const Color(0xFF1B3A52))
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
    );
  }
}

// Custom Painter للتوهجات الدائرية
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

    // رسم 3 دوائر متحركة
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

enum VoiceCommand {
  goToMedication,
  addMedication,
  goToMedia,
  goToHome,
  sos,
}