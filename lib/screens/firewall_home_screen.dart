import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/installed_app.dart';
import '../providers/app_list_provider.dart';
import '../providers/firewall_provider.dart';
import '../widgets/installed_app_tile.dart';

enum AppFilter { all, blocked, allowed }

class FirewallHomeScreen extends StatefulWidget {
  const FirewallHomeScreen({super.key});

  @override
  State<FirewallHomeScreen> createState() => _FirewallHomeScreenState();
}

class _FirewallHomeScreenState extends State<FirewallHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  AppFilter _filter = AppFilter.all;

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
      appBar: AppBar(title: const Text('BlockNet')),
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
                      const SizedBox(height: 12),
                      _AppFilterChips(
                        selectedFilter: _filter,
                        onSelected: (filter) {
                          setState(() {
                            _filter = filter;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _InstalledAppList(filter: _filter),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppFilterChips extends StatelessWidget {
  const _AppFilterChips({
    required this.selectedFilter,
    required this.onSelected,
  });

  final AppFilter selectedFilter;
  final ValueChanged<AppFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final appList = context.watch<AppListProvider>();
    final firewall = context.watch<FirewallProvider>();
    final apps = appList.filteredApps;
    final blockedCount = apps
        .where((app) => firewall.isBlocked(app.packageName))
        .length;
    final allowedCount = apps.length - blockedCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            count: apps.length,
            isSelected: selectedFilter == AppFilter.all,
            onSelected: () => onSelected(AppFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Blocked',
            count: blockedCount,
            isSelected: selectedFilter == AppFilter.blocked,
            onSelected: () => onSelected(AppFilter.blocked),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Allowed',
            count: allowedCount,
            isSelected: selectedFilter == AppFilter.allowed,
            onSelected: () => onSelected(AppFilter.allowed),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: ValueKey('filter-${label.toLowerCase()}'),
      label: Text('$label $count'),
      selected: isSelected,
      onSelected: (_) => onSelected(),
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
                      if (firewall.errorMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          firewall.errorMessage!,
                          key: const ValueKey('firewall-error-message'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  label: 'firewall-master-switch',
                  child: Switch(
                    key: const ValueKey('firewall-master-switch'),
                    value: firewall.isFirewallRunning,
                    onChanged: firewall.isUpdatingFirewall
                        ? null
                        : firewall.setFirewallRunning,
                  ),
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

    return Semantics(
      label: 'app-search-field',
      child: TextField(
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
      ),
    );
  }
}

class _InstalledAppList extends StatelessWidget {
  const _InstalledAppList({required this.filter});

  final AppFilter filter;

  @override
  Widget build(BuildContext context) {
    final appList = context.watch<AppListProvider>();
    final firewall = context.watch<FirewallProvider>();

    if (appList.isLoading && appList.apps.isEmpty) {
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

    final apps = appList.filteredApps
        .where((app) {
          return switch (filter) {
            AppFilter.all => true,
            AppFilter.blocked => firewall.isBlocked(app.packageName),
            AppFilter.allowed => firewall.isInternetAllowed(app.packageName),
          };
        })
        .toList(growable: false);
    if (apps.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _MessageState(
          icon: Icons.apps_outlined,
          title: _emptyStateMessage(appList.searchQuery, filter),
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
          onAllowedChanged: (isAllowed) async {
            await firewall.setAppBlocked(app.packageName, !isAllowed);
          },
          iconBuilder: _buildIcon,
        );
      },
    );
  }

  String _emptyStateMessage(String searchQuery, AppFilter filter) {
    if (searchQuery.isNotEmpty) {
      return 'No apps match your search';
    }
    return switch (filter) {
      AppFilter.all => 'No launchable apps found',
      AppFilter.blocked => 'No blocked apps',
      AppFilter.allowed => 'No allowed apps',
    };
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
