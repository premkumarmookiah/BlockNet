import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/installed_app.dart';
import '../providers/app_list_provider.dart';
import '../providers/firewall_provider.dart';
import '../widgets/installed_app_tile.dart';

class FirewallHomeScreen extends StatefulWidget {
  const FirewallHomeScreen({super.key});

  @override
  State<FirewallHomeScreen> createState() => _FirewallHomeScreenState();
}

class _FirewallHomeScreenState extends State<FirewallHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppListProvider>().loadInstalledApps();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Internet Firewall')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: context.read<AppListProvider>().loadInstalledApps,
          child: CustomScrollView(
            key: const ValueKey('firewall-scroll-view'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FirewallStatusCard(),
                      const SizedBox(height: 16),
                      _SearchField(controller: _searchController),
                    ],
                  ),
                ),
              ),
              const _InstalledAppList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirewallStatusCard extends StatelessWidget {
  const _FirewallStatusCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<FirewallProvider>(
      builder: (context, firewall, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  firewall.isFirewallRunning
                      ? Icons.shield
                      : Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firewall.statusLabel,
                        key: const ValueKey('firewall-status-label'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${firewall.blockedPackages.length} apps blocked',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('firewall-master-switch'),
                  value: firewall.isFirewallRunning,
                  onChanged: firewall.setFirewallRunning,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final appList = context.watch<AppListProvider>();

    if (controller.text != appList.searchQuery) {
      controller.value = controller.value.copyWith(
        text: appList.searchQuery,
        selection: TextSelection.collapsed(offset: appList.searchQuery.length),
        composing: TextRange.empty,
      );
    }

    return TextField(
      key: const ValueKey('app-search-field'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search apps',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: appList.searchQuery.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('clear-search-button'),
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: appList.clearSearch,
              ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      onChanged: appList.setSearchQuery,
    );
  }
}

class _InstalledAppList extends StatelessWidget {
  const _InstalledAppList();

  @override
  Widget build(BuildContext context) {
    final appList = context.watch<AppListProvider>();
    final firewall = context.watch<FirewallProvider>();

    if (appList.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(key: ValueKey('apps-loading')),
        ),
      );
    }

    if (appList.errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _MessageState(
          icon: Icons.error_outline,
          title: appList.errorMessage!,
          actionLabel: 'Retry',
          onActionPressed: context.read<AppListProvider>().loadInstalledApps,
        ),
      );
    }

    final apps = appList.filteredApps;
    if (apps.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _MessageState(
          icon: Icons.apps_outlined,
          title: appList.searchQuery.isEmpty
              ? 'No launchable apps found'
              : 'No apps match your search',
        ),
      );
    }

    return SliverList.separated(
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final app = apps[index];
        return InstalledAppTile(
          key: ValueKey('app-tile-${app.packageName}'),
          app: app,
          isInternetAllowed: firewall.isInternetAllowed(app.packageName),
          onAllowedChanged: (isAllowed) {
            firewall.setAppBlocked(app.packageName, !isAllowed);
          },
          iconBuilder: _buildIcon,
        );
      },
    );
  }

  Widget _buildIcon(InstalledApp app) {
    final iconBytes = _decodeIcon(app.iconBase64);
    if (iconBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          iconBytes,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _InitialIcon(app: app),
        ),
      );
    }

    return _InitialIcon(app: app);
  }

  Uint8List? _decodeIcon(String? iconBase64) {
    if (iconBase64 == null || iconBase64.isEmpty) {
      return null;
    }

    try {
      return base64Decode(iconBase64);
    } on FormatException {
      return null;
    }
  }
}

class _InitialIcon extends StatelessWidget {
  const _InitialIcon({required this.app});

  final InstalledApp app;

  @override
  Widget build(BuildContext context) {
    final initial = app.name.trim().isEmpty ? '?' : app.name.characters.first;

    return CircleAvatar(radius: 22, child: Text(initial.toUpperCase()));
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            key: const ValueKey('message-state-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('retry-load-apps-button'),
              onPressed: onActionPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
