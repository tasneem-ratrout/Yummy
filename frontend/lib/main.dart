import 'package:flutter/material.dart';
import 'features/auth/splash_screen.dart';


void main() {
  runApp(const YummyApp());
}

class YummyApp extends StatelessWidget {
  const YummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yummy',
      home: const SplashScreen(),
    );
  }
}