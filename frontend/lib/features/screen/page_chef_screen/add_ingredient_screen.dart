import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AddIngredientScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSave;

  const AddIngredientScreen({super.key, required this.onSave});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();

  String selectedUnit = 'g';
  List<Map<String, dynamic>> ingredients = [];

  final List<String> units = [
    'g',
    'kg',
    'ml',
    'L',
    'piece',
    'tbsp',
    'tsp',
    'cup',
  ];

  bool _isWebLayout(BuildContext context) {
    return kIsWeb && MediaQuery.of(context).size.width >= 900;
  }

  void addIngredient() {
    if (nameController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      ingredients.add({
        "name": nameController.text.trim(),
        "quantity": double.tryParse(quantityController.text.trim()) ?? 0,
        "unit": selectedUnit,
      });

      nameController.clear();
      quantityController.clear();
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Ingredients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          widget.onSave(ingredients);
          Navigator.pop(context);
        },
        icon: const Icon(Icons.check),
        label: const Text('Save'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 820 : double.infinity),
          child: Padding(
            padding: EdgeInsets.all(isWeb ? 28 : 20),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isWeb ? 24 : 0),
                  decoration: isWeb
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        )
                      : null,
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Ingredient Name',
                          prefixIcon: const Icon(Icons.restaurant_menu),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                prefixIcon: const Icon(Icons.scale),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              items: units.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => selectedUnit = v);
                              },
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: addIngredient,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Ingredient'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ingredients.isEmpty
                      ? const Center(
                          child: Text(
                            'No ingredients added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: ingredients.length,
                          itemBuilder: (_, index) {
                            final item = ingredients[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.restaurant_menu),
                                title: Text(item['name']),
                                subtitle: Text(
                                  '${item['quantity']} ${item['unit']}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() => ingredients.removeAt(index));
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
