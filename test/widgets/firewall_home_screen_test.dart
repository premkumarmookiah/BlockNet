import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_on_off/models/installed_app.dart';
import 'package:internet_on_off/providers/app_list_provider.dart';
import 'package:internet_on_off/providers/firewall_provider.dart';
import 'package:internet_on_off/screens/firewall_home_screen.dart';
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
  const _TestApp({required this.loadApps});

  final Future<List<InstalledApp>> Function() loadApps;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppListProvider(appLoader: loadApps),
        ),
        ChangeNotifierProvider(create: (_) => FirewallProvider()),
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
