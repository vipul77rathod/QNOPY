import 'package:flutter/services.dart';

class ScreenshotProtection {
  static const MethodChannel _channel =
  MethodChannel('app/screenshot');

  static Future<void> enable() async {
    await _channel.invokeMethod('enableScreenshotProtection');
  }

  static Future<void> disable() async {
    await _channel.invokeMethod('disableScreenshotProtection');
  }
}