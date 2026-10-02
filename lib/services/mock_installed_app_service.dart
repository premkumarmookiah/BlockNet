import '../models/installed_app.dart';

class MockInstalledAppService {
  Future<List<InstalledApp>> getInstalledApps() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return const [
      InstalledApp(name: 'Chrome', packageName: 'com.android.chrome'),
      InstalledApp(name: 'Maps', packageName: 'com.google.android.apps.maps'),
      InstalledApp(
        name: 'Messages',
        packageName: 'com.google.android.apps.messaging',
      ),
      InstalledApp(
        name: 'Photos',
        packageName: 'com.google.android.apps.photos',
      ),
      InstalledApp(name: 'YouTube', packageName: 'com.google.android.youtube'),
    ];
  }
}
