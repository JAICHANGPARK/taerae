// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_taerae_platform_interface.dart';

/// Web implementation of [TaeraeFlutterPlatform].
class TaeraeFlutterWeb extends TaeraeFlutterPlatform {
  /// Creates a web platform implementation.
  TaeraeFlutterWeb();

  /// Registers this class as the active platform implementation.
  static void registerWith(Registrar registrar) {
    TaeraeFlutterPlatform.instance = TaeraeFlutterWeb();
  }

  /// The browser user-agent string for this runtime.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }
}
