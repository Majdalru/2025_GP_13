import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'media_page.dart';
import 'elderly_med.dart';
import '../../Screens/login_page.dart';

class ElderlyHomePage extends StatelessWidget {
  const ElderlyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF2A4D69);
    const redButton = Color(0xFFD62828);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
          children: [
            const SizedBox(height: 60),
            const Center(
              child: Text(
                "Sara Ahmed",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const _InfoBox(label: "Gender", value: "Female"),
            const SizedBox(height: 20),
            const _InfoBox(label: "Mobile", value: "+966 555 123 456"),
            const SizedBox(height: 20),
            const _InfoBox(label: "Caregiver", value: "Khaled"),
            const SizedBox(height: 35),
            const Text(
              "Verification Code",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 10),
            const _VerificationCodeBox(),
          ],
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Top Row: Menu + Settings
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
                              borderRadius: BorderRadius.circular(25)),
                          title: const Text(
                            "",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Color.fromRGBO(214, 40, 40, 1),
                                  minimumSize: const Size(double.infinity, 65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text(
                                        "Are you sure you want to log out?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: darkBlue,
                                        ),
                                      ),
                                      actionsAlignment: MainAxisAlignment.center,
                                      actions: [
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.grey[200],
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 35, vertical: 15),
                                          ),
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text(
                                            "No",
                                            style: TextStyle(
                                                fontSize: 24,
                                                color: Colors.black87),
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color.fromRGBO(214, 40, 40, 1),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 35, vertical: 15),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.pop(context);
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const LoginPage()),
                                            );
                                          },
                                          child: const Text(
                                            "Yes",
                                            style: TextStyle(
                                                fontSize: 24,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.logout,
                                    size: 34, color: Colors.white),
                                label: const Text(
                                  "Log out",
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
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

              const Text(
                "Hello Sara",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 55),

              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFEAECEE),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: redButton,
                  minimumSize: const Size(double.infinity, 100),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                  elevation: 6,
                ),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                },
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
                          MaterialPageRoute(
                              builder: (context) => const MediaPage()),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MedicationApp()),
                        );
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

class _VerificationCodeBox extends StatefulWidget {
  const _VerificationCodeBox();

  @override
  State<_VerificationCodeBox> createState() => _VerificationCodeBoxState();
}

class _VerificationCodeBoxState extends State<_VerificationCodeBox> {
  String? code; // 🔹 الكود مخفي بالبداية

  void generateNewCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String newCode =
        List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();

    setState(() {
      code = newCode;
    });

    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF2A4D69);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (code != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: darkBlue.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              code!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: darkBlue,
                letterSpacing: 3,
              ),
            ),
          ),
        const SizedBox(height: 15),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: darkBlue,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: generateNewCode,
          child: Text(
            code == null ? "Generate Code" : "Generate New Code",
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
