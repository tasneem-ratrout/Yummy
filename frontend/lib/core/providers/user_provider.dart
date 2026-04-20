import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isSaving = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get goal => _user?["profile"]?["goal"]?.toString();

  Future<void> fetchUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        _user = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['user'] != null) {
        _user = Map<String, dynamic>.from(data['user'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Keep previous user state on transient errors.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveProfile({
    required String name,
    String? email,
    File? imageFile,
    required String goal,
    required String gender,
    required String dateOfBirth,
    required int heightValue,
    required String heightUnit,
    required double weightValue,
    required String weightUnit,
    required String activityLevel,
    required List<String> allergies,
    required List<String> medicalConditions,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final response = await _authService.saveProfile(
        name: name,
        email: email,
        imageFile: imageFile,
        goal: goal,
        gender: gender,
        dateOfBirth: dateOfBirth,
        heightValue: heightValue,
        heightUnit: heightUnit,
        weightValue: weightValue,
        weightUnit: weightUnit,
        activityLevel: activityLevel,
        allergies: allergies,
        medicalConditions: medicalConditions,
      );

      final hasError = response['error'] == true;
      if (!hasError) {
        await fetchUser();
      }

      return response;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
