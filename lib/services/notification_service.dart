import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Call this method during app initialization.
  Future<void> initialize(String userId) async {
    // Request permission (optional on Android but necessary on iOS)
    await _firebaseMessaging.requestPermission();

    // Get the token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print("FCM Token: $token");
      // Send the token to your backend
      await sendTokenToServer(userId, token);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("FCM Token refreshed: $newToken");
      await sendTokenToServer(userId, newToken);
    });
  }

  // Sends the token to your backend API
  Future<void> sendTokenToServer(String userId, String token) async {
    final url = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/update-fcm-token');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'fcm_token': token,
          // If your endpoint is protected by auth, add your token or other headers here.
        }),
      );
      if (response.statusCode == 200) {
        print("FCM token updated successfully on server.");
      } else {
        print("Failed to update FCM token: ${response.body}");
      }
    } catch (e) {
      print("Error sending FCM token to server: $e");
    }
  }
}
