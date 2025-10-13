import 'package:flutter/material.dart';
import '../screens/elderly_home.dart';

void main() {
  runApp(const KhalilApp());
}

class KhalilApp extends StatelessWidget {
  const KhalilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(), //go to the elderly homepage
    );
  }
}
