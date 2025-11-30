import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; //  إضافة Firebase Core
import 'firebase_options.dart'; //  الملف الذي تم توليده تلقائيًا
import 'Screens/login_page.dart';
import 'services/notification_service.dart';

// This is the custom navy color from your addmed.dart file (revert)
const Color customNavyColor = Color.fromRGBO(13, 45, 93, 1);
// Let's also define your teal color
const Color customTealColor = Colors.teal;
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //  ضروري قبل تشغيل Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, //  تهيئة Firebase
  );

  await NotificationService().initialize();

  runApp(const CaregiverApp());
}

class CaregiverApp extends StatelessWidget {
  const CaregiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caregiver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 13, 45, 93),
          brightness: Brightness.light,
          primary: customNavyColor,
          secondary: customTealColor,
        ),
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

      //  الصفحة الأولى المشتركة بين الطرفين
      home: const LoginPage(),
    );
  }
}
