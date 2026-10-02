import 'package:flutter/foundation.dart';

typedef PrepareVpn = Future<bool> Function();
typedef RequestNotificationPermission = Future<bool> Function();
typedef StartFirewall = Future<bool> Function();
typedef StopFirewall = Future<bool> Function();
typedef GetFirewallStatus = Future<bool> Function();
typedef GetBlockedPackages = Future<Set<String>> Function();
typedef UpdateBlockedPackages = Future<bool> Function(Set<String> packageNames);

class FirewallProvider extends ChangeNotifier {
  FirewallProvider({
    PrepareVpn? prepareVpn,
    RequestNotificationPermission? requestNotificationPermission,
    StartFirewall? startFirewall,
    StopFirewall? stopFirewall,
    GetFirewallStatus? getFirewallStatus,
    GetBlockedPackages? getBlockedPackages,
    UpdateBlockedPackages? updateBlockedPackages,
  }) : _prepareVpn = prepareVpn ?? (() async => true),
       _requestNotificationPermission =
           requestNotificationPermission ?? (() async => true),
       _startFirewall = startFirewall ?? (() async => true),
       _stopFirewall = stopFirewall ?? (() async => true),
       _getFirewallStatus = getFirewallStatus ?? (() async => false),
       _getBlockedPackages = getBlockedPackages ?? (() async => <String>{}),
       _updateBlockedPackages = updateBlockedPackages ?? ((_) async => true);

  final PrepareVpn _prepareVpn;
  final RequestNotificationPermission _requestNotificationPermission;
  final StartFirewall _startFirewall;
  final StopFirewall _stopFirewall;
  final GetFirewallStatus _getFirewallStatus;
  final GetBlockedPackages _getBlockedPackages;
  final UpdateBlockedPackages _updateBlockedPackages;

  bool _isFirewallRunning = false;
  bool _isUpdatingFirewall = false;
  bool _isUpdatingBlockedPackages = false;
  Set<String> _blockedPackages = <String>{};
  String? _errorMessage;

  bool get isFirewallRunning => _isFirewallRunning;
  bool get isUpdatingFirewall => _isUpdatingFirewall;
  bool get isUpdatingBlockedPackages => _isUpdatingBlockedPackages;
  String? get errorMessage => _errorMessage;
  Set<String> get blockedPackages => Set.unmodifiable(_blockedPackages);

  String get statusLabel {
    if (_isUpdatingFirewall) {
      return _isFirewallRunning
          ? 'Stopping firewall...'
          : 'Starting firewall...';
    }
    if (_isFirewallRunning) {
      return 'Firewall active';
    }
    return 'Firewall off';
  }

  bool isBlocked(String packageName) {
    return _blockedPackages.contains(packageName);
  }

  bool isInternetAllowed(String packageName) {
    return !isBlocked(packageName);
  }

  Future<void> setFirewallRunning(bool isRunning) async {
    if (_isUpdatingFirewall || isRunning == _isFirewallRunning) {
      return;
    }

    _isUpdatingFirewall = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isRunning) {
        final hasPermission = await _prepareVpn();
        if (!hasPermission) {
          _errorMessage = 'VPN permission was not granted.';
          return;
        }

        final canShowNotification = await _requestNotificationPermission();
        if (!canShowNotification) {
          _errorMessage =
              'Notification permission is required to show firewall status.';
          return;
        }

        _isFirewallRunning = await _startFirewall();
      } else {
        final didStop = await _stopFirewall();
        if (didStop) {
          _isFirewallRunning = false;
        }
      }
    } catch (_) {
      _errorMessage = isRunning
          ? 'Unable to start firewall.'
          : 'Unable to stop firewall.';
    } finally {
      _isUpdatingFirewall = false;
      notifyListeners();
    }
  }

  Future<void> loadFirewallStatus() async {
    try {
      _isFirewallRunning = await _getFirewallStatus();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Unable to read firewall status.';
    }

    notifyListeners();
  }

  Future<void> setAppBlocked(String packageName, bool isBlocked) async {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) {
      _errorMessage = 'Invalid package name.';
      notifyListeners();
      return;
    }

    final previousPackages = Set<String>.from(_blockedPackages);
    final nextPackages = Set<String>.from(_blockedPackages);
    if (isBlocked) {
      nextPackages.add(normalizedPackage);
    } else {
      nextPackages.remove(normalizedPackage);
    }

    _blockedPackages = nextPackages;
    _isUpdatingBlockedPackages = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _updateBlockedPackages(_blockedPackages);
    } catch (_) {
      _blockedPackages = previousPackages;
      _errorMessage = 'Unable to update blocked apps.';
    } finally {
      _isUpdatingBlockedPackages = false;
      notifyListeners();
    }
  }

  Future<void> setAppsBlocked(
    Iterable<String> packageNames,
    bool isBlocked,
  ) async {
    final normalizedPackages = packageNames
        .map((packageName) => packageName.trim())
        .where((packageName) => packageName.isNotEmpty)
        .toSet();

    if (normalizedPackages.isEmpty) {
      _errorMessage = 'No apps available to update.';
      notifyListeners();
      return;
    }

    final previousPackages = Set<String>.from(_blockedPackages);
    final nextPackages = Set<String>.from(_blockedPackages);
    if (isBlocked) {
      nextPackages.addAll(normalizedPackages);
    } else {
      nextPackages.removeAll(normalizedPackages);
    }

    if (setEquals(previousPackages, nextPackages)) {
      return;
    }

    _blockedPackages = nextPackages;
    _isUpdatingBlockedPackages = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _updateBlockedPackages(_blockedPackages);
    } catch (_) {
      _blockedPackages = previousPackages;
      _errorMessage = 'Unable to update blocked apps.';
    } finally {
      _isUpdatingBlockedPackages = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadBlockedPackages() async {
    try {
      _blockedPackages = await _getBlockedPackages();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Unable to restore blocked apps.';
    }

    notifyListeners();
  }
}
