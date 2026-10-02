import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blocknet/models/installed_app.dart';
import 'package:blocknet/providers/app_list_provider.dart';
import 'package:blocknet/providers/firewall_provider.dart';
import 'package:blocknet/screens/firewall_home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  const chrome = InstalledApp(
    name: 'Chrome',
    packageName: 'com.android.chrome',
  );
  const maps = InstalledApp(
    name: 'Maps',
    packageName: 'com.google.android.apps.maps',
  );

  testWidgets('shows loading indicator while apps load', (tester) async {
    final pendingLoad = Completer<List<InstalledApp>>();

    await tester.pumpWidget(_TestApp(loadApps: () => pendingLoad.future));
    await tester.pump();

    expect(find.byKey(const ValueKey('apps-loading')), findsOneWidget);

    pendingLoad.complete([chrome]);
    await tester.pumpAndSettle();
  });

  testWidgets('shows installed application list', (tester) async {
    await tester.pumpWidget(_TestApp(loadApps: () async => [chrome, maps]));
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('com.android.chrome'), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
  });

  testWidgets('filters apps by search text and clears search', (tester) async {
    await tester.pumpWidget(_TestApp(loadApps: () async => [chrome, maps]));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('app-search-field')),
      'maps',
    );
    await tester.pumpAndSettle();

    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Chrome'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('clear-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Chrome'), findsOneWidget);
  });

  testWidgets('toggles firewall switch', (tester) async {
    await tester.pumpWidget(_TestApp(loadApps: () async => [chrome]));
    await tester.pumpAndSettle();

    expect(find.text('Firewall off'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('firewall-master-switch')));
    await tester.pumpAndSettle();

    expect(find.text('Firewall active'), findsOneWidget);
  });

  testWidgets('shows firewall error message', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        loadApps: () async => [chrome],
        firewallProvider: FirewallProvider(prepareVpn: () async => false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('firewall-master-switch')));
    await tester.pumpAndSettle();

    expect(find.text('VPN permission was not granted.'), findsOneWidget);
  });

  testWidgets('toggles application internet access', (tester) async {
    await tester.pumpWidget(_TestApp(loadApps: () async => [chrome]));
    await tester.pumpAndSettle();

    final appSwitch = find.byKey(
      const ValueKey('internet-switch-com.android.chrome'),
    );

    expect(tester.widget<Switch>(appSwitch).value, isTrue);

    await tester.tap(appSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(appSwitch).value, isFalse);
    expect(find.text('1 apps blocked'), findsOneWidget);
  });

  testWidgets('filters by blocked and allowed apps', (tester) async {
    await tester.pumpWidget(_TestApp(loadApps: () async => [chrome, maps]));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('internet-switch-com.android.chrome')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('filter-blocked')));
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
    expect(find.text('Maps'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('filter-allowed')));
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsNothing);
    expect(find.text('Maps'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(_TestApp(loadApps: () async => const []));
    await tester.pumpAndSettle();

    expect(find.text('No launchable apps found'), findsOneWidget);
  });

  testWidgets('shows error state and retries', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _TestApp(
        loadApps: () async {
          calls += 1;
          if (calls == 1) {
            throw Exception('failed');
          }
          return [chrome];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load installed apps.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retry-load-apps-button')));
    await tester.pumpAndSettle();

    expect(find.text('Chrome'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.loadApps, this.firewallProvider});

  final Future<List<InstalledApp>> Function() loadApps;
  final FirewallProvider? firewallProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppListProvider(appLoader: loadApps),
        ),
        ChangeNotifierProvider(
          create: (_) => firewallProvider ?? FirewallProvider(),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const FirewallHomeScreen(),
      ),
    );
  }
}
