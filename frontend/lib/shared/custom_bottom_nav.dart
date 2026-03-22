import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/home_screen.dart';

class NavItemData {
  final IconData icon;
  final String label;

  const NavItemData({required this.icon, required this.label});
}

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({super.key, required this.currentIndex});

  static const List<NavItemData> items = [
    NavItemData(icon: Icons.home_rounded, label: "Home"),
    NavItemData(icon: Icons.storefront_rounded, label: "Store"),
    NavItemData(icon: Icons.add, label: "Add"),
    NavItemData(icon: Icons.menu_book_rounded, label: "Recipe"),
    NavItemData(icon: Icons.dynamic_feed_rounded, label: "Posts"),
  ];

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget page;

    switch (index) {
      case 0:
        page = const HomeScreen();
        break;
      case 1:
        page = const DummyNavScreen(title: "Store", currentIndex: 1);
        break;
      case 2:
        page = const DummyNavScreen(title: "Add Meal", currentIndex: 2);
        break;
      case 3:
        page = const DummyNavScreen(title: "Recipe", currentIndex: 3);
        break;
      case 4:
        page = const DummyNavScreen(title: "Posts", currentIndex: 4);
        break;
      default:
        page = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: page),
      ),
    );
  }

  Widget _buildNormalItem(
    BuildContext context, {
    required int index,
    required NavItemData item,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleTap(context, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.white.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 22, color: AppColors.white),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddItem(BuildContext context, bool isActive) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleTap(context, 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: isActive ? 50 : 46,
                height: isActive ? 50 : 46,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  color: AppColors.navy,
                  size: isActive ? 28 : 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Add",
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final isActive = index == currentIndex;
            final item = items[index];

            if (index == 2) {
              return _buildAddItem(context, isActive);
            }

            return _buildNormalItem(
              context,
              index: index,
              item: item,
              isActive: isActive,
            );
          }),
        ),
      ),
    );
  }
}

class DummyNavScreen extends StatelessWidget {
  final String title;
  final int currentIndex;

  const DummyNavScreen({
    super.key,
    required this.title,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.babyBlueLight),
          ),
          child: Text(
            "$title page later",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(currentIndex: currentIndex),
    );
  }
}
