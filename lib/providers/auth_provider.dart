import 'package:axilon_mini_m/providers/translation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io' show Platform; // To check the platform
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;

class AuthProvider with ChangeNotifier {
  final String baseUrl = 'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api'; // Replace with your server URL
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  String? _token;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _agent; // Store agent information
  Map<String, dynamic>? _chat; // Store chat information

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get agent => _agent;
  Map<String, dynamic>? get chat => _chat;
  Future<void> fetchUserAndUpdateLang(BuildContext context) async {
    if (_token == null) {
      // No token => user not logged in => do nothing
      return;
    }

    final translation = Provider.of<TranslationProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/me'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Store the user data in _user
        _user = data;
        notifyListeners();

        // Now read the lang field from the updated user
        final newLang = data['lang'] ?? 'en';

        // If you want to forcibly reload the language in translation provider
        await translation.loadLanguage(newLang);

        print('User fetched + language updated => $newLang');
      } else {
        print('Error fetching user: ${response.statusCode} => ${response.body}');
      }
    } catch (e) {
      print('Exception fetching user: $e');
    }
  }
  Future<Map<String, dynamic>> fetchUserData(String token) async {
    // Adjust path if your server uses /users/me, /users/<id>, etc.
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch user data: ${response.body}');
    }
  }
  // Method to fetch chat information
  Future<void> fetchChat() async {
    if (_token == null) return;

    try {
      final response = await _authService.fetchChat(_token!);
      _chat = response; // Save chat details
      notifyListeners();
    } catch (e) {
      print('Error fetching chat: $e');
    }
  }

  // Login method
  Future<void> login(String phone, String password) async {
    try {
      final result = await _authService.login(phone, password);
      _token = result['token'];
      _user = result['user'];

      // Save session to secure storage
      await _storage.write(key: 'token', value: _token);
      await _storage.write(key: 'user', value: jsonEncode(_user));
      await fetchAgent();
      await fetchChat();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to login: ${e.toString()}');
    }
  }

  // Register method
  Future<void> register(String firstName, String lastName, String phone, String password, String countryIso, String fcmToken) async {
    try {
      // Remove "+" from phone number
      final formattedPhone = phone.replaceAll('+', '');

      final response = await _authService.register(firstName, lastName, formattedPhone, password, countryIso, fcmToken);

      // Parse the response to extract token and user
      final token = response['token'];
      final user = response['user'];

      // Save the token and user information locally
      _token = token;
      _user = user;

      // Persist session to secure storage
      await _storage.write(key: 'token', value: token);
      await _storage.write(key: 'user', value: jsonEncode(user));

      notifyListeners();
    } catch (e) {
      print("Error during registration: $e");
      throw Exception(e.toString());
    }
  }

  Future<void> deleteUser(String userId, String token) async {
    // e.g. final url = 'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId';
    final url = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',  // if you use JWT or similar
        },
      );

      if (response.statusCode == 200) {
        // Success: user is deleted
        // Clear local user data
        _token = null;
        _user = null;
        _agent = null; // Clear agent info
        // Clear session from secure storage
        await _storage.delete(key: 'token');
        await _storage.delete(key: 'user');
        notifyListeners();
      } else {
        // Handle failure
        print('Failed to delete user. Status: ${response.statusCode}. Body: ${response.body}');
        throw Exception('Failed to delete user');
      }
    } catch (error) {
      print('Error deleting user: $error');
      rethrow;
    }
  }
  // Load session from storage
  Future<void> loadSession() async {
    _token = await _storage.read(key: 'token');
    final userData = await _storage.read(key: 'user');

    if (_token != null && userData != null) {
      try {
        _user = jsonDecode(userData);

        // Validate token with backend
        final isValid = await _authService.validateToken(_token!);
        if (!isValid) {
          await logout(); // Logout if token is invalid
          return;
        }

        // Fetch agent and chat if token is valid
        await fetchAgent();
        await fetchChat();
      } catch (e) {
        print('Error validating session: $e');
        await logout(); // Logout on error
      }
    }
    notifyListeners();
  }
  Future<void> fetchAgent() async {
    if (_token == null) return;

    try {
      final response = await _authService.fetchAgent(_token!);
      _agent = response; // Save agent details
      notifyListeners();
    } catch (e) {
      print('Error fetching agent: $e');
    }
  }
  Future<void> setUser(Map<String, dynamic> updatedUser) async {
    _user = updatedUser;
    // Optionally persist the updated user in secure storage
    await _storage.write(key: 'user', value: jsonEncode(_user));
    notifyListeners();
  }
  // Logout method
  Future<void> logout() async {
    _token = null;
    _user = null;
    _agent = null; // Clear agent info

    // Clear session from secure storage
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');

    notifyListeners();
  }
}
