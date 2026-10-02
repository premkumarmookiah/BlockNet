import 'package:flutter/foundation.dart';

import '../models/installed_app.dart';

typedef InstalledAppLoader = Future<List<InstalledApp>> Function();

class AppListProvider extends ChangeNotifier {
  AppListProvider({required InstalledAppLoader appLoader})
    : _loadApps = appLoader;

  final InstalledAppLoader _loadApps;

  List<InstalledApp> _apps = const [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String? _errorMessage;

  List<InstalledApp> get apps => List.unmodifiable(_apps);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  List<InstalledApp> get filteredApps {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return apps;
    }

    return _apps
        .where(
          (app) =>
              app.name.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> loadInstalledApps() async {
    final hasExistingApps = _apps.isNotEmpty;
    if (hasExistingApps) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final loadedApps = await _loadApps().timeout(const Duration(seconds: 12));
      _apps = [...loadedApps]
        ..sort(
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        );
    } catch (_) {
      _apps = const [];
      _errorMessage = 'Unable to load installed apps.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    setSearchQuery('');
  }
}
