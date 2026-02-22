/// Flutter bindings for [TaeraeGraph]-based graph workflows.
///
/// This library re-exports the core graph APIs from `taerae_core` and adds
/// Flutter-friendly state management utilities such as [TaeraeGraphController].
library;

export 'package:taerae_core/taerae_core.dart';
export 'src/taerae_graph_controller.dart';

import 'flutter_taerae_platform_interface.dart';

/// Entry point for plugin-level platform integrations.
class TaeraeFlutter {
  /// Returns the current platform version string reported by the host runtime.
  Future<String?> getPlatformVersion() {
    return TaeraeFlutterPlatform.instance.getPlatformVersion();
  }
}
