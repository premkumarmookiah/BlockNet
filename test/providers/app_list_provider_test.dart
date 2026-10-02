import 'package:flutter_test/flutter_test.dart';
import 'package:internet_on_off/models/installed_app.dart';
import 'package:internet_on_off/providers/app_list_provider.dart';

void main() {
  const chrome = InstalledApp(
    name: 'Chrome',
    packageName: 'com.android.chrome',
  );
  const maps = InstalledApp(
    name: 'Maps',
    packageName: 'com.google.android.apps.maps',
  );

  test('starts with empty state', () {
    final provider = AppListProvider(appLoader: () async => const []);

    expect(provider.apps, isEmpty);
    expect(provider.filteredApps, isEmpty);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.searchQuery, isEmpty);
  });

  test('loads installed apps successfully', () async {
    final provider = AppListProvider(appLoader: () async => [maps, chrome]);

    final loadFuture = provider.loadInstalledApps();

    expect(provider.isLoading, isTrue);

    await loadFuture;

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.apps.map((app) => app.name), ['Chrome', 'Maps']);
  });

  test('sets error when installed app loading fails', () async {
    final provider = AppListProvider(
      appLoader: () => Future<List<InstalledApp>>.error(Exception('boom')),
    );

    await provider.loadInstalledApps();

    expect(provider.isLoading, isFalse);
    expect(provider.apps, isEmpty);
    expect(provider.errorMessage, 'Unable to load installed apps.');
  });

  test('filters by app name and package name', () async {
    final provider = AppListProvider(appLoader: () async => [chrome, maps]);
    await provider.loadInstalledApps();

    provider.setSearchQuery('maps');

    expect(provider.filteredApps, [maps]);

    provider.setSearchQuery('android.chrome');

    expect(provider.filteredApps, [chrome]);
  });

  test('clears search query', () async {
    final provider = AppListProvider(appLoader: () async => [chrome]);
    await provider.loadInstalledApps();

    provider.setSearchQuery('chrome');
    provider.clearSearch();

    expect(provider.searchQuery, isEmpty);
    expect(provider.filteredApps, [chrome]);
  });

  test('refresh replaces the app list', () async {
    var calls = 0;
    final provider = AppListProvider(
      appLoader: () async {
        calls += 1;
        return calls == 1 ? [chrome] : [maps];
      },
    );

    await provider.loadInstalledApps();
    await provider.loadInstalledApps();

    expect(provider.apps, [maps]);
  });
}
