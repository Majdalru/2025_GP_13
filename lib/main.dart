import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_khalil/medmain.dart';

void main() {
  // Use const for performance
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Class name should be Medmain (capital M)
    // 2. Add a semicolon at the end
    return const MaterialApp(home: Medmain());
  }
}
