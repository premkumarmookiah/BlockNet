import 'package:flutter_test/flutter_test.dart';
import 'package:internet_on_off/providers/firewall_provider.dart';

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

  test('blocks and unblocks one application', () {
    final provider = FirewallProvider();

    provider.setAppBlocked('com.example.target', true);

    expect(provider.isBlocked('com.example.target'), isTrue);
    expect(provider.isInternetAllowed('com.example.target'), isFalse);

    provider.setAppBlocked('com.example.target', false);

    expect(provider.isBlocked('com.example.target'), isFalse);
    expect(provider.isInternetAllowed('com.example.target'), isTrue);
  });

  test('supports blocking multiple applications', () {
    final provider = FirewallProvider();

    provider.setAppBlocked('com.example.one', true);
    provider.setAppBlocked('com.example.two', true);

    expect(provider.blockedPackages, {'com.example.one', 'com.example.two'});
  });

  test('rejects empty package names', () {
    final provider = FirewallProvider();

    provider.setAppBlocked('   ', true);

    expect(provider.blockedPackages, isEmpty);
    expect(provider.errorMessage, 'Invalid package name.');
  });
}
