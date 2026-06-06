import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/config/app_config.dart';
import 'edit_recipe_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kPrimaryDark = Color(0xFF0A1628);
const _kPrimaryLight = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kAccentOrange = Color(0xFFF59E0B);
const _kCard = Color(0xFFFFFFFF);
const _kBackground = Color(0xFFF8FAFC);
const _kText = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

class RecipeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailsScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  String _selectedSize = 'Medium';
  List<dynamic> recipeReviews = [];

  bool loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadRecipeReviews();
  }

  bool _isWebLayout(BuildContext context) {
    return kIsWeb && MediaQuery.of(context).size.width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);
    final recipe = widget.recipe;
    final image = recipe['image'] ?? '';

    if (isWeb) {
      return Scaffold(
        backgroundColor: _kBackground,
        appBar: AppBar(
          backgroundColor: _kPrimaryDark,
          elevation: 0,
          title: const Text(
            'Recipe Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditRecipeScreen(recipe: recipe),
                  ),
                );
                if (result == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ الصورة فوق
                  _buildWebImageCard(image),
                  const SizedBox(height: 24),
                  // ✅ الاسم + الوصف + السعر
                  _buildWebMainInfo(recipe),
                  const SizedBox(height: 28),
                  // ✅ Nutrition
                  _buildSectionCard(
                    title: 'Nutrition',
                    icon: Icons.local_fire_department_rounded,
                    child: _buildNutritionSection(showTitle: false),
                  ),
                  const SizedBox(height: 24),
                  // ✅ Ingredients
                  _buildSectionCard(
                    title: 'Ingredients',
                    icon: Icons.restaurant_menu_rounded,
                    child: _buildIngredientsSection(showTitle: false),
                  ),
                  const SizedBox(height: 28),
                  // ✅ Reviews
                  _buildSectionCard(
                    title: 'Recipe Reviews',
                    icon: Icons.star_rounded,
                    child: _buildReviewsSection(showTitle: false),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ✅ Mobile layout - بدون تغيير
    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _kPrimaryDark,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditRecipeScreen(recipe: recipe),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _recipeImage(image)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildMobileBody(recipe),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(Map<String, dynamic> recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe['name'] ?? '',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _kText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recipe['description'] ?? '',
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: _kTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _buildPriceCard(recipe),
        const SizedBox(height: 28),
        _buildNutritionSection(),
        const SizedBox(height: 28),
        _buildIngredientsSection(),
        const SizedBox(height: 28),
        _buildSizeSelection(),
        const SizedBox(height: 30),
        _buildReviewsSection(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildWebImageCard(dynamic image) {
    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _recipeImage(image),
    );
  }

  Widget _buildWebMainInfo(Map<String, dynamic> recipe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe['name'] ?? '',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: _kText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            recipe['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: _kTextSecondary,
            ),
          ),
          const SizedBox(height: 26),
          _buildPriceCard(recipe),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildInfoCard(
                Icons.timer_rounded,
                '${recipe['totalTime'] ?? 0}',
                'Minutes',
                _kPrimaryLight,
              ),
              const SizedBox(width: 14),
              _buildInfoCard(
                Icons.category_rounded,
                '${recipe['category'] ?? 'Food'}',
                'Category',
                _kAccentOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recipeImage(dynamic image) {
    return image.toString().isNotEmpty
        ? Image.network(
            image.toString().startsWith('http')
                ? image
                : '${AppConfig.baseUrl.replaceAll('/api', '')}$image',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) {
              return Container(
                color: _kBackground,
                child: const Center(
                  child: Icon(
                    Icons.restaurant,
                    size: 70,
                    color: _kPrimaryLight,
                  ),
                ),
              );
            },
          )
        : Container(
            color: _kBackground,
            child: const Center(
              child: Icon(Icons.restaurant, size: 70, color: _kPrimaryLight),
            ),
          );
  }

  Widget _buildPriceCard(Map<String, dynamic> recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_money_rounded, color: _kAccent),
          const SizedBox(width: 10),
          Text(
            '${recipe['price'] ?? 0} NIS',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _kPrimaryLight.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _kPrimaryLight, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Future<void> _loadRecipeReviews() async {
    try {
      final recipeId = widget.recipe['_id'];
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/review-recipe/$recipeId'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          recipeReviews = data['data'] ?? [];
          loadingReviews = false;
        });
      }
    } catch (e) {
      print(e);
      setState(() {
        loadingReviews = false;
      });
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/review-recipe/$reviewId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          recipeReviews.removeWhere((review) => review['_id'] == reviewId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review deleted')));
      }
    } catch (e) {
      print(e);
    }
  }

  Widget _buildReviewsSection({bool showTitle = true}) {
    if (loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recipeReviews.isEmpty) {
      return const Text(
        'No reviews yet',
        style: TextStyle(color: _kTextSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text(
            'Recipe Reviews',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kText,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...recipeReviews.map((review) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        review['userName'] ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _kText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteReview(review['_id']),
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: index < review['rating']
                          ? Colors.amber
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(review['comment'] ?? ''),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNutritionSection({bool showTitle = true}) {
    final recipe = widget.recipe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text(
            'Nutrition',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kText,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _buildNutritionCard(
              '${recipe['calories'] ?? 0}',
              'Calories',
              Colors.red,
            ),
            _buildNutritionCard(
              '${recipe['protein'] ?? 0}',
              'Protein',
              _kPrimaryLight,
            ),
            _buildNutritionCard('${recipe['fat'] ?? 0}', 'Fat', _kAccentOrange),
            _buildNutritionCard(
              '${recipe['carbs'] ?? recipe['potassium'] ?? 0}',
              'Carbs',
              _kAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionCard(String value, String title, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: _kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection({bool showTitle = true}) {
    final recipe = widget.recipe;
    final ingredients = List<Map<String, dynamic>>.from(
      recipe['ingredients'] ?? [],
    );

    if (ingredients.isEmpty) {
      return const Text(
        'No ingredients added',
        style: TextStyle(color: _kTextSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text(
            'Ingredients',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kText,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...ingredients.map((ingredient) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 10, color: _kAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${ingredient['quantity']} ${ingredient['unit']} ${ingredient['name']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSizeSelection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start);
  }

  Widget _buildInfoCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: _kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
