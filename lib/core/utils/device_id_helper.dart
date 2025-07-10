import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceIdHelper {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        return "web-device";
      } else if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;

        // Use a combination of ID and fingerprint/model if needed
        return androidInfo.id?.isNotEmpty == true
            ? androidInfo.id!
            : '${androidInfo.model}-${androidInfo.fingerprint ?? "unknown"}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor ?? "unknown-ios";
      } else {
        return "unsupported-platform";
      }
    } catch (e) {
      return "error: $e";
    }
  }
}
