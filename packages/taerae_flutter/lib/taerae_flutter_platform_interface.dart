import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'taerae_flutter_method_channel.dart';

abstract class TaeraeFlutterPlatform extends PlatformInterface {
  /// Constructs a TaeraeFlutterPlatform.
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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
