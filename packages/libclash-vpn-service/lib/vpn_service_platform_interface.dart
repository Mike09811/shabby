class VpnServiceResultError {
  final String message;
  VpnServiceResultError(this.message);
}

enum VpnServiceWaitType { done, timeout, error }

class VpnServiceWaitResult {
  final VpnServiceWaitType type;
  final VpnServiceResultError? err;
  VpnServiceWaitResult({required this.type, this.err});
}

class VpnServiceConfig {
  int? control_port;
  String? base_dir;
  String? work_dir;
  String? cache_dir;
  String? core_path;
  String? core_path_patch;
  String? core_path_patch_final;
  String? log_path;
  String? err_path;
  String? id;
  String? version;
  String? name;
  String? secret;
  String? install_refer;
  bool? prepare;
  bool? wake_lock;
  bool? auto_connect_at_boot;

  void fromJson(Map<String, dynamic> json) {}
  Map<String, dynamic> toJson() => {};
}

class ProxyOption {
  final String host;
  final int? port;
  final List<String>? bypass;
  ProxyOption(this.host, this.port, this.bypass);
}
