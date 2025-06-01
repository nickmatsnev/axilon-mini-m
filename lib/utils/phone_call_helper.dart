// lib/utils/phone_call_helper.dart

import 'package:flutter/services.dart';

class PhoneCallHelper {
  static const MethodChannel _channel =
  MethodChannel('com.axilon/call_control');

  /// Returns true if the call was ended, false otherwise.
  static Future<bool> endCurrentCall() async {
    try {
      final result = await _channel.invokeMethod<bool>('endCall');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to end call: ${e.message}');
      return false;
    }
  }
}
