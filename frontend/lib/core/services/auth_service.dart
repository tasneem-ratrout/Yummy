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
      body: jsonEncode({'email': email, 'password': password, 'role': 'user'}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
          'password': password.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      print("LOGIN STATUS 👉 ${response.statusCode}");
      print("LOGIN DATA 👉 $data");

      /// ❌ إذا فشل
      if (response.statusCode != 200) {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }

      /// ✅ إذا نجح
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', data['token'] ?? '');
      await prefs.setString('userId', data['userId'].toString());
      await prefs.setString('chefId', data['chefId']?.toString() ?? '');
      await prefs.setString('userName', data['name'] ?? '');
      await prefs.setString('userEmail', data['email'] ?? '');
      await prefs.setString('userRole', data['role'] ?? 'user');

      return {'success': true, ...data};
    } catch (e) {
      print("LOGIN ERROR 👉 $e");
      return {'success': false, 'message': 'Server error'};
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName') ?? '';
  }

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') ?? '';
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
      body: jsonEncode({'userId': userId, 'name': name}),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', name);
    }
    return data;
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
