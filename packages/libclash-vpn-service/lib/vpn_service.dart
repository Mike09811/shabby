import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'state.dart';
import 'vpn_service_platform_interface.dart';

class FlutterVpnService {
  static FlutterVpnServiceState _currentState =
      FlutterVpnServiceState.disconnected;

  static Future<String> getABIs() async => "arm64-v8a,armeabi-v7a,x86_64";
  static Future<bool> isRunAsAdmin() async => false;
  static Future<void> firewallAddApp(String path, String name) async {}
  static Future<void> firewallAddPorts(List<int?> ports, String name) async {}

  static void onStateChanged(
      void Function(FlutterVpnServiceState state, Map<String, String> params)
          callback) {}

  static Future<void> prepareConfig({
    required VpnServiceConfig config,
    required String tunnelServicePath,
    required String configFilePath,
    required bool systemExtension,
    required String bundleIdentifier,
    required String uiServerAddress,
    required String uiLocalizedDescription,
    required List<dynamic> excludePorts,
  }) async {}

  static Future<VpnServiceResultError?> installService() async => null;
  static Future<VpnServiceResultError?> uninstallService() async => null;

  static Future<VpnServiceWaitResult> restart(Duration timeout) async {
    _currentState = FlutterVpnServiceState.connected;
    return VpnServiceWaitResult(type: VpnServiceWaitType.done);
  }

  static Future<VpnServiceWaitResult> start(Duration timeout) async {
    _currentState = FlutterVpnServiceState.connected;
    return VpnServiceWaitResult(type: VpnServiceWaitType.done);
  }

  static Future<void> stop() async {
    _currentState = FlutterVpnServiceState.disconnected;
  }

  static Future<void> setSystemProxy(ProxyOption option) async {}
  static Future<void> cleanSystemProxy() async {}
  static Future<bool> getSystemProxyEnable(ProxyOption? option) async => false;

  static Future<FlutterVpnServiceState> get currentState async => _currentState;

  static Future<void> autoStartCreate(String name, String path,
      {String? processArgs, bool? runElevated}) async {}
  static Future<void> autoStartDelete(String name) async {}
  static Future<bool> autoStartIsActive(String name) async => false;

  static Future<void> setAlwaysOn(bool enable) async {}

  // Added methods
  static Future<String> getSystemVersion() async => "1.0.0";
  static Future<void> hideDockIcon(bool hide) async {}
  static Future<Directory?> getAppGroupDirectory(String groupId) async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<String?> setExcludeFromRecents(bool exclude) async => null;
  static Future<bool> isServiceAuthorized(String path) async => true;
  static Future<VpnServiceResultError?> authorizeService(
          String path, String password) async =>
      null;
  static Future<String> clashiApiConnections(bool force) async => "{}";
  static Future<String> clashiApiTraffic() async => "{}";
}
