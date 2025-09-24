// pwa_install.dart
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PWAInstall {
  static bool _isInstallable = false;
  static bool _isIOS = false;
  static dynamic _deferredPrompt;

  // Initialize PWA installation detection
  static void initialize() {
    if (kIsWeb) {
      // Check if we're on iOS
      _isIOS = _checkIfIOS();

      // Listen for beforeinstallprompt event
      html.window.addEventListener('beforeinstallprompt', (event) {
        event.preventDefault();
        _deferredPrompt = event;
        _isInstallable = true;
      });

      // Also check if the app is already installed
      html.window.addEventListener('appinstalled', (event) {
        _isInstallable = false;
        _deferredPrompt = null;
      });
    }
  }

  // Check if the device is iOS
  static bool _checkIfIOS() {
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('iphone') ||
          userAgent.contains('ipad') ||
          userAgent.contains('ipod');
    }
    return false;
  }

  // Check if PWA is installable
  static bool isInstallable() {
    return _isInstallable;
  }

  // Getter for iOS detection
  static bool get isIOS {
    return _isIOS;
  }

  // Prompt the user to install the PWA
  static void promptInstall() {
    if (_deferredPrompt != null) {
      _deferredPrompt.prompt();

      _deferredPrompt.userChoice.then((choiceResult) {
        if (choiceResult['outcome'] == 'accepted') {
          print('User accepted the install prompt');
        } else {
          print('User dismissed the install prompt');
        }
        _deferredPrompt = null;
      });
    } else if (_isIOS) {
      // For iOS, we can't programmatically trigger the install prompt
      // So we show instructions instead
      _showIOSInstallInstructions();
    }
  }

  // Show iOS installation instructions
  static void _showIOSInstallInstructions() {
    // This would typically show a dialog with instructions
    // For now, we'll just log them
    print('To install this app on iOS:');
    print('1. Tap the Share button (square with arrow)');
    print('2. Scroll down and tap "Add to Home Screen"');
    print('3. Tap "Add" in the top right corner');
  }
}