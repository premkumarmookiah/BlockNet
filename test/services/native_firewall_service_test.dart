import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blocknet/models/installed_app.dart';
import 'package:blocknet/providers/app_list_provider.dart';
import 'package:blocknet/services/native_firewall_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('blocknet/test_firewall');
  late NativeFirewallService service;

  setUp(() {
    service = NativeFirewallService.withChannel(channel);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('converts getInstalledApps native response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getInstalledApps');

          return [
            {
              'name': 'Chrome',
              'packageName': 'com.android.chrome',
              'iconBase64': 'abc123',
            },
          ];
        });

    final apps = await service.getInstalledApps();

    expect(apps, hasLength(1));
    expect(apps.first.name, 'Chrome');
    expect(apps.first.packageName, 'com.android.chrome');
    expect(apps.first.iconBase64, 'abc123');
  });

  test('throws NativeFirewallException for malformed response item', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => ['not-a-map']);

    expect(service.getInstalledApps(), throwsA(isA<NativeFirewallException>()));
  });

  test('throws NativeFirewallException for malformed app object', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => [
            {'name': 'Chrome'},
          ],
        );

    expect(service.getInstalledApps(), throwsA(isA<NativeFirewallException>()));
  });

  test('throws NativeFirewallException for MethodChannel failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'INSTALLED_APPS_FAILED',
            message: 'PackageManager failed',
          ),
        );

    expect(
      service.getInstalledApps(),
      throwsA(
        isA<NativeFirewallException>().having(
          (error) => error.message,
          'message',
          'PackageManager failed',
        ),
      ),
    );
  });

  test('calls prepareVpn and returns permission result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'prepareVpn');
          return true;
        });

    expect(await service.prepareVpn(), isTrue);
  });

  test('calls requestNotificationPermission', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestNotificationPermission');
          return true;
        });

    expect(await service.requestNotificationPermission(), isTrue);
  });

  test('calls startFirewall and stopFirewall', () async {
    final methodCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call.method);
          return true;
        });

    expect(await service.startFirewall(), isTrue);
    expect(await service.stopFirewall(), isTrue);

    expect(methodCalls, ['startFirewall', 'stopFirewall']);
  });

  test('calls getFirewallStatus', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getFirewallStatus');
          return false;
        });

    expect(await service.getFirewallStatus(), isFalse);
  });

  test('loads blocked apps from native response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getBlockedApps');
          return ['com.example.one', 'com.example.two'];
        });

    expect(await service.getBlockedApps(), {
      'com.example.one',
      'com.example.two',
    });
  });

  test('updates blocked apps through native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'updateBlockedApps');
          expect(call.arguments, {
            'packageNames': ['com.example.one'],
          });
          return true;
        });

    expect(await service.updateBlockedApps({'com.example.one'}), isTrue);
  });

  test('throws NativeFirewallException for malformed blocked app response', () {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => [123]);

    expect(service.getBlockedApps(), throwsA(isA<NativeFirewallException>()));
  });

  test('throws NativeFirewallException when bool response is null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    expect(service.startFirewall(), throwsA(isA<NativeFirewallException>()));
  });

  test('loads native apps through AppListProvider integration', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => [
            {'name': 'Maps', 'packageName': 'com.google.android.apps.maps'},
            {'name': 'Chrome', 'packageName': 'com.android.chrome'},
          ],
        );
    final provider = AppListProvider(appLoader: service.getInstalledApps);

    await provider.loadInstalledApps();

    expect(provider.errorMessage, isNull);
    expect(provider.apps, const [
      InstalledApp(name: 'Chrome', packageName: 'com.android.chrome'),
      InstalledApp(name: 'Maps', packageName: 'com.google.android.apps.maps'),
    ]);
  });
}
