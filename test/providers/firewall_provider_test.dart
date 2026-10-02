import 'package:flutter_test/flutter_test.dart';
import 'package:blocknet/providers/firewall_provider.dart';

void main() {
  test('starts with firewall stopped and no blocked apps', () {
    final provider = FirewallProvider();

    expect(provider.isFirewallRunning, isFalse);
    expect(provider.statusLabel, 'Firewall off');
    expect(provider.blockedPackages, isEmpty);
    expect(provider.errorMessage, isNull);
  });

  test('updates firewall running state', () async {
    final provider = FirewallProvider();

    await provider.setFirewallRunning(true);

    expect(provider.isFirewallRunning, isTrue);
    expect(provider.statusLabel, 'Firewall active');

    await provider.setFirewallRunning(false);

    expect(provider.isFirewallRunning, isFalse);
  });

  test('loads firewall status from native callback', () async {
    final provider = FirewallProvider(getFirewallStatus: () async => true);

    await provider.loadFirewallStatus();

    expect(provider.isFirewallRunning, isTrue);
    expect(provider.errorMessage, isNull);
  });

  test('sets error when firewall status loading fails', () async {
    final provider = FirewallProvider(
      getFirewallStatus: () => Future<bool>.error(Exception('status failed')),
    );

    await provider.loadFirewallStatus();

    expect(provider.errorMessage, 'Unable to read firewall status.');
  });

  test('does not start firewall when VPN permission is rejected', () async {
    var startCalls = 0;
    final provider = FirewallProvider(
      prepareVpn: () async => false,
      startFirewall: () async {
        startCalls += 1;
        return true;
      },
    );

    await provider.setFirewallRunning(true);

    expect(startCalls, 0);
    expect(provider.isFirewallRunning, isFalse);
    expect(provider.errorMessage, 'VPN permission was not granted.');
  });

  test(
    'does not start firewall when notification permission is rejected',
    () async {
      var startCalls = 0;
      final provider = FirewallProvider(
        prepareVpn: () async => true,
        requestNotificationPermission: () async => false,
        startFirewall: () async {
          startCalls += 1;
          return true;
        },
      );

      await provider.setFirewallRunning(true);

      expect(startCalls, 0);
      expect(provider.isFirewallRunning, isFalse);
      expect(
        provider.errorMessage,
        'Notification permission is required to show firewall status.',
      );
    },
  );

  test('sets error when firewall start fails', () async {
    final provider = FirewallProvider(
      prepareVpn: () async => true,
      startFirewall: () => Future<bool>.error(Exception('start failed')),
    );

    await provider.setFirewallRunning(true);

    expect(provider.isFirewallRunning, isFalse);
    expect(provider.errorMessage, 'Unable to start firewall.');
  });

  test('sets error when firewall stop fails', () async {
    final provider = FirewallProvider(
      startFirewall: () async => true,
      stopFirewall: () => Future<bool>.error(Exception('stop failed')),
    );

    await provider.setFirewallRunning(true);
    await provider.setFirewallRunning(false);

    expect(provider.isFirewallRunning, isTrue);
    expect(provider.errorMessage, 'Unable to stop firewall.');
  });

  test('loads blocked applications from native callback', () async {
    final provider = FirewallProvider(
      getBlockedPackages: () async => {'com.example.saved'},
    );

    await provider.loadBlockedPackages();

    expect(provider.blockedPackages, {'com.example.saved'});
  });

  test('sets error when blocked applications restore fails', () async {
    final provider = FirewallProvider(
      getBlockedPackages: () =>
          Future<Set<String>>.error(Exception('restore failed')),
    );

    await provider.loadBlockedPackages();

    expect(provider.errorMessage, 'Unable to restore blocked apps.');
  });

  test('blocks and unblocks one application', () async {
    final provider = FirewallProvider();

    await provider.setAppBlocked('com.example.target', true);

    expect(provider.isBlocked('com.example.target'), isTrue);
    expect(provider.isInternetAllowed('com.example.target'), isFalse);

    await provider.setAppBlocked('com.example.target', false);

    expect(provider.isBlocked('com.example.target'), isFalse);
    expect(provider.isInternetAllowed('com.example.target'), isTrue);
  });

  test('supports blocking multiple applications', () async {
    final provider = FirewallProvider();

    await provider.setAppBlocked('com.example.one', true);
    await provider.setAppBlocked('com.example.two', true);

    expect(provider.blockedPackages, {'com.example.one', 'com.example.two'});
  });

  test('blocks and unblocks applications in bulk', () async {
    final updates = <Set<String>>[];
    final provider = FirewallProvider(
      updateBlockedPackages: (packageNames) async {
        updates.add(Set<String>.from(packageNames));
        return true;
      },
    );

    await provider.setAppsBlocked(['com.example.one', 'com.example.two'], true);

    expect(provider.blockedPackages, {'com.example.one', 'com.example.two'});
    expect(updates.single, {'com.example.one', 'com.example.two'});

    await provider.setAppsBlocked([
      'com.example.one',
      'com.example.two',
    ], false);

    expect(provider.blockedPackages, isEmpty);
    expect(updates.last, isEmpty);
  });

  test('rolls back blocked state when native update fails', () async {
    final provider = FirewallProvider(
      updateBlockedPackages: (_) =>
          Future<bool>.error(Exception('update failed')),
    );

    await provider.setAppBlocked('com.example.target', true);

    expect(provider.blockedPackages, isEmpty);
    expect(provider.errorMessage, 'Unable to update blocked apps.');
  });

  test('rolls back bulk blocked state when native update fails', () async {
    final provider = FirewallProvider(
      updateBlockedPackages: (_) =>
          Future<bool>.error(Exception('update failed')),
    );

    await provider.setAppsBlocked(['com.example.target'], true);

    expect(provider.blockedPackages, isEmpty);
    expect(provider.errorMessage, 'Unable to update blocked apps.');
  });

  test('rejects empty package names', () async {
    final provider = FirewallProvider();

    await provider.setAppBlocked('   ', true);

    expect(provider.blockedPackages, isEmpty);
    expect(provider.errorMessage, 'Invalid package name.');
  });
}
