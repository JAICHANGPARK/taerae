import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_taerae_method_channel.dart';

/// Platform interface for host-specific `flutter_taerae` implementations.
abstract class TaeraeFlutterPlatform extends PlatformInterface {
  /// Creates a platform interface instance.
  TaeraeFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static TaeraeFlutterPlatform _instance = MethodChannelTaeraeFlutter();

  /// The default instance of [TaeraeFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelTaeraeFlutter].
  static TaeraeFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TaeraeFlutterPlatform] when
  /// they register themselves.
  static set instance(TaeraeFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a host-provided platform version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
