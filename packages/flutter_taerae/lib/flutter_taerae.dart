export 'package:taerae_core/taerae_core.dart';
export 'src/taerae_graph_controller.dart';

import 'flutter_taerae_platform_interface.dart';

class TaeraeFlutter {
  Future<String?> getPlatformVersion() {
    return TaeraeFlutterPlatform.instance.getPlatformVersion();
  }
}
