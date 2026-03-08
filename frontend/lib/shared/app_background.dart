import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lightBlue.withOpacity(0.20),
            AppColors.softBlue.withOpacity(0.18),
            AppColors.background,
          ],
        ),
      ),
      child: child,
    );
  }
}