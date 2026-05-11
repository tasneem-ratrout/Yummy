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
  static const String _hiddenUsersKey = 'hiddenUsers';

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

  Future<List<Map<String, dynamic>>> getHiddenUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_hiddenUsersKey) ?? <String>[];

    return rawList
        .map((item) {
          try {
            final decoded = jsonDecode(item);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
          return <String, dynamic>{};
        })
        .where((item) => (item['id']?.toString() ?? '').trim().isNotEmpty)
        .toList();
  }

  Future<void> hideUser({
    required String userId,
    required String name,
    String? imageUrl,
  }) async {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getHiddenUsers();
    final updated = <Map<String, dynamic>>[
      ...current.where((item) => item['id']?.toString() != normalizedId),
      {
        'id': normalizedId,
        'name': name.trim().isEmpty ? 'User' : name.trim(),
        'imageUrl': (imageUrl ?? '').trim(),
      },
    ];

    await prefs.setStringList(
      _hiddenUsersKey,
      updated.map(jsonEncode).toList(),
    );
  }

  Future<void> unhideUser(String userId) async {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getHiddenUsers();
    final updated = current
        .where((item) => item['id']?.toString() != normalizedId)
        .toList();

    await prefs.setStringList(
      _hiddenUsersKey,
      updated.map(jsonEncode).toList(),
    );
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

  Future<Map<String, dynamic>> updateStreak({
    required int streakCount,
    required List<DateTime> streakDates,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .patch(
            Uri.parse('$baseUrl/user-profile/streak'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({
              'streak_count': streakCount,
              'streak_dates': streakDates
                  .map(
                    (date) => DateTime(
                      date.year,
                      date.month,
                      date.day,
                    ).toIso8601String(),
                  )
                  .toList(),
            }),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUsersStreaks() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/user-profile/users-streaks'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      final token = await getToken();
      if (token == null) return {'message': 'No token', 'error': true};

      final uri = Uri.parse(
        '$baseUrl/user-profile/search?q=${Uri.encodeQueryComponent(query)}',
      );
      final response = await http
          .get(uri, headers: await _buildHeaders(token: token))
          .timeout(timeoutDuration);
      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPosts() async {
    try {
      final token = await getToken();
      final headers = await _buildHeaders(token: token);

      final response = await http
          .get(Uri.parse('$baseUrl/posts'), headers: headers)
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String authorName,
    String? authorImageUrl,
    String? text,
    File? imageFile,
    double? calories,
    double? fat,
    double? carbs,
    double? protein,

    /// `public` or `followers_only` (matches backend Post.visibility)
    String visibility = 'public',
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'message': 'No token', 'error': true};

      print('🔗 POST $baseUrl/posts');
      if (imageFile != null) {
        print('📷 Uploading with image: ${imageFile.path}');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/posts'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        if (text != null) request.fields['text'] = text;
        if (authorName.isNotEmpty) request.fields['authorName'] = authorName;
        if (authorImageUrl != null)
          request.fields['authorImageUrl'] = authorImageUrl;
        if (calories != null) request.fields['calories'] = calories.toString();
        if (fat != null) request.fields['fat'] = fat.toString();
        if (carbs != null) request.fields['carbs'] = carbs.toString();
        if (protein != null) request.fields['protein'] = protein.toString();
        request.fields['visibility'] = visibility == 'followers_only'
            ? 'followers_only'
            : 'public';

        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
        final streamed = await request.send().timeout(timeoutDuration);
        final response = await http.Response.fromStream(streamed);
        return _parseResponse(response.body);
      }

      final body = {
        'authorName': authorName,
        if (authorImageUrl != null) 'authorImageUrl': authorImageUrl,
        if (text != null) 'text': text,
        if (calories != null) 'calories': calories,
        if (fat != null) 'fat': fat,
        if (carbs != null) 'carbs': carbs,
        if (protein != null) 'protein': protein,
        'visibility': visibility == 'followers_only'
            ? 'followers_only'
            : 'public',
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> togglePostLike({
    required String postId,
    required String userId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'error': true, 'message': 'No token'};

      print('👍 Toggle like on post $postId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/like'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({'userId': userId}),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addPostComment({
    required String postId,
    required String authorName,
    String? authorImageUrl,
    required String text,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'error': true, 'message': 'No token'};

      print('💬 Adding comment to post $postId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/posts/$postId/comment'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({
              'authorName': authorName,
              'authorImageUrl': authorImageUrl,
              'text': text,
            }),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deletePost({required String postId}) async {
    try {
      final token = await getToken();
      if (token == null) return {'error': true, 'message': 'No token'};

      final response = await http
          .delete(
            Uri.parse('$baseUrl/posts/$postId'),
            headers: await _buildHeaders(token: token),
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

  Future<Map<String, dynamic>> toggleFollow({
    required String targetUserId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        print('❌ No token found');
        return {'message': 'No authentication token found', 'error': true};
      }

      print('🔗 API Call: POST $baseUrl/follow/toggle');
      print('📦 Body: {"targetUserId": "$targetUserId"}');
      print('🔑 Token: ${token.substring(0, 10)}...');

      final response = await http
          .post(
            Uri.parse('$baseUrl/follow/toggle'),
            headers: await _buildHeaders(token: token),
            body: jsonEncode({'targetUserId': targetUserId}),
          )
          .timeout(timeoutDuration);

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      return _parseResponse(response.body);
    } catch (e) {
      print('❌ Error in toggleFollow: $e');
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFollowers({required String userId}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      print('👥 Getting followers for user: $userId');

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$userId/followers'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFollowing({required String userId}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      print('👥 Getting following for user: $userId');

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$userId/following'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> checkFollowStatus({
    required String targetUserId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$targetUserId/status'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserStats({required String userId}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'message': 'No authentication token found', 'error': true};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/follow/$userId/stats'),
            headers: await _buildHeaders(token: token),
          )
          .timeout(timeoutDuration);

      return _parseResponse(response.body);
    } catch (e) {
      return _handleError(e);
    }
  }
}
