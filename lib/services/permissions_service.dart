import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  Future<void> requestAllPermissions() async {
    if (kIsWeb) {
      print("Skipping permission requests on Web.");
      return; // Don't request permissions on Web
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.contacts,
      Permission.microphone,
      Permission.sms,
      Permission.notification,
      Permission.phone,
    ].request();

    statuses.forEach((permission, status) {
      print('$permission: $status');
    });
  }
}
