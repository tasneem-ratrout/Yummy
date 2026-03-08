import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'role': 'user',
      }),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('userId', data['userId'].toString());
    }

    return data;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateUserName({
    required String userId,
    required String name,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/auth/update-name'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'name': name,
      }),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> saveProfile({
  required String name,
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
  final token = await getToken();

  final response = await http.post(
    Uri.parse('$baseUrl/user-profile'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'name': name,
      'goal': goal,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'height_value': heightValue,
      'height_unit': heightUnit,
      'weight_value': weightValue,
      'weight_unit': weightUnit,
      'activity_level': activityLevel,
      'allergies': allergies,
      'medical_conditions': medicalConditions,
    }),
  );

  return jsonDecode(response.body);
}
}