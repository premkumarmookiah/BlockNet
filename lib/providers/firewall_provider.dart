import 'package:flutter/foundation.dart';

class FirewallProvider extends ChangeNotifier {
  bool _isFirewallRunning = false;
  final Set<String> _blockedPackages = <String>{};
  String? _errorMessage;

  bool get isFirewallRunning => _isFirewallRunning;
  String? get errorMessage => _errorMessage;
  Set<String> get blockedPackages => Set.unmodifiable(_blockedPackages);

  String get statusLabel {
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
    _isFirewallRunning = isRunning;
    _errorMessage = null;
    notifyListeners();
  }

  void setAppBlocked(String packageName, bool isBlocked) {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) {
      _errorMessage = 'Invalid package name.';
      notifyListeners();
      return;
    }

    if (isBlocked) {
      _blockedPackages.add(normalizedPackage);
    } else {
      _blockedPackages.remove(normalizedPackage);
    }

    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }
}
