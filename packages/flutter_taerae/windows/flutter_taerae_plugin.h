#ifndef FLUTTER_PLUGIN_TAERAE_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_TAERAE_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_taerae {

class TaeraeFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TaeraeFlutterPlugin();

  virtual ~TaeraeFlutterPlugin();

  // Disallow copy and assign.
  TaeraeFlutterPlugin(const TaeraeFlutterPlugin&) = delete;
  TaeraeFlutterPlugin& operator=(const TaeraeFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_taerae

#endif  // FLUTTER_PLUGIN_TAERAE_FLUTTER_PLUGIN_H_
