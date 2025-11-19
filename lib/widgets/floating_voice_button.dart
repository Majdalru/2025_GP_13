import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class FloatingVoiceButton extends StatefulWidget {
  final Function(VoiceCommand, {Map<String, dynamic>? data}) onCommand;

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
  String? _elderlyId;
  
  // للحوار المتقدم
  ConversationState _conversationState = ConversationState.idle;
  String? _pendingMedicationName;
  List<Map<String, dynamic>> _availableMedications = [];
  
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
        _elderlyId = user.uid;
        
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
        
        // تحميل الأدوية
        await _loadMedications();
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _loadMedications() async {
    try {
      if (_elderlyId == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('medications')
          .doc(_elderlyId)
          .get();
      
      if (doc.exists && doc.data()?['medsList'] != null) {
        final medsList = doc.data()!['medsList'] as List;
        setState(() {
          _availableMedications = medsList
              .map((m) => {
                    'id': m['id'],
                    'name': m['name'],
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading medications: $e');
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
      await _speech.stop();
      await _tts.stop();
      _stopAnimations();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
        _conversationState = ConversationState.idle;
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

  Future<void> _startConversation() async {
    setState(() {
      _isSpeaking = true;
      _conversationState = ConversationState.greeting;
    });
    
    _startAnimations();
    HapticFeedback.mediumImpact();

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
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      await Future.delayed(const Duration(seconds: 10));
      
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

    // معالجة حسب حالة المحادثة
    switch (_conversationState) {
      case ConversationState.greeting:
        await _handleGreetingResponse(text);
        break;
      
      case ConversationState.waitingForMedicationName:
        await _handleMedicationNameResponse(text);
        break;
      
      case ConversationState.waitingForEditSelection:
        await _handleEditSelectionResponse(text);
        break;
      
      case ConversationState.waitingForDeleteConfirmation:
        await _handleDeleteConfirmationResponse(text);
        break;
      
      default:
        await _handleGreetingResponse(text);
    }
  }

  Future<void> _handleGreetingResponse(String text) async {
    final command = _analyzeCommand(text);
    
    if (command != null) {
      switch (command) {
        case VoiceCommand.addMedication:
          await _speak("Sure! What's the name of the medication you want to add?");
          setState(() {
            _conversationState = ConversationState.waitingForMedicationName;
          });
          await _startListening();
          break;
        
        case VoiceCommand.editMedication:
          if (_availableMedications.isEmpty) {
            await _speak("You don't have any medications to edit yet.");
            _stopAnimations();
            setState(() {
              _isSpeaking = false;
              _conversationState = ConversationState.idle;
            });
          } else {
            final medNames = _availableMedications.map((m) => m['name']).join(', ');
            await _speak("Which medication would you like to edit? You have: $medNames");
            setState(() {
              _conversationState = ConversationState.waitingForEditSelection;
            });
            await _startListening();
          }
          break;
        
        case VoiceCommand.deleteMedication:
          if (_availableMedications.isEmpty) {
            await _speak("You don't have any medications to delete.");
            _stopAnimations();
            setState(() {
              _isSpeaking = false;
              _conversationState = ConversationState.idle;
            });
          } else {
            final medNames = _availableMedications.map((m) => m['name']).join(', ');
            await _speak("Which medication would you like to delete? You have: $medNames");
            setState(() {
              _conversationState = ConversationState.waitingForDeleteConfirmation;
            });
            await _startListening();
          }
          break;
        
        case VoiceCommand.goToMedication:
          await _speak("Opening your medications.");
          HapticFeedback.heavyImpact();
          _stopAnimations();
          setState(() {
            _isSpeaking = false;
            _conversationState = ConversationState.idle;
          });
          widget.onCommand(command);
          break;
        
        case VoiceCommand.goToMedia:
          await _speak("Opening your media.");
          HapticFeedback.heavyImpact();
          _stopAnimations();
          setState(() {
            _isSpeaking = false;
            _conversationState = ConversationState.idle;
          });
          widget.onCommand(command);
          break;
        
        default:
          await _speak("Got it!");
          HapticFeedback.heavyImpact();
          _stopAnimations();
          setState(() {
            _isSpeaking = false;
            _conversationState = ConversationState.idle;
          });
          widget.onCommand(command);
      }
    } else {
      await _speak("I can help you add, edit, or delete medications. Or open medications and media. What would you like?");
      setState(() {
        _isSpeaking = false;
      });
      _stopAnimations();
    }
  }

  Future<void> _handleMedicationNameResponse(String text) async {
    _pendingMedicationName = text.trim();
    
    await _speak("Great! Opening the form to add $_pendingMedicationName.");
    
    HapticFeedback.heavyImpact();
    _stopAnimations();
    
    setState(() {
      _isSpeaking = false;
      _conversationState = ConversationState.idle;
    });
    
    widget.onCommand(
      VoiceCommand.addMedication,
      data: {'medicationName': _pendingMedicationName},
    );
  }

  Future<void> _handleEditSelectionResponse(String text) async {
    final selectedMed = _findMedicationByName(text);
    
    if (selectedMed != null) {
      await _speak("Opening ${selectedMed['name']} for editing.");
      
      HapticFeedback.heavyImpact();
      _stopAnimations();
      
      setState(() {
        _isSpeaking = false;
        _conversationState = ConversationState.idle;
      });
      
      widget.onCommand(
        VoiceCommand.editMedication,
        data: {'medicationId': selectedMed['id']},
      );
    } else {
      await _speak("I couldn't find that medication. Please try again.");
      await _startListening();
    }
  }

  Future<void> _handleDeleteConfirmationResponse(String text) async {
    final selectedMed = _findMedicationByName(text);
    
    if (selectedMed != null) {
      await _speak("Are you sure you want to delete ${selectedMed['name']}? Say yes to confirm.");
      
      setState(() {
        _pendingMedicationName = selectedMed['name'];
        _conversationState = ConversationState.waitingForFinalDeleteConfirmation;
      });
      
      await _startListening();
    } else {
      await _speak("I couldn't find that medication. Please try again.");
      await _startListening();
    }
  }

  Map<String, dynamic>? _findMedicationByName(String spokenName) {
    final lower = spokenName.toLowerCase().trim();
    
    for (final med in _availableMedications) {
      if (med['name'].toString().toLowerCase().contains(lower) ||
          lower.contains(med['name'].toString().toLowerCase())) {
        return med;
      }
    }
    
    return null;
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
      _conversationState = ConversationState.idle;
    });
  }

  VoiceCommand? _analyzeCommand(String text) {
    final lower = text.toLowerCase().trim();
    
    // Add medication
    if (_containsAny(lower, [
      'add medication', 'add medicine', 'add new medication', 'add med',
      'new medication', 'create medication', 'add a medication',
      'أضف دواء', 'دواء جديد', 'اضافة دواء'
    ])) {
      return VoiceCommand.addMedication;
    }
    
    // Edit medication
    if (_containsAny(lower, [
      'edit medication', 'edit medicine', 'change medication', 'modify medication',
      'update medication', 'edit med',
      'عدل دواء', 'تعديل دواء', 'غير دواء'
    ])) {
      return VoiceCommand.editMedication;
    }
    
    // Delete medication
    if (_containsAny(lower, [
      'delete medication', 'delete medicine', 'remove medication', 'delete med',
      'احذف دواء', 'حذف دواء', 'امسح دواء'
    ])) {
      return VoiceCommand.deleteMedication;
    }
    
    // View medications
    if (_containsAny(lower, [
      'medication', 'medicine', 'show medication', 'my medications',
      'دواء', 'أدوية', 'ادويتي'
    ])) {
      return VoiceCommand.goToMedication;
    }
    
    // Media
    if (_containsAny(lower, [
      'media', 'video', 'music',
      'ميديا', 'فيديو'
    ])) {
      return VoiceCommand.goToMedia;
    }
    
    // Home
    if (_containsAny(lower, [
      'home', 'main', 'back',
      'رئيسية', 'رجوع'
    ])) {
      return VoiceCommand.goToHome;
    }
    
    // SOS
    if (_containsAny(lower, [
      'sos', 'emergency', 'help',
      'طوارئ', 'مساعدة'
    ])) {
      return VoiceCommand.sos;
    }
    
    return null;
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

enum ConversationState {
  idle,
  greeting,
  waitingForMedicationName,
  waitingForEditSelection,
  waitingForDeleteConfirmation,
  waitingForFinalDeleteConfirmation,
}

enum VoiceCommand {
  goToMedication,
  addMedication,
  editMedication,
  deleteMedication,
  goToMedia,
  goToHome,
  sos,
}