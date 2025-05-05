import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class TranslationProvider extends ChangeNotifier {
  final String baseUrl = 'https://axilon-be-dd0f4db1f2c9.herokuapp.com/api';
  Map<String, String>? _localizedStrings;
  String _currentLang = 'en'; // default to English

  String get currentLang => _currentLang;

  /// Loads JSON file from assets/i18n/<lang>.json
  Future<void> loadLanguage(String langCode) async {
    final String jsonString = await rootBundle.loadString('assets/i18n/$langCode.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);

    // Convert Map<String, dynamic> to Map<String, String>
    _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));

    _currentLang = langCode;
    notifyListeners();
  }

  /// Return the localized value for [key], or the key if missing
  String t(String key) {
    if (_localizedStrings == null) {
      return key;
    }
    return _localizedStrings![key] ?? key;
  }

  Future<Map<String, dynamic>> updateLanguage(String lang, String token, String userId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/lang/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"lang": lang}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update language: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating language: $e');
    }
  }
  /// Switch the current language and reload
  Future<void> setLanguage(String langCode, String token, String userId) async {
    await loadLanguage(langCode);
    await updateLanguage(langCode, token, userId);
  }
  Future<void> fetchUserLanguage(String token, String userId) async {
    try {
      final response = await http.get(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lang = data['lang'] ?? 'en';
        print("received lang is ${lang}");
        await loadLanguage(lang);
      } else {
        throw Exception('Failed to fetch language: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching language: $e');
    }
  }
}
