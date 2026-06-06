import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_ingredient_screen.dart';
import '../../../core/config/app_config.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _time = TextEditingController();
  final _category = TextEditingController();

  List<Map<String, dynamic>> ingredients = [];
  String difficulty = 'Easy';

  XFile? imageFile;
  Uint8List? imageBytes;
  bool loading = false;

  bool _isWebLayout(BuildContext context) {
    return kIsWeb && MediaQuery.of(context).size.width >= 900;
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        imageFile = picked;
        imageBytes = bytes;
      });
    }
  }

  Future<void> addRecipe() async {
    if (imageFile == null || imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select recipe image')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final chefId = prefs.getString('chefId');

      if (chefId == null || chefId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chef ID not found. Open profile first.'),
          ),
        );
        setState(() => loading = false);
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/recipes'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['chefId'] = chefId;
      request.fields['name'] = _name.text.trim();
      request.fields['description'] = _description.text.trim();
      request.fields['price'] = _price.text.trim();
      request.fields['totalTime'] = _time.text.trim();
      request.fields['category'] = _category.text.trim();
      request.fields['ingredients'] = jsonEncode(ingredients);
      request.fields['difficulty'] = difficulty;

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes!,
          filename: imageFile!.name,
        ),
      );

      final response = await request.send();

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe added successfully')),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed To Add Recipe')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (mounted) setState(() => loading = false);
  }

  Widget buildField(
    String title,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: title,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _time.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Recipe')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 1080 : double.infinity),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isWeb ? 32 : 20),
            child: isWeb ? _buildWebLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker({double height = 180}) {
    return GestureDetector(
      onTap: pickImage,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(imageBytes!, fit: BoxFit.cover),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 50),
                  SizedBox(height: 8),
                  Text('Choose recipe image'),
                ],
              ),
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        buildField('Recipe Name', _name),
        buildField('Description', _description, maxLines: 3),
        buildField('Price', _price, type: TextInputType.number),
        buildField('Cooking Time', _time, type: TextInputType.number),
        buildField('Category', _category),
        DropdownButtonFormField<String>(
          value: difficulty,
          items: ['Easy', 'Medium', 'Hard'].map((e) {
            return DropdownMenuItem(value: e, child: Text(e));
          }).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => difficulty = v);
          },
          decoration: InputDecoration(
            labelText: 'Difficulty',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsBox() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddIngredientScreen(
                    onSave: (data) => setState(() => ingredients = data),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Add Ingredients'),
          ),
        ),
        const SizedBox(height: 16),
        if (ingredients.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingredients',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ...ingredients.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• ${e['name']} - ${e['quantity']} ${e['unit']}',
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : addRecipe,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Publish Recipe'),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildImagePicker(),
        const SizedBox(height: 20),
        _buildFields(),
        const SizedBox(height: 16),
        _buildIngredientsBox(),
        const SizedBox(height: 20),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: _webCardDecoration(),
            child: Column(
              children: [
                _buildImagePicker(height: 320),
                const SizedBox(height: 20),
                _buildIngredientsBox(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: _webCardDecoration(),
            child: Column(
              children: [
                _buildFields(),
                const SizedBox(height: 20),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _webCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
