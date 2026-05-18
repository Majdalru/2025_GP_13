import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/location_service.dart';
import 'media_page.dart';
import 'elderly_med.dart';
//import 'family_messages_page.dart';
import 'daily_library_page.dart';
import 'shared_media_list_page.dart';

import 'favorites_manager.dart';
import '../../Screens/login_page.dart';

import '../../widgets/floating_voice_button.dart';
import '../../widgets/arabic_floating_voice_button.dart';

import '../../services/voice_assistant_service.dart';
import '../../services/arabic_voice_assistant_service.dart';

import '../../providers/locale_provider.dart';
import 'package:flutter_application_1/models/voice_command.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

/// =====================
///  Styles (Unified)
/// =====================
const kPrimary = Color(0xFF1B3A52);
const kAccentRed = Color(0xFFD62828);
const kSurface = Color(0xFFF5F5F5);
const kCardRadius = 16.0;
const kFieldRadius = 14.0;

const kTitleText = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w800,
  color: kPrimary,
);

const kBodyText = TextStyle(fontSize: 22, color: Colors.black87);

const kButtonText = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

InputDecoration kInput(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(
    fontSize: 20,
    color: kPrimary,
    fontWeight: FontWeight.w600,
  ),
  filled: true,
  fillColor: Colors.white,
  focusedBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: kPrimary, width: 2),
    borderRadius: BorderRadius.circular(kFieldRadius),
  ),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(kFieldRadius)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
);

ButtonStyle kBigButton(Color bg, {EdgeInsets? pad}) => ElevatedButton.styleFrom(
  backgroundColor: bg,
  padding: pad ?? const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 4,
);

class ElderlyHomePage extends StatefulWidget {
  const ElderlyHomePage({super.key});

  @override
  State<ElderlyHomePage> createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  String? fullName;
  // news

  // done
  final locationService = LocationService();

  Future<void> saveElderlyLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("No user logged in");
        return;
      }

      final position = await locationService.getCurrentLocation();

      await FirebaseFirestore.instance
          .collection('elderly_locations')
          .doc(user.uid)
          .set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      debugPrint(
        "Elderly location saved: ${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      debugPrint("Error saving elderly location: $e");
    }
  }

  Future<void> sendEmergencyAlert() async {
    try {
      if (_isSendingEmergency) return;

      setState(() {
        _isSendingEmergency = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("No user logged in");
        return;
      }

      final position = await locationService.getCurrentLocation();

      await FirebaseFirestore.instance
          .collection('elderly_locations')
          .doc(user.uid)
          .set({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final alertRef = await FirebaseFirestore.instance
          .collection('emergency_alerts')
          .add({
            'elderlyId': user.uid,
            'elderlyName': fullName ?? 'Elderly',
            'latitude': position.latitude,
            'longitude': position.longitude,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      debugPrint("🚨 Emergency alert saved with ID: ${alertRef.id}");

      if (mounted) {
        setState(() {
          _latestAlertStatus = 'active';
        });
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  "Alert Sent",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              "Your emergency alert has been sent to the caregiver.\nHelp is on the way.",
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );

      if (mounted) {
        setState(() {
          _isSendingEmergency = false;
        });
      }

      debugPrint(
        "Emergency alert sent: ${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      debugPrint("Error sending emergency alert: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sending emergency alert: $e"),
          backgroundColor: Colors.red,
        ),
      );

      if (mounted) {
        setState(() {
          _isSendingEmergency = false;
        });
      }
    }
  }

  void _listenToMyEmergencyStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _emergencyStatusSub = FirebaseFirestore.instance
        .collection('emergency_alerts')
        .where('elderlyId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (!mounted || snapshot.docs.isEmpty) return;

          final data = snapshot.docs.first.data();
          final status = data['status']?.toString();

          setState(() {
            _latestAlertStatus = status;
          });

          if (status == 'seen') {
            final localeProvider = Provider.of<LocaleProvider>(
              context,
              listen: false,
            );
            final isArabic = localeProvider.isArabic;

            _showStatusMessage(
              title: isArabic ? 'تمت مشاهدة التنبيه' : 'Alert Seen',
              message: isArabic
                  ? 'الكيرقيفر شاهد تنبيه الطوارئ الخاص بك.'
                  : 'Your caregiver has seen your emergency alert.',
              icon: Icons.visibility_rounded,
              color: Colors.green.shade700,
            );
          }
        });
  }

  void _startSosHold(bool isArabic) {
    if (_isSendingEmergency) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _isHoldingSos = true;
      _sosHoldProgress = 0.0;
    });

    const totalMilliseconds = 2000;
    const stepMilliseconds = 100;
    int elapsed = 0;

    _sosHoldTimer?.cancel();
    _sosHoldTimer = Timer.periodic(
      const Duration(milliseconds: stepMilliseconds),
      (timer) async {
        elapsed += stepMilliseconds;

        if (mounted) {
          setState(() {
            _sosHoldProgress = elapsed / totalMilliseconds;
          });
        }

        if (elapsed % 400 == 0) {
          HapticFeedback.selectionClick();
        }

        if (elapsed >= totalMilliseconds) {
          timer.cancel();

          if (!mounted) return;

          setState(() {
            _isHoldingSos = false;
            _sosHoldProgress = 1.0;
          });

          HapticFeedback.heavyImpact();
          await sendEmergencyAlert();

          if (mounted) {
            setState(() {
              _sosHoldProgress = 0.0;
            });
          }
        }
      },
    );
  }

  void _cancelSosHold() {
    _sosHoldTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isHoldingSos = false;
      _sosHoldProgress = 0.0;
    });
  }

  String _translateGender(String? g) {
    if (g == null || g.isEmpty) {
      return AppLocalizations.of(context)!.na;
    }

    switch (g.toLowerCase()) {
      case 'male':
        return AppLocalizations.of(context)!.male;
      case 'female':
        return AppLocalizations.of(context)!.female;
      default:
        return g;
    }
  }

  String? gender;
  String? phone;
  List<String> caregiverNames = [];
  bool loading = true;

  final VoiceAssistantService _voice = VoiceAssistantService();
  final ArabicVoiceAssistantService _arabicVoice =
      ArabicVoiceAssistantService();

  StreamSubscription<DocumentSnapshot>? _userSub;
  int _prevCaregiverCount = 0;
  bool _initialCaregiverLoaded = false;
  bool _didRunNewsTest = false;

  bool _medicationsEnabled = true;
  bool _libraryEnabled = true;
  bool _mediaEnabled = true;

  // Voice card state — updated via onStateChange callbacks from the button widgets
  bool _voiceIsListening = false;
  bool _voiceIsSpeaking = false;

  bool _isSendingEmergency = false;
  String? _latestAlertStatus;
  StreamSubscription<QuerySnapshot>? _emergencyStatusSub;

  Timer? _sosHoldTimer;
  double _sosHoldProgress = 0.0;
  bool _isHoldingSos = false;

  @override
  void initState() {
    super.initState();
    _listenToUserDoc();
    favoritesManager.init();
    saveElderlyLocation();
    _listenToMyEmergencyStatus();
  }

  //here test news

  void _showTopBanner(
    String message, {
    Color color = kPrimary,
    int seconds = 5,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: color,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );

    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  void _showStatusMessage({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    int seconds = 4,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          elevation: 6,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );

    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final out = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return out;
  }

  void _listenToUserDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) async {
            if (!doc.exists) {
              if (mounted) {
                setState(() => loading = false);
              }
              return;
            }

            final data = doc.data() as Map<String, dynamic>;

            final first = (data['firstName'] ?? '').toString().trim();
            final last = (data['lastName'] ?? '').toString().trim();
            final newFullName = [
              first,
              last,
            ].where((s) => s.isNotEmpty).join(' ');
            final newGender = (data['gender'] ?? '').toString();
            final newPhone = (data['phone'] ?? '').toString();

            final ids = (data['caregiverIds'] is List)
                ? List<String>.from(data['caregiverIds'])
                : <String>[];

            final names = <String>[];

            if (ids.isNotEmpty) {
              for (final batch in _chunk(ids, 10)) {
                final qs = await FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: batch)
                    .get();

                for (final d in qs.docs) {
                  final x = d.data();
                  final f = (x['firstName'] ?? '').toString().trim();
                  final l = (x['lastName'] ?? '').toString().trim();
                  final email = (x['email'] ?? '').toString().trim();
                  final n = [f, l].where((s) => s.isNotEmpty).join(' ');
                  names.add(
                    n.isNotEmpty ? n : (email.isNotEmpty ? email : 'Unknown'),
                  );
                }
              }
            }

            final newCount = names.length;

            if (!_initialCaregiverLoaded) {
              _prevCaregiverCount = newCount;
              _initialCaregiverLoaded = true;
            } else {
              if (mounted) {
                if (newCount > _prevCaregiverCount) {
                  _showTopBanner(
                    AppLocalizations.of(context)!.newCaregiverLinked,
                    color: Colors.green.shade700,
                  );
                } else if (newCount < _prevCaregiverCount) {
                  _showTopBanner(
                    AppLocalizations.of(context)!.caregiverUnlinked,
                    color: kAccentRed,
                  );
                }
              }
              _prevCaregiverCount = newCount;
            }

            final permissions = data['permissions'] as Map<String, dynamic>?;

            if (!mounted) return;

            setState(() {
              fullName = newFullName;
              gender = newGender;
              phone = newPhone;
              caregiverNames = names;
              _medicationsEnabled = permissions?['medications'] ?? true;
              _libraryEnabled = permissions?['library'] ?? true;
              _mediaEnabled = permissions?['media'] ?? true;
              loading = false;
            });
          },
          onError: (e) {
            if (mounted) {
              setState(() => loading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                      context,
                    )!.errorLoadingProfile(e.toString()),
                  ),
                ),
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _emergencyStatusSub?.cancel();
    _sosHoldTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: kSurface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final localeProvider = Provider.of<LocaleProvider>(context);
    final bool isArabic = localeProvider.isArabic;

    // Color palette for new design
    const kTeal = Color(0xFF4DB6AC);
    const kTealDark = Color(0xFF00897B);
    const kServiceBg = Colors.white;
    const kEmergencyRed = Color(0xFFE53935);

    final bool alertActive = _latestAlertStatus == 'active';
    final bool alertSeen = _latestAlertStatus == 'seen';

    final Color emergencyButtonColor = alertSeen
        ? Colors.green
        : alertActive
        ? Colors.orange.shade700
        : kEmergencyRed;

    final Color emergencyButtonBg = alertSeen
        ? Colors.green.withOpacity(0.10)
        : alertActive
        ? Colors.orange.withOpacity(0.12)
        : _isHoldingSos
        ? kEmergencyRed.withOpacity(0.18)
        : kEmergencyRed.withOpacity(0.10);

    final Color emergencyButtonBorder = alertSeen
        ? Colors.green.withOpacity(0.5)
        : alertActive
        ? Colors.orange.withOpacity(0.55)
        : kEmergencyRed.withOpacity(0.4);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Greeting
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'صباح الخير،' : 'Good morning,',
                        style: const TextStyle(
                          fontSize: 18,
                          color: kTealDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        fullName?.split(' ').first ?? '',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                    ],
                  ),
                  // Settings icon (opens AppDrawer as a page)
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 34,
                      color: Color(0xFF1A2340),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ElderlySettingsPage(
                            fullName: fullName ?? '',
                            gender: gender ?? '',
                            phone: phone ?? '',
                            caregiverNames: caregiverNames,
                            onSave: (newName, newGender, newPhone) async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final parts = newName.split(RegExp(r'\s+'));
                                final first = parts.isNotEmpty
                                    ? parts.first
                                    : '';
                                final last = parts.length > 1
                                    ? parts.sublist(1).join(' ')
                                    : '';
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                      'firstName': first,
                                      'lastName': last,
                                      'gender': newGender,
                                      'phone': newPhone,
                                    });
                                if (mounted) {
                                  setState(() {
                                    fullName = newName;
                                    gender = newGender;
                                    phone = newPhone;
                                  });
                                  _showTopBanner(
                                    AppLocalizations.of(
                                      context,
                                    )!.informationUpdatedSuccessfully,
                                    color: Colors.green.shade700,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ─── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Voice Assistant Card ─────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _voiceIsListening
                              ? [
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF66BB6A),
                                ] // green — listening
                              : _voiceIsSpeaking
                              ? [
                                  const Color(0xFFC62828),
                                  const Color(0xFFEF5350),
                                ] // red — speaking
                              : [
                                  const Color(0xFF4DB6AC),
                                  const Color(0xFF00897B),
                                ], // teal — idle
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_voiceIsListening
                                        ? const Color(0xFF2E7D32)
                                        : _voiceIsSpeaking
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF4DB6AC))
                                    .withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          // Voice button widget (keeps all its animation states)
                          isArabic
                              ? ArabicFloatingVoiceButton(
                                  onStateChange: (isListening, isSpeaking) {
                                    if (mounted) {
                                      setState(() {
                                        _voiceIsListening = isListening;
                                        _voiceIsSpeaking = isSpeaking;
                                      });
                                    }
                                  },
                                  onCommand: (command) async {
                                    final uid =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    debugPrint(
                                      '🎯 Arabic voice command received in ElderlyHomePage: $command',
                                    );
                                    switch (command) {
                                      case VoiceCommand.goToMedication:
                                        if (uid != null) {
                                          if (!mounted) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ElderlyMedicationPage(
                                                    elderlyId: uid,
                                                    isMedicationsEnabled:
                                                        _medicationsEnabled,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          await _arabicVoice.speak(
                                            'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                          );
                                        }
                                        break;
                                      case VoiceCommand.addMedication:
                                        if (!_medicationsEnabled) {
                                          await _arabicVoice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (uid == null) {
                                          await _arabicVoice.speak(
                                            'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                          );
                                          return;
                                        }
                                        await _arabicVoice.speak(
                                          'حسنًا، سأساعدك في إضافة دواء جديد.',
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ElderlyMedicationPage(
                                                  elderlyId: uid,
                                                  isMedicationsEnabled:
                                                      _medicationsEnabled,
                                                  initialCommand: VoiceCommand
                                                      .addMedication,
                                                ),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.editMedication:
                                        if (!_medicationsEnabled) {
                                          await _arabicVoice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (uid == null) {
                                          await _arabicVoice.speak(
                                            'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                          );
                                          return;
                                        }
                                        await _arabicVoice.speak(
                                          'حسنًا، لنعدّل أحد أدويتك.',
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ElderlyMedicationPage(
                                                  elderlyId: uid,
                                                  isMedicationsEnabled:
                                                      _medicationsEnabled,
                                                  initialCommand: VoiceCommand
                                                      .editMedication,
                                                ),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.deleteMedication:
                                        if (!_medicationsEnabled) {
                                          await _arabicVoice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (uid == null) {
                                          await _arabicVoice.speak(
                                            'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.',
                                          );
                                          return;
                                        }
                                        await _arabicVoice.speak(
                                          'حسنًا، لنحذف أحد أدويتك.',
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ElderlyMedicationPage(
                                                  elderlyId: uid,
                                                  isMedicationsEnabled:
                                                      _medicationsEnabled,
                                                  initialCommand: VoiceCommand
                                                      .deleteMedication,
                                                ),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.goToMedia:
                                        if (!_mediaEnabled) {
                                          await _arabicVoice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const MediaPage(),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.goToHome:
                                        await _arabicVoice.speak(
                                          'أنت بالفعل في الصفحة الرئيسية.',
                                        );
                                        break;
                                      case VoiceCommand.weather:
                                      case VoiceCommand.news:
                                      case VoiceCommand.goToDailyLibrary:
                                        if (!_libraryEnabled) {
                                          await _arabicVoice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const DailyLibraryPage(),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.sos:
                                        if (!mounted) return;
                                        await _arabicVoice.speak(
                                          AppLocalizations.of(
                                            context,
                                          )!.voiceSosPreamble,
                                        );
                                        await sendEmergencyAlert();
                                        break;
                                      case VoiceCommand.goToSettings:
                                        await _arabicVoice.speak(
                                          'صفحة الإعدادات ليست جاهزة بعد.',
                                        );
                                        break;
                                      case VoiceCommand.todayMedications:
                                        if (uid == null) {
                                          await _arabicVoice.speak(
                                            'لم أتمكن من العثور على حسابك.',
                                          );
                                          return;
                                        }
                                        await _arabicVoice
                                            .runTodayMedicationsFlow(uid);
                                        break;
                                    }
                                  },
                                )
                              : FloatingVoiceButton(
                                  onStateChange: (isListening, isSpeaking) {
                                    if (mounted) {
                                      setState(() {
                                        _voiceIsListening = isListening;
                                        _voiceIsSpeaking = isSpeaking;
                                      });
                                    }
                                  },
                                  onCommand: (command) async {
                                    final uid =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    switch (command) {
                                      case VoiceCommand.goToMedication:
                                        if (uid != null) {
                                          if (!mounted) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ElderlyMedicationPage(
                                                    elderlyId: uid,
                                                    isMedicationsEnabled:
                                                        _medicationsEnabled,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          await _voice.speak(
                                            "I could not find your account. Please log in again.",
                                          );
                                        }
                                        break;
                                      case VoiceCommand.addMedication:
                                        if (!_medicationsEnabled) {
                                          await _voice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (uid == null) {
                                          await _voice.speak(
                                            "I could not find your account. Please log in again.",
                                          );
                                          return;
                                        }
                                        await _voice.speak(
                                          "Okay, let me help you add a new medication.",
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ElderlyMedicationPage(
                                                  elderlyId: uid,
                                                  isMedicationsEnabled:
                                                      _medicationsEnabled,
                                                  initialCommand: VoiceCommand
                                                      .addMedication,
                                                ),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.editMedication:
                                        if (!_medicationsEnabled) {
                                          await _voice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (uid == null) {
                                          await _voice.speak(
                                            "I could not find your account. Please log in again.",
                                          );
                                          return;
                                        }
                                        await _voice.speak(
                                          "Okay, let us edit one of your medications.",
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ElderlyMedicationPage(
                                                  elderlyId: uid,
                                                  isMedicationsEnabled:
                                                      _medicationsEnabled,
                                                  initialCommand: VoiceCommand
                                                      .editMedication,
                                                ),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.deleteMedication:
                                        if (!_medicationsEnabled) {
                                          await _voice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (uid == null) {
                                          await _voice.speak(
                                            "I could not find your account. Please log in again.",
                                          );
                                          return;
                                        }
                                        await _voice.speak(
                                          "Okay, let us choose which medication to delete.",
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ElderlyMedicationPage(
                                                  elderlyId: uid,
                                                  isMedicationsEnabled:
                                                      _medicationsEnabled,
                                                  initialCommand: VoiceCommand
                                                      .deleteMedication,
                                                ),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.goToMedia:
                                        if (!_mediaEnabled) {
                                          await _voice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const MediaPage(),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.goToHome:
                                        await _voice.speak(
                                          "You are already on the home page.",
                                        );
                                        break;
                                      case VoiceCommand.weather:
                                      case VoiceCommand.news:
                                      case VoiceCommand.goToDailyLibrary:
                                        if (!_libraryEnabled) {
                                          await _voice.speak(
                                            AppLocalizations.of(
                                              context,
                                            )!.featureDisabledByCaregiver,
                                          );
                                          return;
                                        }
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const DailyLibraryPage(),
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.sos:
                                        if (!mounted) return;
                                        await _voice.speak(
                                          AppLocalizations.of(
                                            context,
                                          )!.voiceSosPreamble,
                                        );
                                        await sendEmergencyAlert();
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.emergencyTitle,
                                            ),
                                            content: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.emergencyFlowDesc,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.ok,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        break;
                                      case VoiceCommand.goToSettings:
                                        await _voice.speak(
                                          "Settings page is not ready yet. In the future, I will open it for you from here.",
                                        );
                                        break;
                                      case VoiceCommand.todayMedications:
                                        final uid2 = FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid;
                                        if (uid2 == null) {
                                          await _voice.speak(
                                            "I could not find your account. Please log in again.",
                                          );
                                          return;
                                        }
                                        await _voice.runTodayMedicationsFlow(
                                          uid2,
                                        );
                                        break;
                                    }
                                  },
                                ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _voiceIsListening
                                        ? (isArabic
                                              ? 'استمع إليك...'
                                              : 'Listening...')
                                        : _voiceIsSpeaking
                                        ? (isArabic
                                              ? 'المساعد يتحدث'
                                              : 'Assistant is talking')
                                        : (isArabic
                                              ? 'اضغط للتحدث'
                                              : 'Tap to speak'),
                                    key: ValueKey(
                                      '$_voiceIsListening-$_voiceIsSpeaking',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _voiceIsListening
                                        ? (isArabic
                                              ? 'دورك للكلام 🎤'
                                              : 'Your turn to speak 🎤')
                                        : _voiceIsSpeaking
                                        ? (isArabic
                                              ? 'انتظر لحظة...'
                                              : 'Please wait...')
                                        : (isArabic
                                              ? 'المساعد الصوتي جاهز'
                                              : 'Voice assistant ready'),
                                    key: ValueKey(
                                      'sub-$_voiceIsListening-$_voiceIsSpeaking',
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Section label ────────────────────────────────
                    Text(
                      isArabic ? 'الخدمات' : 'Services',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 2×2 Service Grid ─────────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.05,
                      children: [
                        // Medications
                        _GridServiceCard(
                          icon: Icons.medication_outlined,
                          iconColor: const Color(0xFF4CAF50),
                          iconBg: const Color(0xFFE8F5E9),
                          title: isArabic ? 'أدويتي' : 'Medications',
                          enabled: _medicationsEnabled,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ElderlyMedicationPage(
                                    elderlyId: uid,
                                    isMedicationsEnabled: _medicationsEnabled,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.errorNotLoggedIn2,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        // News & Weather (Daily Library)
                        _GridServiceCard(
                          icon: Icons.wb_sunny_outlined,
                          iconColor: const Color(0xFFFF8F00),
                          iconBg: const Color(0xFFFFF8E1),
                          title: isArabic
                              ? 'الأخبار\nوالطقس'
                              : 'News &\nWeather',
                          enabled: _libraryEnabled,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DailyLibraryPage(),
                              ),
                            );
                          },
                        ),
                        // Media Library
                        _GridServiceCard(
                          icon: Icons.library_music_outlined,
                          iconColor: const Color(0xFF7E57C2),
                          iconBg: const Color(0xFFEDE7F6),
                          title: isArabic ? 'مكتبة الوسائط' : 'Media Library',
                          enabled: _mediaEnabled,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MediaPage(),
                              ),
                            );
                          },
                        ),
                        // Family Messages (stub — functions applied later)
                        _GridServiceCard(
                          icon: Icons.videocam_outlined,
                          iconColor: const Color(0xFFE91E8C),
                          iconBg: const Color(0xFFFCE4EC),
                          title: isArabic ? 'رسائل العائلة' : 'Family Messages',
                          enabled: true,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SharedMediaListPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),

            // ─── Emergency Button (bottom) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: () {
                  _showStatusMessage(
                    title: isArabic ? 'تنبيه' : 'Hold Required',
                    message: isArabic
                        ? 'اضغطي باستمرار حتى يكتمل الشريط لإرسال تنبيه الطوارئ.'
                        : 'Press and hold until the progress bar is full to send SOS.',
                    icon: Icons.touch_app_rounded,
                    color: Colors.orange.shade700,
                  );
                },
                onLongPressStart: (_) => _startSosHold(isArabic),
                onLongPressEnd: (_) {
                  if (_sosHoldProgress < 1.0) {
                    _cancelSosHold();
                  }
                },
                onLongPressCancel: _cancelSosHold,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: emergencyButtonBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: emergencyButtonBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: CircularProgressIndicator(
                                  value: _isHoldingSos ? _sosHoldProgress : 0,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    emergencyButtonColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: emergencyButtonColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _latestAlertStatus == 'seen'
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSendingEmergency
                                    ? (isArabic
                                          ? 'جارٍ الإرسال...'
                                          : 'Sending...')
                                    : _isHoldingSos
                                    ? (isArabic
                                          ? 'استمر بالضغط...'
                                          : 'Keep holding...')
                                    : alertSeen
                                    ? (isArabic
                                          ? 'تمت مشاهدة التنبيه'
                                          : 'Alert Seen')
                                    : alertActive
                                    ? (isArabic
                                          ? 'تم إرسال التنبيه'
                                          : 'Alert Sent')
                                    : (isArabic ? 'طوارئ' : 'Emergency'),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: emergencyButtonColor,
                                ),
                              ),
                              Text(
                                alertSeen
                                    ? (isArabic
                                          ? 'الكيرقيفر شاهد تنبيه الطوارئ'
                                          : 'Caregiver has seen your alert')
                                    : alertActive
                                    ? (isArabic
                                          ? 'بانتظار مشاهدة الكيرقيفر للتنبيه'
                                          : 'Waiting for caregiver to view the alert')
                                    : _isHoldingSos
                                    ? (isArabic
                                          ? 'لا ترفع إصبعك حتى يكتمل المؤشر'
                                          : 'Do not release until the indicator is full')
                                    : (isArabic
                                          ? 'اضغط باستمرار ثانيتين للإرسال'
                                          : 'Hold 2 seconds to send SOS'),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: emergencyButtonColor.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_isHoldingSos) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _sosHoldProgress,
                            minHeight: 8,
                            backgroundColor: Colors.red.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              emergencyButtonColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Settings Page (replaces drawer)
// ═══════════════════════════════════════════════════════════════════
class _ElderlySettingsPage extends StatelessWidget {
  final String fullName;
  final String gender;
  final String phone;
  final List<String> caregiverNames;
  final Function(String name, String gender, String phone) onSave;

  const _ElderlySettingsPage({
    required this.fullName,
    required this.gender,
    required this.phone,
    required this.caregiverNames,
    required this.onSave,
  });

  String _translateGender(BuildContext context, String? g) {
    if (g == null || g.isEmpty) return AppLocalizations.of(context)!.na;
    switch (g.toLowerCase()) {
      case 'male':
        return AppLocalizations.of(context)!.male;
      case 'female':
        return AppLocalizations.of(context)!.female;
      default:
        return g;
    }
  }

  @override
  Widget build(BuildContext context) {
    const kTeal = Color(0xFF4DB6AC);
    const kTealDark = Color(0xFF00897B);
    final isArabic = Provider.of<LocaleProvider>(context).isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar — matches home page style ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 26,
                      color: Color(0xFF1A2340),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.settings,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2340),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile header card — navy ──────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4DB6AC), Color(0xFF00897B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4DB6AC).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                      child: Row(
                        children: [
                          // Avatar circle
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName.isNotEmpty
                                      ? fullName
                                      : AppLocalizations.of(context)!.na,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      phone.isNotEmpty
                                          ? phone
                                          : AppLocalizations.of(context)!.na,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Edit button
                          Material(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _EditInfoDialog(
                                      initialName: fullName,
                                      initialGender: gender,
                                      initialPhone: phone,
                                      onSave: (n, g, p) async {
                                        onSave(n, g, p);
                                        if (context.mounted)
                                          Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Personal Info section ──────────────────────
                    _SectionLabel(AppLocalizations.of(context)!.elderlyInfo),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            iconColor: const Color(0xFF00897B),
                            iconBg: const Color(0xFFE0F2F1),
                            label: AppLocalizations.of(context)!.name,
                            value: fullName.isNotEmpty
                                ? fullName
                                : AppLocalizations.of(context)!.na,
                          ),
                          const _RowDivider(),
                          _InfoRow(
                            icon: Icons.wc_outlined,
                            iconColor: const Color(0xFF7E57C2),
                            iconBg: const Color(0xFFEDE7F6),
                            label: AppLocalizations.of(context)!.gender,
                            value: _translateGender(context, gender),
                          ),
                          const _RowDivider(),
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            iconColor: const Color(0xFFFF8F00),
                            iconBg: const Color(0xFFFFF8E1),
                            label: AppLocalizations.of(context)!.mobile,
                            value: phone.isNotEmpty
                                ? phone
                                : AppLocalizations.of(context)!.na,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Caregivers section ─────────────────────────
                    _SectionLabel(AppLocalizations.of(context)!.caregivers),
                    const SizedBox(height: 10),
                    _SettingsCard(child: _CaregiversBox(names: caregiverNames)),

                    const SizedBox(height: 22),

                    // ── Pairing code section ───────────────────────
                    _SectionLabel(
                      AppLocalizations.of(context)!.verificationCode,
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(child: const _PairingCodeBox()),

                    const SizedBox(height: 22),

                    // ── Language section ───────────────────────────
                    _SectionLabel(isArabic ? 'اللغة' : 'Language'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.language_outlined,
                                color: Color(0xFF00897B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'لغة التطبيق' : 'App Language',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isArabic ? 'العربية' : 'English',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A2340),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Toggle pill
                            GestureDetector(
                              onTap: () {
                                final provider = Provider.of<LocaleProvider>(
                                  context,
                                  listen: false,
                                );
                                provider.toggleLanguage();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: 72,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4DB6AC),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 👇 WRAP THE BACKGROUND ROW WITH DIRECTIONALITY TO PREVENT RTL FLIPPING
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: const [
                                          Text(
                                            'EN',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'ع',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                      alignment: isArabic
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.all(3),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.15,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            isArabic ? 'ع' : 'EN',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF1A2340),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Logout button ──────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEBEE),
                          foregroundColor: kAccentRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: kAccentRed.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 26),
                        label: Text(
                          AppLocalizations.of(context)!.logOut,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _LogoutConfirmPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Logout Confirmation Page
// ═══════════════════════════════════════════════════════════════════
class _LogoutConfirmPage extends StatelessWidget {
  const _LogoutConfirmPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 26,
                      color: Color(0xFF1A2340),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content — centered vertically
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Red icon badge
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kAccentRed.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: kAccentRed,
                        size: 52,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      AppLocalizations.of(context)!.confirmLogout,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2340),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      AppLocalizations.of(context)!.doYouReallyWantToLogOut,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 52),

                    // Stay button (navy outlined)
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF1A2340),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalizations.of(context)!.no,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xFF1A2340),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Logout button (red filled)
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentRed,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 26),
                        label: Text(
                          AppLocalizations.of(context)!.logOut,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          FirebaseAuth.instance.signOut();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (_) => false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label helper ──────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
      ),
    );
  }
}

// ── Single info row inside a card ─────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thin divider between info rows ───────────────────────────────
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFFF7F8FA),
      indent: 50,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Grid Service Card (new design)
// ═══════════════════════════════════════════════════════════════════
class _GridServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  const _GridServiceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
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
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: kTitleText),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: kPrimary.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(value, style: kBodyText),
        ),
      ],
    );
  }
}

class _CaregiversBox extends StatelessWidget {
  final List<String> names;

  const _CaregiversBox({required this.names});

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_outline,
                color: Color(0xFF00897B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              AppLocalizations.of(context)!.noCaregiversLinked,
              style: const TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: names.asMap().entries.map((entry) {
        final name = entry.value;
        final isLast = entry.key == names.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF00897B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Caregiver',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A2340),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                thickness: 1,
                color: const Color(0xFFF7F8FA),
                indent: 50,
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _PairingCodeBox extends StatefulWidget {
  const _PairingCodeBox();

  @override
  State<_PairingCodeBox> createState() => _PairingCodeBoxState();
}

class _PairingCodeBoxState extends State<_PairingCodeBox> {
  String? _code;
  Timer? _timer;
  int _countdown = 300;
  bool _isLoading = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 300;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _code = null);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _generateNewCode() async {
    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.youNeedToBeLoggedIn),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final newCode = List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'pairingCode': newCode,
            'pairingCodeCreatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          _code = newCode;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorGeneratingCode(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_code != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: kPrimary.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Text(
                  _code!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expires in: ${_formatDuration(_countdown)}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        const SizedBox(height: 15),
        ElevatedButton(
          style: kBigButton(
            const Color.fromARGB(255, 61, 137, 113),
            pad: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
          onPressed: _isLoading ? null : _generateNewCode,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  AppLocalizations.of(context)!.generateCode,
                  style: kButtonText,
                ),
        ),
      ],
    );
  }
}

class _EditInfoDialog extends StatefulWidget {
  final String initialName;
  final String initialGender;
  final String initialPhone;
  final Function(String name, String gender, String phone) onSave;

  const _EditInfoDialog({
    required this.initialName,
    required this.initialGender,
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<_EditInfoDialog> createState() => _EditInfoDialogState();
}

class _EditInfoDialogState extends State<_EditInfoDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _selectedGender;
  final _formKey = GlobalKey<FormState>();
  String? _phoneUsedError;
  bool _isSaving = false;

  // Navy palette — replaces teal for better elderly contrast
  static const kNavy = Color(0xFF1A2340);
  static const kNavyLight = Color(0xFFEEF0F5);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _selectedGender = widget.initialGender.isNotEmpty
        ? widget.initialGender
        : 'male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _isPhoneAvailable(String phone) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return true;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      return snap.docs.first.id == currentUid;
    } catch (e) {
      debugPrint('⚠️ phone uniqueness check failed: $e');
      return true;
    }
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 18,
        color: Color(0xFF6B7280),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kNavyLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: kNavy, size: 22),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kNavy.withOpacity(0.15), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kNavy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kAccentRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kAccentRed, width: 2),
      ),
      errorStyle: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LocaleProvider>(
      context,
      listen: false,
    ).isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 26,
                      color: kNavy,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.editInformation,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: kNavy,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      _FieldLabel(isArabic ? 'الاسم الكامل' : 'Full Name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                          fontSize: 22,
                          color: kNavy,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _fieldDecoration(
                          AppLocalizations.of(context)!.name,
                          Icons.badge_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context)!.nameIsRequired
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // Gender field
                      _FieldLabel(isArabic ? 'الجنس' : 'Gender'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kNavy.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Male option
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedGender = 'male'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.all(5),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'male'
                                        ? kNavy
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.male,
                                        color: _selectedGender == 'male'
                                            ? Colors.white
                                            : const Color(0xFF9CA3AF),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppLocalizations.of(context)!.male,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedGender == 'male'
                                              ? Colors.white
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Female option
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedGender = 'female'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.all(5),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'female'
                                        ? kNavy
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.female,
                                        color: _selectedGender == 'female'
                                            ? Colors.white
                                            : const Color(0xFF9CA3AF),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppLocalizations.of(context)!.female,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedGender == 'female'
                                              ? Colors.white
                                              : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Phone field
                      _FieldLabel(isArabic ? 'رقم الجوال' : 'Mobile Number'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 22,
                          color: kNavy,
                          fontWeight: FontWeight.w600,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _fieldDecoration(
                          AppLocalizations.of(context)!.mobileFormatHint,
                          Icons.phone_outlined,
                        ),
                        validator: (v) {
                          final txt = (v ?? '').trim();
                          if (txt.isEmpty) {
                            return AppLocalizations.of(context)!.requiredField;
                          }
                          if (!txt.startsWith('05')) {
                            return AppLocalizations.of(context)!.startWith05;
                          }
                          if (txt.length != 10) {
                            return AppLocalizations.of(context)!.enter10Digits;
                          }
                          if (_phoneUsedError != null) {
                            return _phoneUsedError;
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // ── Pinned bottom buttons ─────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Cancel
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: kNavy.withOpacity(0.4),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(
                            fontSize: 22,
                            color: kNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Save
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNavy,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _phoneUsedError = null);
                                if (!_formKey.currentState!.validate()) return;

                                setState(() => _isSaving = true);

                                final phone = _phoneController.text.trim();
                                final available = await _isPhoneAvailable(
                                  phone,
                                );

                                if (!mounted) return;

                                if (!available) {
                                  setState(() {
                                    _phoneUsedError = AppLocalizations.of(
                                      context,
                                    )!.mobileAlreadyUsed;
                                    _isSaving = false;
                                  });
                                  _formKey.currentState!.validate();
                                  return;
                                }

                                widget.onSave(
                                  _nameController.text.trim(),
                                  _selectedGender,
                                  phone,
                                );

                                setState(() => _isSaving = false);
                              },
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context)!.save,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field label helper ────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A2340),
      ),
    );
  }
}
