import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:provider/provider.dart';
import '../providers/call_logging_provider.dart';
import '../providers/auth_provider.dart';

class CallListener {
  static DateTime? _lastCallStartTime; // Track last call start time
  static String? _lastCallerPhone; // Track last caller phone
  static String? _lastRecipientPhone; // Track last recipient phone
  static bool _callLogged = false; // Ensure each call is logged once

  static void startListening(BuildContext context) {
    PhoneState.stream.listen((PhoneState event) async {
      // Access the user's phone number from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? recipientPhone = authProvider.user?['phone_number'];

      if (recipientPhone == null) {
        print("Recipient phone number is not available.");
        return;
      }

      // Sanitize phone numbers by removing "+"
      final String callerPhone = event.number?.replaceAll('+', '') ?? 'Unknown';
      final String sanitizedRecipientPhone = recipientPhone.replaceAll('+', '');

      // Skip if the caller phone is "Unknown"
      if (callerPhone == 'Unknown') {
        print("Skipping call log as callerPhone is Unknown");
        return;
      }

      // Initialize logging provider
      final callLoggingProvider =
      Provider.of<CallLoggingProvider>(context, listen: false);

      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        print("CALL_INCOMING callerPhone: $callerPhone");

        if (!_callLogged) {
          _lastCallStartTime = DateTime.now();
          _lastCallerPhone = callerPhone;
          _lastRecipientPhone = sanitizedRecipientPhone;
          _callLogged = true;

          // Log incoming call
          await callLoggingProvider.logCall(
            callerPhone: callerPhone,
            recipientPhone: sanitizedRecipientPhone,
            status: 'incoming',
            startTime: _lastCallStartTime!,
            duration: Duration.zero,
          );
        }
      } else if (event.status == PhoneStateStatus.CALL_ENDED) {
        print("CALL_ENDED callerPhone: $callerPhone");

        if (_callLogged) {
          final callDuration = _lastCallStartTime != null
              ? DateTime.now().difference(_lastCallStartTime!)
              : Duration.zero;

          // Log ended call
          await callLoggingProvider.logCall(
            callerPhone: _lastCallerPhone!,
            recipientPhone: _lastRecipientPhone!,
            status: 'completed',
            startTime: _lastCallStartTime!,
            duration: callDuration,
          );

          // Reset call log tracking
          _callLogged = false;
        }
      }
    });
  }
}
