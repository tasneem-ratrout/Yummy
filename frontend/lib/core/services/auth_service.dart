import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;
  static const Duration timeoutDuration = Duration(seconds: 30);
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userId';
  static const String _rememberMeKey = 'rememberMe';

  static String? _sessionToken;
  static String? _sessionUserId;

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
        _sessionToken = data['token'];
        _sessionUserId = data['userId']?.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, data['token']);
        await prefs.setString(_userIdKey, data['userId'].toString());
        await prefs.setBool(_rememberMeKey, true);
      }

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = true,
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
        _sessionToken = data['token'];
        _sessionUserId = data['userId']?.toString();

        final prefs = await SharedPreferences.getInstance();

        if (rememberMe) {
          await prefs.setString(_tokenKey, data['token']);
          await prefs.setString(_userIdKey, data['userId'].toString());
        } else {
          await prefs.remove(_tokenKey);
          await prefs.remove(_userIdKey);
        }

        await prefs.setBool(_rememberMeKey, rememberMe);
      }

      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<String?> getToken() async {
    if (_sessionToken != null) {
      return _sessionToken;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserId() async {
    if (_sessionUserId != null) {
      return _sessionUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<bool> getRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? true;
  }

  Future<void> setRememberMePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<void> logout() async {
    _sessionToken = null;
    _sessionUserId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
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
    try {
      final token = await getToken();

      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      if (imageFile != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/user-profile'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.fields['name'] = name;
        request.fields['goal'] = goal;
        request.fields['gender'] = gender;
        request.fields['date_of_birth'] = dateOfBirth;
        request.fields['height_value'] = heightValue.toString();
        request.fields['height_unit'] = heightUnit;
        request.fields['weight_value'] = weightValue.toString();
        request.fields['weight_unit'] = weightUnit;
        request.fields['activity_level'] = activityLevel;
        request.fields['allergies'] = jsonEncode(allergies);
        request.fields['medical_conditions'] = jsonEncode(medicalConditions);

        if (email != null) {
          request.fields['email'] = email;
        }

        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );

        final streamedResponse = await request.send().timeout(timeoutDuration);
        final response = await http.Response.fromStream(streamedResponse);
        return _parseResponse(response.body);
      }

      final requestBody = {
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
      };

      if (email != null) {
        requestBody['email'] = email;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/user-profile'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode(requestBody),
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
