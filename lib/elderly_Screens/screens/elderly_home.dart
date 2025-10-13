import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'media_page.dart';
import 'elderly_med.dart';

void main() {
  runApp(const KhalilApp());
}

class KhalilApp extends StatelessWidget {
  const KhalilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'NotoSansArabic',
        scaffoldBackgroundColor: const Color(0xFFFDFEFE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF34495E),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF34495E),
          onPrimary: Colors.white,
          secondary: Color(0xFFD62828),
          background: Color(0xFFFDFEFE),
          surface: Color(0xFFFFFFFF),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const appBarColor = Color(0xFF34495E);
    const buttonRed = Color(0xFFD62828);
    const iconColor = Color(0xFF2C3E50);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 4,
        toolbarHeight: 85,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 44, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 38),
            onPressed: () {
              HapticFeedback.selectionClick();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFFFDFEFE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  title: const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: appBarColor,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
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
                                  color: appBarColor,
                                ),
                              ),
                              actionsAlignment: MainAxisAlignment.center,
                              actions: [
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
                                      fontSize: 24,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: buttonRed,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 35,
                                      vertical: 15,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "Yes",
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.logout,
                          size: 34,
                          color: Colors.white,
                        ),
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
      drawer: Drawer(
        backgroundColor: const Color(0xFFFDFEFE),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
          children: [
            const Center(
              child: Text(
                "Sara Ahmed",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF34495E),
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
                color: Color(0xFF34495E),
              ),
            ),
            const SizedBox(height: 10),
            const _VerificationCodeBox(),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDFEFE), Color(0xFFE8EBEE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Hello Sara",
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: appBarColor,
                ),
              ),
              const SizedBox(height: 50),
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
                  backgroundColor: buttonRed,
                  minimumSize: const Size(double.infinity, 100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
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
              const SizedBox(height: 35),
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
                            builder: (context) => const MediaPage(),
                          ),
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
                        // Add this line to navigate
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MedicationApp(),
                          ),
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
    const labelColor = Color(0xFF34495E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
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
  const _VerificationCodeBox({super.key});

  @override
  State<_VerificationCodeBox> createState() => _VerificationCodeBoxState();
}

class _VerificationCodeBoxState extends State<_VerificationCodeBox> {
  int code = Random().nextInt(9000) + 1000;

  void generateNewCode() {
    setState(() {
      code = Random().nextInt(9000) + 1000;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            code.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF34495E),
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 15),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: generateNewCode,
          child: const Text(
            "Generate New Code",
            style: TextStyle(fontSize: 20, color: Colors.white),
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
    const iconColor = Color(0xFF2C3E50);
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      shadowColor: Colors.grey.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        splashColor: Colors.blue.withOpacity(0.15),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              Icon(icon, size: 90, color: iconColor),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
