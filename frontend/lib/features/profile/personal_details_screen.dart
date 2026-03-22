import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? user;
  File? _selectedImageFile;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
    fetchUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _recoverLostImage() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;

    final List<XFile>? files = response.files;
    if (files != null && files.isNotEmpty) {
      setState(() {
        _selectedImageFile = File(files.first.path);
      });
    }
  }

  Future<void> fetchUser() async {
    try {
      final token = await AuthService().getToken();

      final response = await http
          .get(
            Uri.parse("${AppConfig.baseUrl}/auth/me"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 30));

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 200) {
          final fetchedUser = data["user"] ?? {};
          final profile = fetchedUser["profile"] ?? {};

          setState(() {
            user = fetchedUser;

            _nameCtrl.text = fetchedUser["name"]?.toString() ?? "";
            _emailCtrl.text = fetchedUser["email"]?.toString() ?? "";
            _ageCtrl.text = profile["age"]?.toString() ?? "";
            _heightCtrl.text = profile["height"]?.toString() ?? "";
            _weightCtrl.text = profile["weight"]?.toString() ?? "";

            _profileImageUrl =
                profile["imageUrl"]?.toString() ??
                fetchedUser["imageUrl"]?.toString();

            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          _showSnack("Failed to load user data");
        }
      } catch (parseError) {
        setState(() => _isLoading = false);
        _showSnack("Invalid server response");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack("Error: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _selectedImageFile = File(image.path);
      });
    } catch (e) {
      _showSnack("Failed to pick image");
    }
  }

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Choose Profile Picture",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _imageOption(
                        icon: Icons.photo_library_rounded,
                        title: "Gallery",
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _imageOption(
                        icon: Icons.camera_alt_rounded,
                        title: "Camera",
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final token = await AuthService().getToken();

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Authentication failed. Please login again."),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      // Update user name using the auth service
      final updateResponse = await AuthService().updateUserName(
        name: _nameCtrl.text.trim(),
      );

      if (mounted) {
        if (updateResponse.containsKey('error') &&
            updateResponse['error'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updateResponse['message'] ?? "Failed to update name",
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.successPrimary,
              content: Text("Profile updated successfully!"),
            ),
          );
        }
        setState(() => _isSaving = false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${error.toString()}")));
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  ImageProvider? _buildAvatarImage() {
    if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }

    return null;
  }

  String getInitials(String name) {
    if (name.trim().isEmpty) return "U";
    final parts = name.trim().split(" ");

    // Handle single word name
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    // Handle multi-word name - safely access indices
    final firstInitial = parts[0].isNotEmpty ? parts[0][0] : '';
    final secondInitial = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1][0]
        : '';

    return "$firstInitial$secondInitial".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final currentName = _nameCtrl.text.isEmpty ? "User" : _nameCtrl.text;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8FC),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.deepBlue),
        title: const Text(
          "Personal Details",
          style: TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.royalBlue.withValues(
                                  alpha: 0.12,
                                ),
                                backgroundImage: _buildAvatarImage(),
                                child: _buildAvatarImage() == null
                                    ? Text(
                                        getInitials(currentName),
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.deepBlue,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _showImageSourceSheet,
                                  borderRadius: BorderRadius.circular(40),
                                  child: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: const BoxDecoration(
                                      color: AppColors.deepBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: AppColors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            currentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _emailCtrl.text,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.blueGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      children: [
                        _buildTextField(
                          controller: _nameCtrl,
                          label: "Full Name",
                          icon: Icons.person_outline_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your name";
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _emailCtrl,
                          label: "Email",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your email";
                            }
                            if (!value.contains("@")) {
                              return "Enter a valid email";
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _ageCtrl,
                          label: "Age",
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _heightCtrl,
                          label: "Height (cm)",
                          icon: Icons.height_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _weightCtrl,
                          label: "Weight (kg)",
                          icon: Icons.monitor_weight_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : saveUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepBlue,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        color: AppColors.deepBlue,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.deepBlue),
        filled: true,
        fillColor: AppColors.background,
        labelStyle: const TextStyle(
          color: AppColors.blueGray,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.royalBlue.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.deepBlue, width: 1.4),
        ),
      ),
    );
  }

  Widget _imageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.deepBlue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
