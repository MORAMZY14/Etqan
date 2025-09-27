import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class PWAInstall {
  static bool _isAvailable = false;
  static bool _isIOS = false;

  static bool get isAvailable => _isAvailable;
  static bool get isIOS => _isIOS;

  static void setOnAvailableCallback(VoidCallback onAvailable) {
    if (kIsWeb) {
      // Check if iOS
      _isIOS = js.context.callMethod('isIOSDevice');

      // Check initial availability
      _isAvailable = js.context.callMethod('isPWAInstallAvailable');
      if (_isAvailable) {
        onAvailable();
      }

      // Set up callback for when it becomes available
      js.context.callMethod('setPWAInstallAvailableCallback',
          [js.allowInterop(() {
            _isAvailable = true;
            onAvailable();
          })]
      );
    }
  }

  static void showInstallPrompt() {
    if (kIsWeb && _isAvailable) {
      js.context.callMethod('showInstallPrompt');
    }
  }
}