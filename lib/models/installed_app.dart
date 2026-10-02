class InstalledApp {
  const InstalledApp({
    required this.name,
    required this.packageName,
    this.iconBase64,
  });

  final String name;
  final String packageName;
  final String? iconBase64;

  factory InstalledApp.fromMap(Map<String, Object?> map) {
    final name = map['name'];
    final packageName = map['packageName'];
    final iconBase64 = map['iconBase64'];

    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Installed app name is missing.');
    }
    if (packageName is! String || packageName.trim().isEmpty) {
      throw const FormatException('Installed app package name is missing.');
    }
    if (iconBase64 != null && iconBase64 is! String) {
      throw const FormatException('Installed app icon must be a string.');
    }

    return InstalledApp(
      name: name,
      packageName: packageName,
      iconBase64: iconBase64 as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {'name': name, 'packageName': packageName, 'iconBase64': iconBase64};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstalledApp &&
            other.name == name &&
            other.packageName == packageName &&
            other.iconBase64 == iconBase64;
  }

  @override
  int get hashCode => Object.hash(name, packageName, iconBase64);
}
