import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AddMealManualScreen extends StatefulWidget {
  final String? mealType;
  final String? mealTitle;
  final int? targetCalories;
  final int? consumedCalories;
  final String? mealImageAsset;

  const AddMealManualScreen({
    super.key,
    this.mealType,
    this.mealTitle,
    this.targetCalories,
    this.consumedCalories,
    this.mealImageAsset,
  });

  @override
  State<AddMealManualScreen> createState() => _AddMealManualScreenState();
}

class _AddMealManualScreenState extends State<AddMealManualScreen> {
  DateTime _selectedDate = DateTime.now();
  static const double _sheetMinSize = 0.36;
  static const double _sheetMaxSize = 1.0;
  double _sheetExtent = _sheetMaxSize;

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _formattedDate {
    final day = _selectedDate.day;
    final month = _monthNames[_selectedDate.month - 1];
    final year = _selectedDate.year;
    return '$day $month $year';
  }

  bool get _hasMealSummary =>
      widget.mealTitle != null && widget.mealTitle!.trim().isNotEmpty;

  String get _resolvedMealImageAsset {
    final configured = (widget.mealImageAsset ?? '').trim();
    if (configured.isNotEmpty) return configured;

    final type = (widget.mealType ?? '').trim().toLowerCase();
    if (type.isEmpty) return 'assets/icons/eggs.png';

    return 'assets/icons/$type.png';
  }

  String get _displayMealTitle {
    final type = (widget.mealType ?? '').trim().toLowerCase();
    switch (type) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return widget.mealTitle ?? '';
    }
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final int targetCalories = (widget.targetCalories ?? 0).clamp(0, 999999);
    final int consumedCalories = (widget.consumedCalories ?? 0).clamp(
      0,
      999999,
    );
    final double calorieProgress = targetCalories <= 0
        ? 0
        : (consumedCalories / targetCalories).clamp(0.0, 1.0);
    final String mealType = (widget.mealType ?? '').trim().toLowerCase();
    final double mealImageSize = mealType == 'snack' ? 80 : 74;
    final double mealImageOffsetY = mealType == 'dinner' ? 5 : 0;
    final String caloriesLine = '$consumedCalories / $targetCalories kcal';
    final double headerBlueStrength =
        ((_sheetExtent - _sheetMinSize) / (_sheetMaxSize - _sheetMinSize))
            .clamp(0.0, 1.0);
    final Color pageBackgroundColor =
        Color.lerp(
          AppColors.background,
          AppColors.mediumBlue,
          headerBlueStrength,
        ) ??
        AppColors.background;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  if (_hasMealSummary)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: SizedBox(
                            width: 78,
                            height: 78,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color.alphaBlend(
                                      Colors.black.withValues(alpha: 0.06),
                                      AppColors.background,
                                    ),
                                    border: Border.all(
                                      color: AppColors.navy,
                                      width: 2.2,
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(0, mealImageOffsetY),
                                  child: Image.asset(
                                    _resolvedMealImageAsset,
                                    width: mealImageSize,
                                    height: mealImageSize,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      return const Icon(
                                        Icons.restaurant_rounded,
                                        color: AppColors.deepBlue,
                                        size: 30,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _displayMealTitle,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 0.5),
                                Text(
                                  caloriesLine,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    width: 104,
                                    height: 6,
                                    color: Colors.white.withValues(alpha: 0.35),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: calorieProgress,
                                        child: Container(
                                          color: Colors.white.withValues(
                                            alpha: 0.95,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.translate(
                          offset: const Offset(0, -8),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  final nextExtent = notification.extent;
                  if ((nextExtent - _sheetExtent).abs() > 0.001) {
                    setState(() {
                      _sheetExtent = nextExtent;
                    });
                  }
                  return false;
                },
                child: DraggableScrollableSheet(
                  initialChildSize: _sheetMaxSize,
                  minChildSize: _sheetMinSize,
                  maxChildSize: _sheetMaxSize,
                  builder: (context, scrollController) {
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.babyBlueLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: _goToPreviousDay,
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        color: AppColors.deepBlue,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formattedDate,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.deepBlue,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _goToNextDay,
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.deepBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'lets start add mele',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.deepBlue,
                                ),
                              ),
                              const SizedBox(height: 420),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
