#include "include/taerae_flutter/taerae_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "taerae_flutter_plugin.h"

void TaeraeFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  taerae_flutter::TaeraeFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
