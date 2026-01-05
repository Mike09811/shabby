import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashmi/app/clash/clash_config.dart';
import 'package:clashmi/app/clash/clash_http_api.dart';
import 'package:clashmi/app/local_services/vpn_service.dart';
import 'package:clashmi/app/modules/auto_update_manager.dart';
import 'package:clashmi/app/modules/biz.dart';
import 'package:clashmi/app/modules/clash_setting_manager.dart';
import 'package:clashmi/app/modules/profile_manager.dart';
import 'package:clashmi/app/modules/setting_manager.dart';
import 'package:clashmi/app/modules/zashboard.dart';
import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/app_lifecycle_state_notify.dart';
import 'package:clashmi/app/utils/app_scheme_actions.dart';
import 'package:clashmi/app/utils/file_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/move_to_background_utils.dart';
import 'package:clashmi/app/utils/network_utils.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:clashmi/app/utils/platform_utils.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/about_screen.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:clashmi/screens/file_view_screen.dart';
import 'package:clashmi/screens/group_helper.dart';
import 'package:clashmi/screens/profiles_board_screen.dart';
import 'package:clashmi/screens/proxy_board_screen.dart';
import 'package:clashmi/screens/richtext_viewer.screen.dart';
import 'package:clashmi/screens/scheme_handler.dart';
import 'package:clashmi/screens/theme_config.dart';
import 'package:clashmi/screens/theme_define.dart';
import 'package:clashmi/screens/webview_helper.dart';
import 'package:clashmi/screens/widgets/segmented_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:libclash_vpn_service/state.dart';
import 'package:libclash_vpn_service/vpn_service.dart';
import 'package:quick_actions/quick_actions.dart';

class HomeScreenWidgetPart1 extends StatefulWidget {
  const HomeScreenWidgetPart1({super.key});

  @override
  State<HomeScreenWidgetPart1> createState() => _HomeScreenWidgetPart1();
}

class _HomeScreenWidgetPart1 extends State<HomeScreenWidgetPart1> {
  static final String _kNoSpeed = "↑ 0 B/s   ↓ 0 B/s";
  static final String _kNoTrafficTotal = "↑ 0 B   ↓ 0 B";
  //static final String _kNoMemory = "0 B   0 B";
  final FocusNode _focusNodeConnect = FocusNode();
  FlutterVpnServiceState _state = FlutterVpnServiceState.disconnected;
  Timer? _timerStateChecker;
  Timer? _timerConnectToCore;
  QuickActions? _quickActions;
  bool _quickActionWorking = false;

  //final ValueNotifier<String> _memory = ValueNotifier<String>(_kNoMemory);
  final ValueNotifier<String> _trafficSpeed = ValueNotifier<String>(_kNoSpeed);
  final ValueNotifier<String> _trafficTotal =
      ValueNotifier<String>(_kNoTrafficTotal);
  final ValueNotifier<String> _proxyNow = ValueNotifier<String>("");
  bool _proxyNowUpdating = false;

  @override
  void initState() {
    super.initState();
    VPNService.onEventStateChanged.add(_onStateChanged);
    AppLifecycleStateNofity.onStateResumed(hashCode, _onStateResumed);
    AppLifecycleStateNofity.onStatePaused(hashCode, _onStatePaused);
    ProfileManager.onEventCurrentChanged.add(_onCurrentChanged);
    ProfileManager.onEventUpdate.add(_onUpdate);
    if (!AppLifecycleStateNofity.isPaused()) {
      _onStateResumed();
    }
    Biz.onEventInitAllFinish.add(() async {
      if (Platform.isAndroid) {
        if (SettingManager.getConfig().excludeFromRecent) {
          FlutterVpnService.setExcludeFromRecents(true);
        }
      }
      await _onInitAllFinish();
    });
  }

  @override
  void dispose() {
    _focusNodeConnect.dispose();
    super.dispose();
  }

  void initQuickAction() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    String connect = AppSchemeActions.connectAction();
    String disconnect = AppSchemeActions.disconnectAction();
    try {
      _quickActions ??= QuickActions();
      await _quickActions!.initialize((String shortcutType) async {
        if (_quickActionWorking) {
          return;
        }
        _quickActionWorking = true;
        var state = await VPNService.getState();
        if (shortcutType == connect) {
          if (state != FlutterVpnServiceState.invalid &&
              state != FlutterVpnServiceState.disconnected) {
            MoveToBackgroundUtils.moveToBackground(
                duration: const Duration(milliseconds: 300));
            _quickActionWorking = false;
            return;
          }

          bool ok = await start("quickAction");
          if (ok) {
            MoveToBackgroundUtils.moveToBackground(
                duration: const Duration(milliseconds: 300));
          }
        } else if (shortcutType == disconnect) {
          if (state == FlutterVpnServiceState.connected) {
            await stop();
          }
          MoveToBackgroundUtils.moveToBackground(
              duration: const Duration(milliseconds: 300));
        }
        _quickActionWorking = false;
      });

      await _quickActions!.setShortcutItems(<ShortcutItem>[
        ShortcutItem(
          type: connect,
          localizedTitle: 'ON',
          icon: 'ic_launcher',
        ),
        ShortcutItem(
          type: disconnect,
          localizedTitle: 'OFF',
          icon: 'ic_launcher',
        ),
      ]);
    } catch (err, stacktrace) {
      Log.w("initQuickAction exception ${err.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final tcontext = Translations.of(context);
    bool connected = _state == FlutterVpnServiceState.connected;
    final currentProfile = ProfileManager.getCurrent();
    final currentProfileName = currentProfile?.getShowName() ?? "未选择节点";

    return Column(
      children: [
        // Top Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text(
                  "ClashMi",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // Mode Switch
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButton<ClashConfigsMode>(
                value: ClashSettingManager.getConfigsMode(),
                underline: SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                dropdownColor: Colors.grey[900],
                items: [
                  DropdownMenuItem(
                    value: ClashConfigsMode.rule,
                    child: Text(tcontext.meta.rule),
                  ),
                  DropdownMenuItem(
                    value: ClashConfigsMode.global,
                    child: Text(tcontext.meta.global),
                  ),
                ],
                onChanged: (ClashConfigsMode? newValue) async {
                  if (newValue != null) {
                    await ClashSettingManager.setConfigsMode(newValue);
                    setState(() {});
                    _updateProxyNow();
                  }
                },
              ),
            ),
          ],
        ),
        
        // Customer Service
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
               // Handle customer service tap
            },
            icon: Icon(Icons.headset_mic, color: Colors.grey),
            label: Text("客服", style: TextStyle(color: Colors.grey)),
          ),
        ),

        Spacer(),

        // Connect Button
        GestureDetector(
          onTap: () async {
            if (connected) {
              await stop();
            } else {
              await start("home");
            }
          },
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              border: Border.all(
                color: connected ? Colors.blue : Colors.grey,
                width: 2,
              ),
              boxShadow: connected
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.power_settings_new,
                  size: 60,
                  color: connected ? Colors.blue : Colors.grey,
                ),
                SizedBox(height: 10),
                Text(
                  connected ? "已连接" : (_state == FlutterVpnServiceState.connecting ? "连接中..." : "未连接"),
                  style: TextStyle(
                    color: connected ? Colors.blue : Colors.grey,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 40),

        // Node Selector
        InkWell(
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    settings: ProfilesBoardScreen.routSettings(),
                    builder: (context) => ProfilesBoardScreen()));
            setState(() {});
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              children: [
                Icon(Icons.public, color: Colors.blue),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentProfileName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (connected)
                        ValueListenableBuilder<String>(
                          valueListenable: _proxyNow,
                          builder: (context, value, child) {
                            return value.isNotEmpty 
                                ? Text(value, style: TextStyle(color: Colors.grey, fontSize: 12)) 
                                : SizedBox.shrink();
                          },
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),

        Spacer(),

        // Marketing Banner
        Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              "限时特惠：年卡 5 折起！",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithTrafficSpeedValue(
      BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: ThemeConfig.kFontSizeListSubItem),
      ),
    );
  }

  Widget _buildWithValue(BuildContext context, String value, Widget? child) {
    return SizedBox(
      child: Text(value,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: ThemeDefine.kColorBlue,
          )),
    );
  }

  Future<String> _getLocalAddress() async {
    String ipLocal = "127.0.0.1";
    String ipInterface = ipLocal;

    List<NetInterfacesInfo> interfaces =
        await NetworkUtils.getInterfaces(addressType: InternetAddressType.IPv4);
    if (interfaces.isNotEmpty) {
      ipInterface = interfaces.first.address;
    }
    for (var interf in interfaces) {
      if (interf.name.startsWith("en") || interf.name.startsWith("wlan")) {
        ipInterface = interf.address;
        break;
      }
    }

    return ipInterface;
  }

  Future<void> _onInitAllFinish() async {
    SchemeHandler.vpnConnect = _vpnSchemeConnect;
    SchemeHandler.vpnDisconnect = _vpnSchemeDisconnect;
    SchemeHandler.vpnReconnect = _vpnSchemeReconnect;
    initQuickAction();
    if (PlatformUtils.isPC()) {
      if (SettingManager.getConfig().autoConnectAfterLaunch) {
        await start("launch");
      }
    }
  }

  Future<void> stop() async {
    await VPNService.stop();
  }

  Future<bool> start(String from) async {
    final currentProfile = ProfileManager.getCurrent();
    if (currentProfile == null) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              settings: ProfilesBoardScreen.routSettings(),
              builder: (context) => ProfilesBoardScreen()));
      setState(() {});
      return false;
    }
    if (Platform.isLinux) {
      String? installer = await AutoUpdateManager.checkReplace();
      if (installer != null) {
        return true;
      }
      final servicePath = PathUtils.serviceExePath();
      if (!await FlutterVpnService.isServiceAuthorized(servicePath)) {
        if (!mounted) {
          return false;
        }
        String? password = await DialogUtils.showPasswordInputDialog(context);
        if (password == null || password.isEmpty) {
          setState(() {});
          return true;
        }
        final result =
            await FlutterVpnService.authorizeService(servicePath, password);
        if (result != null) {
          if (!mounted) {
            return false;
          }
          DialogUtils.showAlertDialog(context, result.message);
          setState(() {});
          return false;
        }
      }
    }
    var state = await VPNService.getState();
    if (state == FlutterVpnServiceState.connecting ||
        state == FlutterVpnServiceState.disconnecting ||
        state == FlutterVpnServiceState.reasserting) {
      setState(() {});
      return false;
    }

    var err = await VPNService.start(const Duration(seconds: 60));
    if (!mounted) {
      return false;
    }
    setState(() {});
    if (err != null) {
      if (err.message == "willCompleteAfterRebootInstall") {
        err.message = t.meta.willCompleteAfterRebootInstall;
      } else if (err.message == "requestNeedsUserApproval") {
        err.message = t.meta.requestNeedsUserApproval;
      } else if (err.message.contains("FullDiskAccessPermissionRequired")) {
        err.message = t.meta.FullDiskAccessPermissionRequired;
      }

      DialogUtils.showAlertDialog(context, err.message);
      return false;
    }

    return true;
  }

  Future<void> _vpnSchemeConnect(bool background) async {
    Future.delayed(const Duration(seconds: 0), () async {
      bool ok = await start("scheme");
      if (ok) {
        if (background) {
          MoveToBackgroundUtils.moveToBackground(
              duration: const Duration(milliseconds: 300));
        }
      }
    });
  }

  Future<void> _vpnSchemeDisconnect(bool background) async {
    Future.delayed(const Duration(seconds: 0), () async {
      await stop();
      if (background) {
        MoveToBackgroundUtils.moveToBackground(
            duration: const Duration(milliseconds: 300));
      }
    });
  }

  Future<void> _vpnSchemeReconnect(bool background) async {
    Future.delayed(const Duration(seconds: 0), () async {
      await stop();
      bool ok = await start("scheme");
      if (ok) {
        if (background) {
          MoveToBackgroundUtils.moveToBackground(
              duration: const Duration(milliseconds: 300));
        }
      }
    });
  }

  Future<void> _onStateChanged(
      FlutterVpnServiceState state, Map<String, String> params) async {
    if (_state == state) {
      return;
    }
    _state = state;
    if (state == FlutterVpnServiceState.disconnected) {
      _disconnectToCore();
      Biz.vpnStateChanged(false);
    } else if (state == FlutterVpnServiceState.connecting) {
    } else if (state == FlutterVpnServiceState.connected) {
      if (!AppLifecycleStateNofity.isPaused()) {
        _connectToCore();
      }
      Biz.vpnStateChanged(true);
    } else if (state == FlutterVpnServiceState.reasserting) {
      _disconnectToCore();
    } else if (state == FlutterVpnServiceState.disconnecting) {
      _stopStateCheckTimer();
      Zashboard.stop();
    } else {
      _disconnectToCore();
      Biz.vpnStateChanged(false);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _onStateResumed() async {
    _checkState();
    _startStateCheckTimer();
    _connectToCore();

    _updateProxyNow();
  }

  Future<void> _onStatePaused() async {
    _stopStateCheckTimer();
    _disconnectToCore(resetUI: false);
  }

  Future<void> _onCurrentChanged(String id) async {
    if (id.isEmpty) {
      await VPNService.stop();
      return;
    }

    final err = await VPNService.restart(const Duration(seconds: 60));
    if (err != null) {
      if (!mounted) {
        return;
      }
      DialogUtils.showAlertDialog(context, err.message);
    }
  }

  Future<void> _onUpdate(String id, bool finish) async {
    setState(() {});
  }

  Future<void> _checkState() async {
    var state = await VPNService.getState();
    await _onStateChanged(state, {});
  }

  void _startStateCheckTimer() {
    const Duration duration = Duration(seconds: 1);
    _timerStateChecker ??= Timer.periodic(duration, (timer) async {
      if (!Platform.isMacOS) {
        if (AppLifecycleStateNofity.isPaused()) {
          return;
        }
      }
      await _checkState();
    });
  }

  void _stopStateCheckTimer() {
    if (!Platform.isMacOS) {
      _timerStateChecker?.cancel();
      _timerStateChecker = null;
    }
  }

  Future<void> _connectToCore() async {
    bool started = await VPNService.getStarted();
    if (!started) {
      return;
    }
    if (AppLifecycleStateNofity.isPaused()) {
      return;
    }
    const Duration duration = Duration(seconds: 1);
    _timerConnectToCore ??= Timer.periodic(duration, (timer) async {
      if (AppLifecycleStateNofity.isPaused()) {
        return;
      }
      String connections = await FlutterVpnService.clashiApiConnections(false);
      String tranffic = await FlutterVpnService.clashiApiTraffic();
      if (AppLifecycleStateNofity.isPaused()) {
        return;
      }
      try {
        var obj = jsonDecode(connections);
        ClashConnections body = ClashConnections();
        body.fromJson(obj);
        //_memory.value =
        //    ClashHttpApi.convertTrafficToStringDouble(body.memory);
        _trafficTotal.value =
            "↑ ${ClashHttpApi.convertTrafficToStringDouble(body.uploadTotal)}  ↓ ${ClashHttpApi.convertTrafficToStringDouble(body.downloadTotal)} ";
      } catch (err) {}
      try {
        var obj = jsonDecode(tranffic);
        ClashTraffic traffic = ClashTraffic();
        traffic.fromJson(obj);
        _trafficSpeed.value =
            "↑ ${ClashHttpApi.convertTrafficToStringDouble(traffic.upload)}/s  ↓ ${ClashHttpApi.convertTrafficToStringDouble(traffic.download)}/s";
      } catch (err) {}

      if (_proxyNow.value.isEmpty) {
        Future.delayed(Duration(seconds: 1), () async {
          _updateProxyNow();
        });
      }
    });
  }

  Future<void> _disconnectToCore({bool resetUI = true}) async {
    _timerConnectToCore?.cancel();
    _timerConnectToCore = null;
    if (resetUI) {
      _trafficTotal.value = _kNoTrafficTotal;
      _trafficSpeed.value = _kNoSpeed;
      // _memory.value = _kNoMemory;
      _proxyNow.value = "";
    }
  }

  Future<void> _updateProxyNow() async {
    if (_state == FlutterVpnServiceState.connected) {
      if (AppLifecycleStateNofity.isPaused()) {
        return;
      }
      if (_proxyNowUpdating) {
        return;
      }
      _proxyNowUpdating = true;

      final result = await ClashHttpApi.getNowProxy(
          ClashSettingManager.getConfig().Mode ?? ClashConfigsMode.rule.name);
      if (result.error != null || result.data!.isEmpty) {
        _proxyNow.value = "";
      } else {
        if (result.data!.length >= 2) {
          if (result.data!.first.delay != null) {
            _proxyNow.value =
                "${result.data![1].name} -> ${result.data!.first.name} (${result.data!.first.delay} ms)";
          } else {
            _proxyNow.value =
                "${result.data![1].name} -> ${result.data!.first.name}";
          }
        } else {
          if (result.data!.first.delay != null) {
            _proxyNow.value =
                "${result.data!.first.name} (${result.data!.first.delay} ms)";
          } else {
            _proxyNow.value = result.data!.first.name;
          }
        }
      }
      _proxyNowUpdating = false;
    } else {
      _proxyNow.value = "";
    }
  }
}

class HomeScreenWidgetPart2 extends StatelessWidget {
  const HomeScreenWidgetPart2({super.key});

  @override
  Widget build(BuildContext context) {
    AutoUpdateCheckVersion versionCheck = AutoUpdateManager.getVersionCheck();
    final tcontext = Translations.of(context);
    var widgets = [
      ListTile(
        title: Text(tcontext.meta.settingApp),
        leading: Icon(
          Icons.settings,
          size: 20,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await GroupHelper.showAppSettings(context);
        },
      ),
      ListTile(
        title: Text(tcontext.meta.settingCore),
        leading: Icon(
          Icons.settings,
          size: 20,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await GroupHelper.showClashSettings(context);
        },
      ),
      ListTile(
        title: Text(tcontext.meta.coreLog),
        leading: Icon(
          Icons.set_meal,
          size: 20,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          String content = "";
          final filePath = await PathUtils.serviceLogFilePath();
          final item =
              await FileUtils.readAsStringReverse(filePath, 20 * 1024, false);
          if (item != null) {
            content = item.item1;
          }
          if (!context.mounted) {
            return;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  settings: RichtextViewScreen.routSettings(),
                  builder: (context) => RichtextViewScreen(
                      title: tcontext.meta.coreLog,
                      file: "",
                      content: content)));
        },
      ),
      ListTile(
        title: Text(tcontext.meta.backupAndSync),
        leading: Icon(
          Icons.backup,
          size: 20,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          GroupHelper.showBackupAndSync(context);
        },
      ),
    ];
    if (versionCheck.newVersion) {
      widgets.add(
        ListTile(
          title: Text(tcontext.meta.hasNewVersion(p: versionCheck.version)),
          leading: Icon(
            Icons.fiber_new_outlined,
            size: 20,
            color: Colors.red,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_right,
            size: 20,
          ),
          minVerticalPadding: 22,
          onTap: () async {
            GroupHelper.newVersionUpdate(context);
          },
        ),
      );
    }

    widgets.addAll([
      ListTile(
        title: Text(tcontext.meta.help),
        leading: Icon(
          Icons.help,
          size: 20,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await GroupHelper.showHelp(context);
        },
      ),
      ListTile(
        title: Text(tcontext.meta.about),
        leading: Icon(
          Icons.info,
          size: 20,
        ),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 20,
        ),
        minVerticalPadding: 22,
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  settings: AboutScreen.routSettings(),
                  builder: (context) => AboutScreen()));
        },
      )
    ]);

    return Card(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (_, index) {
          return widgets[index];
        },
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(
            height: 1,
            thickness: 0.3,
          );
        },
        itemCount: widgets.length,
      ),
    ));
  }
}
