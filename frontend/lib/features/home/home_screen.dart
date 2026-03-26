import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/custom_bottom_nav.dart';
import '../../shared/app_drawer.dart';
import '../profile/personal_details_screen.dart';
import '../auth/welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? user;
  bool isLoading = true;

  // Placeholder values until backend logic is added.
  int fireCounter = 0;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _streakAwardedForToday = false;
  bool _overCaloriesNotified = false;
  DateTime _streakStateDate = DateUtils.dateOnly(DateTime.now());

  int dailyCalories = 0;
  int dailyProtein = 0;
  int dailyFat = 0;
  int dailyCarbs = 0;

  int consumedCalories = 0;
  int consumedProtein = 0;
  int consumedFat = 0;
  int consumedCarbs = 0;

  List<Map<String, dynamic>> todaysMeals = [];
  List<Map<String, dynamic>> mealHistory = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    try {
      final token = await AuthService().getToken();

      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/auth/me"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["user"] != null) {
        final profile = data["user"]["profile"];
        final calories = calculateCalories(profile);
        final macros = calculateMacros(profile, calories);

        setState(() {
          user = data["user"];
          dailyCalories = calories;
          dailyProtein = macros["protein"] ?? 0;
          dailyFat = macros["fat"] ?? 0;
          dailyCarbs = macros["carbs"] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("HOME ERROR: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    await fetchUser();
  }

  int calculateAge(String dateOfBirth) {
    final birthDate = DateTime.parse(dateOfBirth);
    final today = DateTime.now();

    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  int calculateCalories(dynamic profile) {
    if (profile == null) return 0;

    final weight = (profile["weight"]?["value"] ?? 0).toDouble();
    final height = (profile["height"]?["value"] ?? 0).toDouble();
    final gender = profile["gender"];
    final activity = profile["activity_level"];
    final goal = profile["goal"];
    final dob = profile["date_of_birth"];

    if (dob == null || dob.toString().isEmpty) return 0;

    final age = calculateAge(dob.toString());
    if (age == 0 || height == 0 || weight == 0) return 0;

    double bmr;

    if (gender == "male") {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    double activityFactor = 1.2;

    switch (activity) {
      case "lightly_active":
        activityFactor = 1.375;
        break;
      case "moderately_active":
        activityFactor = 1.55;
        break;
      case "very_active":
        activityFactor = 1.725;
        break;
      case "sedentary":
      default:
        activityFactor = 1.2;
    }

    double calories = bmr * activityFactor;

    if (goal == "lose_weight") {
      calories -= 350;
    } else if (goal == "gain_weight") {
      calories += 300;
    }

    return calories.round();
  }

  Map<String, int> calculateMacros(dynamic profile, int calories) {
    if (profile == null || calories == 0) {
      return {"protein": 0, "fat": 0, "carbs": 0};
    }

    final weight = (profile["weight"]?["value"] ?? 0).toDouble();
    final goal = profile["goal"];

    if (weight == 0) {
      return {"protein": 0, "fat": 0, "carbs": 0};
    }

    double proteinPerKg;
    double fatPercentage;

    switch (goal) {
      case "lose_weight":
        proteinPerKg = 1.6;
        fatPercentage = 0.25;
        break;
      case "gain_weight":
        proteinPerKg = 1.8;
        fatPercentage = 0.25;
        break;
      case "stay_healthy":
      default:
        proteinPerKg = 1.2;
        fatPercentage = 0.30;
        break;
    }

    final proteinGrams = weight * proteinPerKg;
    final proteinCalories = proteinGrams * 4;

    final fatGrams = (calories * fatPercentage) / 9;
    final fatCalories = fatGrams * 9;

    final carbsGrams = (calories - proteinCalories - fatCalories) / 4;

    return {
      "protein": proteinGrams.round(),
      "fat": fatGrams.round(),
      "carbs": carbsGrams.round() < 0 ? 0 : carbsGrams.round(),
    };
  }

  double getProgress(int consumed, int total) {
    if (total <= 0) return 0.0;
    return consumed / total;
  }

  double _indicatorProgress(int consumed, int total) {
    final progress = getProgress(consumed, total);
    if (progress < 0) return 0;
    if (progress > 1) return 1;
    return progress;
  }

  String _calorieStatusLabel(double progress) {
    if (consumedCalories <= 0) {
      return "Start Strong";
    }
    if (dailyCalories > 0 && consumedCalories > dailyCalories) {
      return "Over Calories";
    }
    if (progress >= 0.85) {
      return "Almost There";
    }
    return "On Track";
  }

  String _formatMealType(String mealType) {
    final trimmed = mealType.trim();
    if (trimmed.isEmpty) return "Meal";

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return "Meal";

    return normalized
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String? _validateMealInput({
    required String mealName,
    required String mealType,
    required String caloriesText,
    required String proteinText,
    required String fatText,
    required String carbsText,
  }) {
    if (mealName.trim().isEmpty) {
      return "Meal name is required";
    }
    if (mealType.trim().isEmpty) {
      return "Meal type is required";
    }
    if (caloriesText.trim().isEmpty ||
        proteinText.trim().isEmpty ||
        fatText.trim().isEmpty ||
        carbsText.trim().isEmpty) {
      return "Please fill all nutrition values";
    }

    final calories = int.tryParse(caloriesText);
    final protein = int.tryParse(proteinText);
    final fat = int.tryParse(fatText);
    final carbs = int.tryParse(carbsText);

    if (calories == null || protein == null || fat == null || carbs == null) {
      return "Please enter valid whole numbers";
    }

    if (calories <= 0) {
      return "Calories must be greater than 0";
    }
    if (protein < 0 || fat < 0 || carbs < 0) {
      return "Values cannot be negative";
    }
    if (calories > 4000) {
      return "Calories value is unrealistic";
    }
    if (protein > 300 || fat > 250 || carbs > 400) {
      return "Macros value is unrealistic";
    }

    return null;
  }

  void _showExceededCaloriesSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You have exceeded your daily calories")),
    );
  }

  void _normalizeConsumedTotals() {
    if (consumedCalories < 0) consumedCalories = 0;
    if (consumedProtein < 0) consumedProtein = 0;
    if (consumedFat < 0) consumedFat = 0;
    if (consumedCarbs < 0) consumedCarbs = 0;
  }

  bool _applyStreakAndCalorieRules() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (!_isSameDay(today, _streakStateDate)) {
      _streakStateDate = today;
      _streakAwardedForToday = false;
      _overCaloriesNotified = false;
    }

    if (dailyCalories <= 0) {
      return false;
    }

    final isOver = consumedCalories > dailyCalories;

    if (isOver) {
      if (!_overCaloriesNotified && fireCounter > 0) {
        fireCounter -= 1;
      }
      _streakAwardedForToday = false;

      if (!_overCaloriesNotified) {
        _overCaloriesNotified = true;
        return true;
      }
      return false;
    }

    if (consumedCalories > 0 && !_streakAwardedForToday) {
      fireCounter += 1;
      _streakAwardedForToday = true;
    }

    _overCaloriesNotified = false;
    return false;
  }

  String greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  String getInitials(String name) {
    if (name.trim().isEmpty) return "U";

    final parts = name.trim().split(" ");
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? "").trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? "${baseUri.host}:${baseUri.port}"
        : baseUri.host;
    final origin = "${baseUri.scheme}://$authority";

    if (raw.startsWith("/")) {
      return "$origin$raw";
    }

    return "$origin/$raw";
  }

  String? _extractUserImageUrl() {
    final profile = user?["profile"] as Map<String, dynamic>?;
    final rawImageValue =
        profile?["image_url"] ??
        profile?["image"] ??
        profile?["imageUrl"] ??
        user?["image_url"] ??
        user?["image"] ??
        user?["imageUrl"];

    return _resolveImageUrl(rawImageValue);
  }

  Future<void> _logout() async {
    await AuthService().logout();
    await AuthService().setRememberMePreference(false);
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()),
    );
  }

  void _goToAboutUs() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Go to About Us page later")));
  }

  void addMeal(
    String name,
    int calories,
    int protein,
    int fat,
    int carbs, {
    required String mealType,
  }) {
    bool shouldShowExceededCaloriesSnack = false;

    setState(() {
      consumedCalories += calories;
      consumedProtein += protein;
      consumedFat += fat;
      consumedCarbs += carbs;

      todaysMeals.add({
        "name": name.trim(),
        "type": _formatMealType(mealType),
        "calories": calories,
        "protein": protein,
        "fat": fat,
        "carbs": carbs,
        "time": DateTime.now(),
      });

      shouldShowExceededCaloriesSnack = _applyStreakAndCalorieRules();
    });

    if (shouldShowExceededCaloriesSnack) {
      _showExceededCaloriesSnackBar();
    }
  }

  void _updateMeal(
    int mealIndex, {
    required String name,
    required String mealType,
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
  }) {
    if (mealIndex < 0 || mealIndex >= todaysMeals.length) return;

    bool shouldShowExceededCaloriesSnack = false;

    setState(() {
      final oldMeal = todaysMeals[mealIndex];

      final oldCalories = oldMeal["calories"] as int? ?? 0;
      final oldProtein = oldMeal["protein"] as int? ?? 0;
      final oldFat = oldMeal["fat"] as int? ?? 0;
      final oldCarbs = oldMeal["carbs"] as int? ?? 0;
      final oldTime = oldMeal["time"] is DateTime
          ? oldMeal["time"] as DateTime
          : DateTime.now();

      consumedCalories += calories - oldCalories;
      consumedProtein += protein - oldProtein;
      consumedFat += fat - oldFat;
      consumedCarbs += carbs - oldCarbs;
      _normalizeConsumedTotals();

      todaysMeals[mealIndex] = {
        "name": name.trim(),
        "type": _formatMealType(mealType),
        "calories": calories,
        "protein": protein,
        "fat": fat,
        "carbs": carbs,
        "time": oldTime,
      };

      shouldShowExceededCaloriesSnack = _applyStreakAndCalorieRules();
    });

    if (shouldShowExceededCaloriesSnack) {
      _showExceededCaloriesSnackBar();
    }
  }

  void _deleteMeal(int mealIndex) {
    if (mealIndex < 0 || mealIndex >= todaysMeals.length) return;

    bool shouldShowExceededCaloriesSnack = false;

    setState(() {
      final meal = todaysMeals.removeAt(mealIndex);

      consumedCalories -= meal["calories"] as int? ?? 0;
      consumedProtein -= meal["protein"] as int? ?? 0;
      consumedFat -= meal["fat"] as int? ?? 0;
      consumedCarbs -= meal["carbs"] as int? ?? 0;
      _normalizeConsumedTotals();

      shouldShowExceededCaloriesSnack = _applyStreakAndCalorieRules();
    });

    if (shouldShowExceededCaloriesSnack) {
      _showExceededCaloriesSnackBar();
    }
  }

  void _showAddMealDialog({String? mealType, int? editIndex}) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final fatController = TextEditingController();
    final carbsController = TextEditingController();

    if (editIndex != null && editIndex >= 0 && editIndex < todaysMeals.length) {
      final meal = todaysMeals[editIndex];
      nameController.text = meal["name"]?.toString() ?? "";
      typeController.text = meal["type"]?.toString() ?? (mealType ?? "Meal");
      caloriesController.text = '${meal["calories"] ?? 0}';
      proteinController.text = '${meal["protein"] ?? 0}';
      fatController.text = '${meal["fat"] ?? 0}';
      carbsController.text = '${meal["carbs"] ?? 0}';
    } else {
      typeController.text = mealType ?? "Meal";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(editIndex == null ? "Add Meal" : "Edit Meal"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Meal Name"),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: "Meal Type (Breakfast, Lunch, etc.)",
                ),
              ),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: "Calories"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: proteinController,
                decoration: const InputDecoration(labelText: "Protein (g)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(labelText: "Fat (g)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: carbsController,
                decoration: const InputDecoration(labelText: "Carbs (g)"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final validationError = _validateMealInput(
                mealName: nameController.text,
                mealType: typeController.text,
                caloriesText: caloriesController.text,
                proteinText: proteinController.text,
                fatText: fatController.text,
                carbsText: carbsController.text,
              );

              if (validationError != null) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text(validationError)));
                return;
              }

              final calories = int.parse(caloriesController.text.trim());
              final protein = int.parse(proteinController.text.trim());
              final fat = int.parse(fatController.text.trim());
              final carbs = int.parse(carbsController.text.trim());

              if (editIndex == null) {
                addMeal(
                  nameController.text.trim(),
                  calories,
                  protein,
                  fat,
                  carbs,
                  mealType: typeController.text.trim(),
                );
              } else {
                _updateMeal(
                  editIndex,
                  name: nameController.text.trim(),
                  mealType: typeController.text.trim(),
                  calories: calories,
                  protein: protein,
                  fat: fat,
                  carbs: carbs,
                );
              }

              Navigator.pop(context);
            },
            child: Text(editIndex == null ? "Add" : "Save"),
          ),
        ],
      ),
    );
  }

  Widget buildCaloriesCard() {
    final progress = getProgress(consumedCalories, dailyCalories);
    final indicatorProgress = _indicatorProgress(
      consumedCalories,
      dailyCalories,
    );
    final isOverCalories =
        dailyCalories > 0 && consumedCalories > dailyCalories;
    final calorieDelta = isOverCalories
        ? consumedCalories - dailyCalories
        : dailyCalories - consumedCalories;
    final statusLabel = _calorieStatusLabel(progress);
    final progressColor = isOverCalories
        ? const Color(0xFFFF6A3D)
        : Colors.white;
    final balanceText = isOverCalories
        ? "Exceeded by $calorieDelta kcal"
        : "Remaining $calorieDelta kcal";
    final today = DateTime.now();
    final dateLabel =
        '${_weekdayShort(today.weekday)}, ${today.day}/${today.month}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.deepBlue, AppColors.royalBlue, AppColors.deepBlue],
          stops: [0.0, 0.56, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Transform.translate(
                offset: const Offset(8, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Today's Goals",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$dailyCalories",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  "kcal target",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Consumed $consumedCalories kcal",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  balanceText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: indicatorProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _showDateHistoryPicker() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = _selectedDate.isAfter(today) ? today : _selectedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: today,
      helpText: 'Select date',
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = DateUtils.dateOnly(pickedDate);
    });
  }

  Widget _buildDateHistoryButton() {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: _showDateHistoryPicker,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 18,
        icon: Icon(
          Icons.calendar_month_rounded,
          color: AppColors.deepBlue.withValues(alpha: 0.9),
          size: 21,
        ),
        tooltip: 'All previous dates',
      ),
    );
  }

  Widget _buildDaysStrip() {
    final today = DateUtils.dateOnly(DateTime.now());
    final anchorDate = _selectedDate.isAfter(today) ? today : _selectedDate;

    final dates = List.generate(
      7,
      (index) => anchorDate.subtract(Duration(days: 3 - index)),
    );

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isActive = _isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateUtils.dateOnly(date);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 66,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.lightBlue.withValues(alpha: 0.35)
                    : AppColors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isActive
                      ? AppColors.navy.withValues(alpha: 0.30)
                      : AppColors.dark.withValues(alpha: 0.06),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dark.withValues(alpha: 0.03),
                    blurRadius: 9,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isActive ? 0.30 : 0.48),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdayShort(date.weekday),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppColors.navy
                            : AppColors.dark.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isActive
                            ? AppColors.navy
                            : AppColors.dark.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakFireBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.babyBlueLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Image.asset(
              'assets/icons/flame.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.local_fire_department_rounded,
                  size: 20,
                  color: AppColors.fatOrange,
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$fireCounter',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeCard({
    required String title,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.60)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBlue,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _showAddMealDialog(mealType: title),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.lightBlue.withValues(alpha: 0.22),
                foregroundColor: AppColors.deepBlue,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: AppColors.lightBlue.withValues(alpha: 0.70),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealQuickAddSection() {
    return Column(
      children: [
        _buildMealTypeCard(
          title: 'Breakfast',
          icon: Icons.wb_sunny_outlined,
          accent: const Color(0xFFFFB85C),
        ),
        const SizedBox(height: 10),
        _buildMealTypeCard(
          title: 'Lunch',
          icon: Icons.lunch_dining_outlined,
          accent: const Color(0xFF63A4FF),
        ),
        const SizedBox(height: 10),
        _buildMealTypeCard(
          title: 'Dinner',
          icon: Icons.dinner_dining_outlined,
          accent: const Color(0xFF7F8CAA),
        ),
        const SizedBox(height: 10),
        _buildMealTypeCard(
          title: 'Snack',
          icon: Icons.cookie_outlined,
          accent: const Color(0xFF55B58A),
        ),
        const SizedBox(height: 10),
        _buildMealTypeCard(
          title: 'Custom',
          icon: Icons.add_circle_outline_rounded,
          accent: const Color(0xFF3F72AF),
        ),
      ],
    );
  }

  Widget buildMiniDetailCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.blueGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCombinedMacrosCard() {
    final caloriesProgressRaw = getProgress(consumedCalories, dailyCalories);
    final proteinProgressRaw = getProgress(consumedProtein, dailyProtein);
    final fatProgressRaw = getProgress(consumedFat, dailyFat);
    final carbsProgressRaw = getProgress(consumedCarbs, dailyCarbs);

    final caloriesProgress = _indicatorProgress(
      consumedCalories,
      dailyCalories,
    );
    final proteinProgress = _indicatorProgress(consumedProtein, dailyProtein);
    final fatProgress = _indicatorProgress(consumedFat, dailyFat);
    final carbsProgress = _indicatorProgress(consumedCarbs, dailyCarbs);

    final caloriesPercent = (caloriesProgressRaw * 100).round();
    final proteinPercent = (proteinProgressRaw * 100).round();
    final fatPercent = (fatProgressRaw * 100).round();
    final carbsPercent = (carbsProgressRaw * 100).round();

    const caloriesColor = AppColors.babyBlueDark;
    const proteinColor = AppColors.proteinBlue;
    const fatColor = AppColors.fatOrange;
    const carbsColor = AppColors.carbsGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.babyBlueLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Daily Progress",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepBlue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Calories and macros overview",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.blueGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.insights_rounded, size: 24, color: AppColors.deepBlue),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: buildMiniDetailCard(
                      title: "Calories",
                      value: "$caloriesPercent%",
                      subtitle: "$consumedCalories / $dailyCalories kcal",
                      color: caloriesColor,
                      bgColor: const Color(0xFFEAF3FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildMiniDetailCard(
                      title: "Protein",
                      value: "$proteinPercent%",
                      subtitle: "$consumedProtein / $dailyProtein g",
                      color: proteinColor,
                      bgColor: const Color(0xFFEFF4FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: buildMiniDetailCard(
                      title: "Fat",
                      value: "$fatPercent%",
                      subtitle: "$consumedFat / $dailyFat g",
                      color: fatColor,
                      bgColor: const Color(0xFFFFF4EC),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildMiniDetailCard(
                      title: "Carbs",
                      value: "$carbsPercent%",
                      subtitle: "$consumedCarbs / $dailyCarbs g",
                      color: carbsColor,
                      bgColor: const Color(0xFFEFFBF5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: caloriesProgress,
                      strokeWidth: 10,
                      backgroundColor: caloriesColor.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        caloriesColor,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  SizedBox(
                    width: 142,
                    height: 142,
                    child: CircularProgressIndicator(
                      value: proteinProgress,
                      strokeWidth: 10,
                      backgroundColor: proteinColor.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        proteinColor,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  SizedBox(
                    width: 114,
                    height: 114,
                    child: CircularProgressIndicator(
                      value: fatProgress,
                      strokeWidth: 10,
                      backgroundColor: fatColor.withValues(alpha: 0.14),
                      valueColor: const AlwaysStoppedAnimation<Color>(fatColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    height: 86,
                    child: CircularProgressIndicator(
                      value: carbsProgress,
                      strokeWidth: 10,
                      backgroundColor: carbsColor.withValues(alpha: 0.14),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        carbsColor,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Daily",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepBlue,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Stats",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepBlue,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _legendItem("Calories", caloriesColor),
              _legendItem("Protein", proteinColor),
              _legendItem("Fat", fatColor),
              _legendItem("Carbs", carbsColor),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, List<int>> _groupTodayMealsByType() {
    final groupedMeals = <String, List<int>>{};

    for (int index = 0; index < todaysMeals.length; index++) {
      final mealType = _formatMealType(
        todaysMeals[index]["type"]?.toString() ?? "Meal",
      );
      groupedMeals.putIfAbsent(mealType, () => <int>[]).add(index);
    }

    return groupedMeals;
  }

  List<String> _orderedMealTypes(Iterable<String> mealTypes) {
    const preferredOrder = ["Breakfast", "Lunch", "Dinner", "Snack"];

    final ordered = <String>[];
    for (final type in preferredOrder) {
      if (mealTypes.contains(type)) {
        ordered.add(type);
      }
    }

    final customTypes =
        mealTypes.where((type) => !preferredOrder.contains(type)).toList()
          ..sort((a, b) => a.compareTo(b));

    ordered.addAll(customTypes);
    return ordered;
  }

  Widget _buildTodayMealsGroupedView() {
    if (todaysMeals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.babyBlueLight),
        ),
        child: const Center(
          child: Text(
            "No meals added today",
            style: TextStyle(
              color: AppColors.blueGray,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final groupedMeals = _groupTodayMealsByType();
    final sortedTypes = _orderedMealTypes(groupedMeals.keys);

    return Column(
      children: sortedTypes.map((mealType) {
        final mealIndexes = groupedMeals[mealType] ?? <int>[];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.babyBlueLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    mealType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${mealIndexes.length} item${mealIndexes.length == 1 ? '' : 's'}",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...mealIndexes.map((mealIndex) => buildMealCard(mealIndex)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildMealCard(int mealIndex) {
    final meal = todaysMeals[mealIndex];
    final mealType = meal["type"]?.toString() ?? "Meal";
    final mealTime = meal["time"] is DateTime
        ? meal["time"] as DateTime
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.babyBlueLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.babyBlueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppColors.deepBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal["name"]?.toString() ?? "Meal",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mealType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.babyBlueDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${meal["calories"]} kcal  •  P:${meal["protein"]}g  •  F:${meal["fat"]}g  •  C:${meal["carbs"]}g",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.blueGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${mealTime.hour}:${mealTime.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.blueGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showAddMealDialog(editIndex: mealIndex),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.babyBlueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _deleteMeal(mealIndex),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFE15B3D),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.deepBlue,
      ),
    );
  }

  Widget _buildChatPlaceholderButton() {
    return Tooltip(
      message: 'Chat (Coming Soon)',
      child: Material(
        color: AppColors.deepBlue,
        elevation: 7,
        shadowColor: AppColors.navy.withValues(alpha: 0.30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.lightBlue.withValues(alpha: 0.48),
            width: 1.1,
          ),
        ),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(18),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.royalBlue),
        ),
      );
    }

    final userName = user?["name"] ?? "User";
    final userImageUrl = _extractUserImageUrl();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: AppDrawer(
        user: user,
        onProfileTap: _goToProfile,
        onAboutTap: _goToAboutUs,
        onLogoutTap: _logout,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _goToProfile,
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy, width: 2.2),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.babyBlueLight,
                        backgroundImage: userImageUrl != null
                            ? NetworkImage(userImageUrl)
                            : null,
                        child: userImageUrl == null
                            ? Text(
                                getInitials(userName),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepBlue,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.blueGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStreakFireBadge(),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.deepBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: _buildDateHistoryButton(),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 4),
                                child: _buildDaysStrip(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        buildCaloriesCard(),
                        const SizedBox(height: 22),
                        buildSectionTitle("Daily Macros"),
                        const SizedBox(height: 14),
                        buildCombinedMacrosCard(),
                        const SizedBox(height: 14),
                        _buildMealQuickAddSection(),
                        const SizedBox(height: 26),
                        buildSectionTitle("Today's Meals"),
                        const SizedBox(height: 14),
                        _buildTodayMealsGroupedView(),
                        const SizedBox(height: 26),
                        buildSectionTitle("Meal History"),
                        const SizedBox(height: 14),
                        mealHistory.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: AppColors.babyBlueLight,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    "No meal history",
                                    style: TextStyle(
                                      color: AppColors.blueGray,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: mealHistory.map((day) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.babyBlueLight,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          day["date"],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.deepBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...day["meals"].map<Widget>((meal) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              "${meal["name"]} - ${meal["calories"]} kcal",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.blueGray,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildChatPlaceholderButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
    );
  }
}
