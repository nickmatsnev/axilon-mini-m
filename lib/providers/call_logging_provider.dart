import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CallLoggingProvider with ChangeNotifier {
  final String apiBaseUrl = 'https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/phone-calls';
  final String token; // Pass token during provider initialization

  CallLoggingProvider(this.token);


  Future<void> logCall({
    required String callerPhone,
    required String recipientPhone,
    required String status,
    String? transcript,
    String? audio,
    required DateTime startTime,
    required Duration duration,
  }) async {
    final url = Uri.parse(apiBaseUrl);
    print("WE HAVE TOKEN $token");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'caller_phone': callerPhone,
          'recipient_phone': recipientPhone,
          'status': status,
          'transcript': transcript,
          'audio': audio,
          'start_time': startTime.toIso8601String(),
          'duration': duration.inSeconds,
        }),
      );

      if (response.statusCode == 201) {
        if (kDebugMode) {
          print('Call logged successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to log call: ${response.body}');
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error logging call: $error');
      }
    }
  }
}
