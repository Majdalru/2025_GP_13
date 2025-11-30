import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'media_page.dart';
import 'elderly_med.dart';
import 'addmedeld.dart';
import 'favorites_manager.dart';
import '../../Screens/login_page.dart';

import '../../widgets/floating_voice_button.dart';
import '../../services/voice_assistant_service.dart';
import 'package:flutter_application_1/models/voice_command.dart';
import 'package:flutter_application_1/models/medication.dart';

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
  String? gender;
  String? phone;
  List<String> caregiverNames = [];
  bool loading = true;

  final VoiceAssistantService _voice = VoiceAssistantService();
  StreamSubscription<DocumentSnapshot>? _userSub;
  int _prevCaregiverCount = 0;
  bool _initialCaregiverLoaded = false;

  @override
  void initState() {
    super.initState();
    _listenToUserDoc();
    favoritesManager.init();
  }

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
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  // chunk helper for whereIn (max 10 ids)
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

            // caregiverIds[]
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
              // أول مرة نحمل البيانات: لا نعرض أي رسالة
              _prevCaregiverCount = newCount;
              _initialCaregiverLoaded = true;
            } else {
              if (newCount > _prevCaregiverCount) {
                _showTopBanner(
                  'A new caregiver has been linked to your profile.',
                  color: Colors.green.shade700,
                );
              } else if (newCount < _prevCaregiverCount) {
                _showTopBanner(
                  'A caregiver has been unlinked from your profile.',
                  color: kAccentRed,
                );
              }
              _prevCaregiverCount = newCount;
            }

            if (!mounted) return;

            setState(() {
              fullName = newFullName;
              gender = newGender;
              phone = newPhone;
              caregiverNames = names;
              loading = false;
            });
          },
          onError: (e) {
            if (mounted) {
              setState(() => loading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading profile: $e')),
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _userSub?.cancel();
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

    return Scaffold(
      backgroundColor: kSurface,
      drawer: Drawer(
        backgroundColor: kSurface,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          children: [
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  (fullName?.isNotEmpty ?? false) ? fullName! : "User",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ===== Card 1: Elderly Info =====
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Elderly Info", style: kTitleText),
                        IconButton(
                          iconSize: 32,
                          splashRadius: 28,
                          icon: const Icon(Icons.settings, color: kPrimary),
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => _EditInfoDialog(
                                initialName: fullName ?? '',
                                initialGender: gender ?? '',
                                initialPhone: phone ?? '',
                                onSave: (newName, newGender, newPhone) async {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
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

                                    setState(() {
                                      fullName = newName;
                                      gender = newGender;
                                      phone = newPhone;
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _showTopBanner(
                                        'Information updated successfully',
                                        color: Colors.green.shade700,
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoBox(
                      label: "Name",
                      value: (fullName?.isNotEmpty ?? false)
                          ? fullName!
                          : "N/A",
                    ),
                    const SizedBox(height: 14),
                    _InfoBox(label: "Gender", value: gender ?? "N/A"),
                    const SizedBox(height: 14),
                    _InfoBox(label: "Mobile", value: phone ?? "N/A"),
                  ],
                ),
              ),
            ),

            // ===== Card 2: Caregivers =====
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _CaregiversBox(names: caregiverNames),
              ),
            ),

            const SizedBox(height: 14),

            // ===== Card 3: Verification Code (Generate) =====
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Verification Code", style: kTitleText),
                    SizedBox(height: 12),
                    _PairingCodeBox(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ===== Main content =====
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 42,
                        color: Colors.black,
                      ),
                      splashRadius: 28,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),

                  // Floating voice button with advanced flows
                  FloatingVoiceButton(
                    onCommand: (command) async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;

                      debugPrint(
                        '🎯 Voice command received in ElderlyHomePage: $command',
                      );

                      switch (command) {
                        // ====== MEDICATIONS (Navigation + flows) ======
                        case VoiceCommand.goToMedication:
                          if (uid != null) {
                            // await _voice.speak(
                            //   "Opening your medications page.",
                            // );
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ElderlyMedicationPage(elderlyId: uid),
                              ),
                            );
                          } else {
                            await _voice.speak(
                              "I could not find your account. Please log in again.",
                            );
                          }
                          break;

                        case VoiceCommand.addMedication:
                          if (uid == null) {
                            await _voice.speak(
                              "I could not find your account. Please log in again.",
                            );
                            return;
                          }
                          await _voice.speak(
                            "Okay, I will help you add a new medication.",
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ElderlyMedicationPage(
                                elderlyId: uid,
                                initialCommand: VoiceCommand.addMedication,
                              ),
                            ),
                          );
                          break;

                        case VoiceCommand.editMedication:
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
                              builder: (_) => ElderlyMedicationPage(
                                elderlyId: uid,
                                initialCommand: VoiceCommand.editMedication,
                              ),
                            ),
                          );
                          break;

                        case VoiceCommand.deleteMedication:
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
                              builder: (_) => ElderlyMedicationPage(
                                elderlyId: uid,
                                initialCommand: VoiceCommand.deleteMedication,
                              ),
                            ),
                          );
                          break;

                        // ====== MEDIA ======
                        case VoiceCommand.goToMedia:
                          // await _voice.speak(
                          //   "Opening your media page.",
                          // );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MediaPage(),
                            ),
                          );
                          break;

                        // ====== HOME ======
                        case VoiceCommand.goToHome:
                          await _voice.speak(
                            "You are already on the home page.",
                          );
                          break;

                        // ====== SOS ======
                        case VoiceCommand.sos:
                          if (!mounted) return;
                          await _voice.speak(
                            "Emergency mode. Here we will trigger the SOS flow.",
                          );
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Emergency'),
                                content: const Text(
                                  'Here we will trigger the SOS flow (calling caregiver, sending alert, etc.).',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                          break;

                        // ====== SETTINGS ======
                        case VoiceCommand.goToSettings:
                          await _voice.speak(
                            "Settings page is not ready yet. In the future, I will open it for you from here.",
                          );
                          break;
                      }
                    },
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.black,
                      size: 36,
                    ),
                    splashRadius: 28,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: const BorderSide(color: kPrimary, width: 2),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Are you sure you want to log out?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: kPrimary,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 30,
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "No",
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: kPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  ElevatedButton(
                                    style: kBigButton(
                                      kAccentRed,
                                      pad: const EdgeInsets.symmetric(
                                        horizontal: 36,
                                        vertical: 18,
                                      ),
                                    ),
                                    onPressed: () {
                                      FirebaseAuth.instance.signOut();
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginPage(),
                                        ),
                                        (_) => false,
                                      );
                                    },
                                    child: const Text(
                                      "Yes",
                                      style: kButtonText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 65),
              Text(
                "Hello ${fullName?.split(' ').first ?? ''}",
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 6, 10, 65),
                ),
              ),
              const SizedBox(height: 55),

              // SOS
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentRed,
                  minimumSize: const Size(double.infinity, 100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 6,
                ),
                onPressed: () => HapticFeedback.heavyImpact(),
                child: const Text(
                  "SOS",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // two tiles
              Row(
                children: [
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.video_library,
                      title: "Media",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MediaPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.medical_services,
                      title: "Medication",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ElderlyMedicationPage(elderlyId: uid),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Error: Not logged in."),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Reusable widgets =====

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Caregivers', style: kTitleText),
        const SizedBox(height: 8),
        if (names.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: kPrimary.withOpacity(0.5), width: 1.5),
            ),
            child: const Text(
              'No caregivers linked',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          )
        else
          Column(
            children: names.map((name) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: kPrimary.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: Color.fromARGB(255, 27, 108, 113),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
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
  int _countdown = 300; // 5 minutes
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
        const SnackBar(content: Text("You need to be logged in.")),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error generating code: $e")));
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
              : const Text("Generate Code", style: kButtonText),
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width / 200).clamp(0.8, 1.0);
        final iconSize = 79 * scale;
        final fontSize = 27 * scale;
        final vPadding = 50 * scale;

        return Card(
          color: kSurface,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: kPrimary, width: 2),
          ),
          shadowColor: Colors.grey.withOpacity(0.1),
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: onTap,
            splashColor: kPrimary.withOpacity(0.15),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: vPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize, color: kPrimary),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  // error للجوال إذا طلع مستخدم
  String? _phoneUsedError;

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
      // لو الرقم نفس المستخدم الحالي عادي
      return snap.docs.first.id == currentUid;
    } catch (e) {
      // مع الرول الحالية ممكن ترجع PERMISSION_DENIED
      debugPrint('⚠️ phone uniqueness check failed: $e');
      // نرجّع true عشان ما نكسر التجربة
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF9FAFB),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: kPrimary.withOpacity(0.3), width: 2),
      ),
      title: const Text(
        "Edit Information",
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: kPrimary,
        ),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                // Name Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: kBodyText,
                  decoration: kInput("Name").copyWith(
                    errorStyle: const TextStyle(fontSize: 18),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Name is required"
                      : null,
                ),
                const SizedBox(height: 18),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: kInput(
                    "Gender",
                  ).copyWith(
                    filled: true,
                    fillColor: Colors.white,
                    errorStyle: const TextStyle(fontSize: 18),
                  ),
                  dropdownColor: Colors.white,
                  style: kBodyText,
                  items: const [
                    DropdownMenuItem(
                      value: "male",
                      child: Text("Male", style: kBodyText),
                    ),
                    DropdownMenuItem(
                      value: "female",
                      child: Text("Female", style: kBodyText),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGender = val ?? 'male';
                    });
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? "Select gender" : null,
                ),
                const SizedBox(height: 18),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: kBodyText,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: kInput("Mobile (05XXXXXXXX)").copyWith(
                    errorStyle: const TextStyle(fontSize: 18),
                  ),
                  validator: (v) {
                    final txt = (v ?? "").trim();
                    if (txt.isEmpty) return "Required";
                    if (!txt.startsWith('05')) return "Start with 05";
                    if (txt.length != 10) return "Enter 10 digits";
                    if (_phoneUsedError != null) return _phoneUsedError;
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        Row(
          children: [
            // Cancel Button
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kPrimary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      fontSize: 22,
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Save Button
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: kBigButton(
                    kPrimary,
                    pad: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ).copyWith(elevation: const WidgetStatePropertyAll(2)),
                  onPressed: () async {
                    // نفضي رسالة "مستخدم" قبل ما نتحقق
                    setState(() => _phoneUsedError = null);

                    if (!_formKey.currentState!.validate()) return;

                    final phone = _phoneController.text.trim();

                    // نحاول نتأكد إذا الرقم مستخدم
                    final available = await _isPhoneAvailable(phone);
                    if (!available) {
                      if (!mounted) return;
                      setState(() {
                        _phoneUsedError = "Mobile already used";
                      });
                      _formKey.currentState!.validate();
                      return;
                    }

                    widget.onSave(
                      _nameController.text.trim(),
                      _selectedGender,
                      phone,
                    );
                  },
                  child: const Text("Save", style: kButtonText),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
