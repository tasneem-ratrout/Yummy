import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Parse JSON response safely with error handling
  static Map<String, dynamic> _parseResponse(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ JSON Parse Error: $e');
      print('📄 Response body: $body');
      return {'message': 'Invalid server response', 'error': true};
    }
  }

  /// Build authorization headers
  static Future<Map<String, String>> _buildHeaders({String? token}) async {
    final headers = {'Content-Type': 'application/json'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Handle HTTP errors
  static Map<String, dynamic> _handleError(dynamic error) {
    return {
      'message': 'Network error. Please check your connection.',
      'error': true,
      'details': error.toString(),
    };
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: await _buildHeaders(),
            body: jsonEncode({
              'email': email,
              'password': password,
              'role': 'user',
            }),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('userId', data['userId'].toString());
      }

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: await _buildHeaders(),
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(timeoutDuration);

      final data = _parseResponse(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('userId', data['userId'].toString());
      }

      return data;
    } catch (e) {
      return _handleError(e);
    }
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
    try {
      final token = await getToken();

      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateUserName({required String name}) async {
    try {
      final token = await getToken();

      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/auth/update-name'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({'name': name}),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
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
    try {
      final token = await getToken();

      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/user-profile'),
            headers: await _buildHeaders(token: token),
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
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendResetCode({required String email}) async {
    try {
      print('📤 Sending reset code to: $email');
      print('🔗 URL: $baseUrl/auth/forgot-password/send-code');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/send-code'),
            headers: await _buildHeaders(),
            body: jsonEncode({'email': email}),
          )
          .timeout(timeoutDuration);

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Headers: ${response.headers}');
      print('📥 Response Body: ${response.body}');

      final data = _parseResponse(response.body);
      data['statusCode'] = response.statusCode;
      return data;
    } catch (e) {
      print('❌ Error in sendResetCode: $e');
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      print('📤 Verifying reset code for: $email');
      print('🔗 URL: $baseUrl/auth/forgot-password/verify-code');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/verify-code'),
            headers: await _buildHeaders(),
            body: jsonEncode({'email': email, 'code': code}),
          )
          .timeout(timeoutDuration);

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      final data = _parseResponse(response.body);
      data['statusCode'] = response.statusCode;
      return data;
    } catch (e) {
      print('❌ Error in verifyResetCode: $e');
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      print('📤 Resetting password for: $email');
      print('🔗 URL: $baseUrl/auth/forgot-password/reset');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/reset'),
            headers: await _buildHeaders(),
            body: jsonEncode({'email': email, 'newPassword': newPassword}),
          )
          .timeout(timeoutDuration);

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      final data = _parseResponse(response.body);
      data['statusCode'] = response.statusCode;
      return data;
    } catch (e) {
      print('❌ Error in resetPassword: $e');
      return _handleError(e);
    }
  }
}
