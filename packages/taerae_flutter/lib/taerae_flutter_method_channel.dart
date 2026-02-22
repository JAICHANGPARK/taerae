import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'taerae_flutter_platform_interface.dart';

/// An implementation of [TaeraeFlutterPlatform] that uses method channels.
class MethodChannelTaeraeFlutter extends TaeraeFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('taerae_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
