import 'package:flutter/services.dart';

import '../models/installed_app.dart';

class NativeFirewallService {
  NativeFirewallService()
    : this.withChannel(const MethodChannel('blocknet/firewall'));

  NativeFirewallService.withChannel(this._channel);

  final MethodChannel _channel;

  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final response = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );

      if (response == null) {
        throw const FormatException('Native app list response was null.');
      }

      return response.map(_installedAppFromNative).toList(growable: false);
    } on PlatformException catch (error) {
      throw NativeFirewallException(
        error.message ?? 'Unable to load installed apps from Android.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw NativeFirewallException(error.message, cause: error);
    } on TypeError catch (error) {
      throw NativeFirewallException(
        'Native app list response had an unexpected shape.',
        cause: error,
      );
    }
  }

  Future<bool> prepareVpn() async {
    return _invokeBool('prepareVpn');
  }

  Future<bool> requestNotificationPermission() async {
    return _invokeBool('requestNotificationPermission');
  }

  Future<bool> startFirewall() async {
    return _invokeBool('startFirewall');
  }

  Future<bool> stopFirewall() async {
    return _invokeBool('stopFirewall');
  }

  Future<bool> getFirewallStatus() async {
    return _invokeBool('getFirewallStatus');
  }

  Future<Set<String>> getBlockedApps() async {
    try {
      final response = await _channel.invokeMethod<List<dynamic>>(
        'getBlockedApps',
      );
      if (response == null) {
        throw const FormatException('getBlockedApps returned null.');
      }

      return response.map((packageName) {
        if (packageName is! String || packageName.trim().isEmpty) {
          throw const FormatException('Blocked package response is invalid.');
        }
        return packageName;
      }).toSet();
    } on PlatformException catch (error) {
      throw NativeFirewallException(
        error.message ?? 'Unable to load blocked apps.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw NativeFirewallException(error.message, cause: error);
    }
  }

  Future<bool> updateBlockedApps(Set<String> packageNames) async {
    try {
      final response = await _channel.invokeMethod<bool>('updateBlockedApps', {
        'packageNames': packageNames.toList(growable: false),
      });
      if (response == null) {
        throw const FormatException('updateBlockedApps returned null.');
      }
      return response;
    } on PlatformException catch (error) {
      throw NativeFirewallException(
        error.message ?? 'Unable to update blocked apps.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw NativeFirewallException(error.message, cause: error);
    }
  }

  Future<bool> _invokeBool(String methodName) async {
    try {
      final response = await _channel.invokeMethod<bool>(methodName);
      if (response == null) {
        throw FormatException('$methodName returned null.');
      }
      return response;
    } on PlatformException catch (error) {
      throw NativeFirewallException(
        error.message ?? 'Native firewall call failed.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw NativeFirewallException(error.message, cause: error);
    }
  }

  InstalledApp _installedAppFromNative(Object? item) {
    if (item is! Map) {
      throw const FormatException('Native app list item was not an object.');
    }

    return InstalledApp.fromMap(Map<String, Object?>.from(item));
  }
}

class NativeFirewallException implements Exception {
  const NativeFirewallException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'NativeFirewallException: $message';
}
