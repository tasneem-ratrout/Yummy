import 'package:flutter/material.dart';
import 'package:frontend/features/auth/splash_screen.dart';

void main() {
  runApp(const YummyNaremanApp());
}

class YummyNaremanApp extends StatelessWidget {
  const YummyNaremanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yummy Nareman',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
