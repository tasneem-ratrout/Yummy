import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/home_provider.dart';
import 'core/providers/user_provider.dart';
import 'features/auth/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: const YummyApp(),
    ),
  );
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
