import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_list_provider.dart';
import 'providers/firewall_provider.dart';
import 'screens/firewall_home_screen.dart';
import 'services/native_firewall_service.dart';

void main() {
  runApp(const BlockNetApp());
}

class BlockNetApp extends StatelessWidget {
  const BlockNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firewallService = NativeFirewallService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AppListProvider(appLoader: firewallService.getInstalledApps),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              FirewallProvider(
                  prepareVpn: firewallService.prepareVpn,
                  requestNotificationPermission:
                      firewallService.requestNotificationPermission,
                  startFirewall: firewallService.startFirewall,
                  stopFirewall: firewallService.stopFirewall,
                  getFirewallStatus: firewallService.getFirewallStatus,
                  getBlockedPackages: firewallService.getBlockedApps,
                  updateBlockedPackages: firewallService.updateBlockedApps,
                )
                ..loadFirewallStatus()
                ..loadBlockedPackages(),
        ),
      ],
      child: MaterialApp(
        title: 'BlockNet',
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
