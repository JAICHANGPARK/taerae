#include "include/flutter_taerae/flutter_taerae_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_taerae_plugin.h"

void TaeraeFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_taerae::TaeraeFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
