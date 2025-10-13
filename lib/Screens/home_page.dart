import 'package:flutter/material.dart';
import 'login_page.dart'; // Make sure this path is correct

void main() {
  runApp(const CaregiverApp());
}

class CaregiverApp extends StatelessWidget {
  const CaregiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caregiver',
      debugShowCheckedModeBanner: false,
      // All theme properties now go inside ThemeData
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6FD),
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Color(0xFFFFFFFF),
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          iconColor: Colors.black87,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F2FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          indicatorColor: const Color(0xFF5E60CE).withOpacity(.15),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
