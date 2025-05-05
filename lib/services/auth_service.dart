import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final String baseUrl = 'https://axilon-be-dd0f4db1f2c9.herokuapp.com/api';

Future<Map<String, dynamic>> fetchChat(String token) async {
  final response = await http.get(
    Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to fetch chat');
  }
}
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/auth/validate-token'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200; // Token is valid if status is 200
    } catch (e) {
      print('Error validating token: $e');
      return false; // Assume token is invalid on error
    }
  }
  Future<Map<String, dynamic>> register(String firstName, String lastName, String phone, String password, String countryIso) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "phone_number": phone,
        "password": password,
        "country": countryIso
      }),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "phone_number": phone,
        "password": password,
      }),
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Error occurred');
    }
  }

  Future<Map<String, dynamic>> fetchAgent(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/agents/my-agent'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch agent');
    }
  }
}
