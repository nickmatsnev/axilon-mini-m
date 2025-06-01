import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/call_logging_provider.dart';
import '../utils/phone_call_helper.dart';

class CallListener {
  static DateTime? _lastCallStartTime;
  static String? _lastCallerPhone;
  static String? _lastRecipientPhone;
  static bool _callLogged = false;

  static void startListening(BuildContext context) {
    PhoneState.stream.listen((PhoneState event) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rejectAll = authProvider.user?['reject_all'] as bool? ?? false;

      // The user’s own phone number (recipient) from AuthProvider
      final String? rawSelfNumber = authProvider.user?['phone_number'];
      if (rawSelfNumber == null) return;
      final recipientPhone = rawSelfNumber.replaceAll('+', '');

      final callerPhone = event.number?.replaceAll('+', '') ?? 'Unknown';

      // If user chose to reject all, hang up immediately on incoming
      if (event.status == PhoneStateStatus.CALL_INCOMING && rejectAll) {
        print('Reject‐All is ON: hanging up call from $callerPhone');
        await PhoneCallHelper.endCurrentCall();
        // Optionally, log that we “rejected” the call:
        final callLoggingProvider =
        Provider.of<CallLoggingProvider>(context, listen: false);
        await callLoggingProvider.logCall(
          callerPhone: callerPhone,
          recipientPhone: recipientPhone,
          status: 'rejected',
          startTime: DateTime.now(),
          duration: Duration.zero,
        );
        return; // do not proceed further
      }

      // Otherwise, proceed with your existing logging logic:
      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        print('CALL_INCOMING: $callerPhone');
        if (!_callLogged) {
          _lastCallStartTime = DateTime.now();
          _lastCallerPhone = callerPhone;
          _lastRecipientPhone = recipientPhone;
          _callLogged = true;

          final callLoggingProvider =
          Provider.of<CallLoggingProvider>(context, listen: false);
          await callLoggingProvider.logCall(
            callerPhone: callerPhone,
            recipientPhone: recipientPhone,
            status: 'incoming',
            startTime: _lastCallStartTime!,
            duration: Duration.zero,
          );
        }
      } else if (event.status == PhoneStateStatus.CALL_ENDED) {
        print('CALL_ENDED: $callerPhone');
        if (_callLogged) {
          final callDuration = _lastCallStartTime != null
              ? DateTime.now().difference(_lastCallStartTime!)
              : Duration.zero;
          final callLoggingProvider =
          Provider.of<CallLoggingProvider>(context, listen: false);
          await callLoggingProvider.logCall(
            callerPhone: _lastCallerPhone!,
            recipientPhone: _lastRecipientPhone!,
            status: 'completed',
            startTime: _lastCallStartTime!,
            duration: callDuration,
          );

          _callLogged = false;
        }
      }
    });
  }
}
