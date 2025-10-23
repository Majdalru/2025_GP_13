import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'media_page.dart';
import 'elderly_med.dart';
import '../../Screens/login_page.dart';

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

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // chunk helper for whereIn (max 10 ids)
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final out = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return out;
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() => loading = false);
        return;
      }

      final data = doc.data()!;
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['lastName'] ?? '').toString().trim();
      fullName = [first, last].where((s) => s.isNotEmpty).join(' ');
      gender = (data['gender'] ?? '').toString();
      phone = (data['phone'] ?? '').toString();

      // get caregivers names from caregiverIds[]
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
            names.add(n.isNotEmpty ? n : (email.isNotEmpty ? email : 'Unknown'));
          }
        }
      }

      setState(() {
        caregiverNames = names;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF2A4D69);
    const redButton = Color(0xFFD62828);

    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          children: [
            // Header name
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
        color: Color(0xFF2A4D69),
      ),
    ),
  ),
),
            const SizedBox(height: 20),

// ===== Card 1: Elderly Info =====
Card(
  elevation: 1,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // العنوان + زر الإعدادات
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Elderly Info",
              style: TextStyle(
                fontSize: 22, // أكبر
                fontWeight: FontWeight.w800,
                color: darkBlue,
              ),
            ),
            IconButton(
              iconSize: 28, // أكبر
              icon: const Icon(Icons.settings, color: darkBlue),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    final _formKey = GlobalKey<FormState>();
                    final nameController =
                        TextEditingController(text: fullName ?? '');
                    final genderController =
                        TextEditingController(text: gender ?? '');
                    final phoneController =
                        TextEditingController(text: phone ?? '');

                    return AlertDialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text(
                        "Edit Info",
                        style: TextStyle(
                          fontSize: 22, // أكبر
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      content: ConstrainedBox(
                        constraints: BoxConstraints(
                          // تكبير المقاس على الشاشات الصغيرة أيضًا
                          maxWidth: MediaQuery.of(context).size.width * 0.95,
                          maxHeight: MediaQuery.of(context).size.height * 0.70,
                        ),
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // الاسم
                                TextFormField(
                                  controller: nameController,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(fontSize: 18),
                                  decoration: const InputDecoration(
                                    labelText: "Name",
                                    labelStyle: TextStyle(fontSize: 16),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return "Name is required";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // الجنس
                                DropdownButtonFormField<String>(
                                  value: (genderController.text.isNotEmpty)
                                      ? genderController.text
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: "Gender",
                                    labelStyle: TextStyle(fontSize: 16),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  ),
                                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: "male", child: Text("Male")),
                                    DropdownMenuItem(value: "female", child: Text("Female")),
                                  ],
                                  onChanged: (val) => genderController.text = val ?? '',
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Select gender";
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // الجوال
                                TextFormField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontSize: 18),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: "Mobile (05XXXXXXXX)",
                                    labelStyle: TextStyle(fontSize: 16),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  ),
                                  validator: (v) {
                                    final txt = (v ?? "").trim();
                                    final reg = RegExp(r'^05\d{8}$');
                                    if (!reg.hasMatch(txt)) {
                                      return "Mobile must be 10 digits and start with 05";
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel", style: TextStyle(fontSize: 16)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;

                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final name = nameController.text.trim();
                              final parts = name.split(RegExp(r'\s+'));
                              final first = parts.isNotEmpty ? parts.first : '';
                              final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                'firstName': first,
                                'lastName': last,
                                'gender': genderController.text,
                                'phone': phoneController.text.trim(),
                              });

                              setState(() {
                                fullName = nameController.text.trim();
                                gender = genderController.text;
                                phone = phoneController.text.trim();
                              });

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Information updated successfully")),
                                );
                              }
                            }
                          },
                          child: const Text("Save", style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoBox(label: "Name", value: (fullName?.isNotEmpty ?? false) ? fullName! : "N/A"),
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
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Verification Code",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 12),
                    _PairingCodeBox(), // ← unchanged logic
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ===== Main content (unchanged) =====
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
                      icon: const Icon(Icons.menu, size: 42, color: Colors.black),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.black, size: 36),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
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
                                  color: darkBlue,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 35,
                                        vertical: 15,
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "No",
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: redButton,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 35,
                                        vertical: 15,
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
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Colors.white,
                                      ),
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
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 55),

              // spacer bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAECEE),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),

              const SizedBox(height: 40),

              // SOS
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: redButton,
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

              const SizedBox(height: 60),

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
                      title: "Medic",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ElderlyMedicationPage(elderlyId: uid),
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

// ===== Reusable widgets (unchanged logic) =====

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF2A4D69);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: darkBlue.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 22, color: Colors.black87),
          ),
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
    const darkBlue = Color(0xFF2A4D69);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caregivers',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        if (names.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: darkBlue.withOpacity(0.5), width: 1.5),
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
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: darkBlue.withOpacity(0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: darkBlue),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error generating code: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF2A4D69);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_code != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: darkBlue.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  _code!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
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
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: darkBlue,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                  _code == null ? "Generate Code" : "Generate New Code",
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
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
    const darkBlue = Color(0xFF2A4D69);
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      shadowColor: Colors.grey.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        splashColor: darkBlue.withOpacity(0.15),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              Icon(icon, size: 90, color: darkBlue),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
