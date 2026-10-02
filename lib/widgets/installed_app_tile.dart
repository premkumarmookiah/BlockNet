import 'package:flutter/material.dart';

import '../models/installed_app.dart';

typedef InstalledAppIconBuilder = Widget Function(InstalledApp app);

class InstalledAppTile extends StatelessWidget {
  const InstalledAppTile({
    required this.app,
    required this.isInternetAllowed,
    required this.onAllowedChanged,
    required this.iconBuilder,
    super.key,
  });

  final InstalledApp app;
  final bool isInternetAllowed;
  final ValueChanged<bool> onAllowedChanged;
  final InstalledAppIconBuilder iconBuilder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: iconBuilder(app),
      title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        app.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Semantics(
        label: 'internet-switch-${app.packageName}',
        child: Switch(
          key: ValueKey('internet-switch-${app.packageName}'),
          value: isInternetAllowed,
          onChanged: onAllowedChanged,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
