import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_list_provider.dart';
import 'providers/firewall_provider.dart';
import 'screens/firewall_home_screen.dart';
import 'services/mock_installed_app_service.dart';

void main() {
  runApp(const InternetFirewallApp());
}

class InternetFirewallApp extends StatelessWidget {
  const InternetFirewallApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appService = MockInstalledAppService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AppListProvider(appLoader: appService.getInstalledApps),
        ),
        ChangeNotifierProvider(create: (_) => FirewallProvider()),
      ],
      child: MaterialApp(
        title: 'Internet Firewall',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const FirewallHomeScreen(),
      ),
    );
  }
}
