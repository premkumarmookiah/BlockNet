# BlockNet

BlockNet is an Android-only Flutter app that uses Android `VpnService` to block internet access for selected installed apps without root.

## Current Capability

- Lists launchable user apps with icon, name, and package name.
- Searches installed apps.
- Filters the list by `All`, `Blocked`, and `Allowed`.
- Persists blocked package selections locally.
- Starts a foreground Android VPN service.
- Routes blocked apps through the local VPN and drops their IPv4 traffic.
- Keeps non-blocked apps outside the VPN so their internet continues to work.
- Restores status and blocked selections when the app is reopened.
- Keeps blocking active when the app is removed from recents, as long as Android does not force-stop the app.

## Known Limitations

- IPv4 blocking is implemented first.
- IPv6 blocking is not implemented yet. Full IPv6 support needs IPv6 VPN address/route handling and real-device validation to avoid bypasses.
- If the user force-stops BlockNet from Android settings, Android prevents the service from running until the app is opened again.
- Maestro UI flows verify interaction only. They do not prove real network blocking.

## Test Commands

From the project root:

```sh
flutter analyze
flutter test
flutter test --coverage
flutter build apk --debug
cd android && ./gradlew testDebugUnitTest
```

## Install Debug APK

```sh
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The Android application id is:

```text
com.blocknet.firewall
```

## Maestro

Maestro flows live in `maestro/flows`.

From the project root:

```sh
maestro test maestro/flows/launch_app.yaml
maestro test maestro/flows/search_apps.yaml
maestro test maestro/flows/firewall_toggle.yaml
maestro test maestro/flows/block_app.yaml
maestro test maestro/flows/unblock_app.yaml
maestro test maestro/flows/persistence.yaml
```

From the `android/` folder, prefix paths with `../`:

```sh
maestro test ../maestro/flows/search_apps.yaml
```

## Real-Device Network Validation

Use a physical Android device for actual firewall validation.

1. Firewall OFF: verify Chrome and the target app both have internet.
2. Block one target app in BlockNet.
3. Turn firewall ON and accept notification/VPN prompts.
4. Verify the blocked target app cannot access internet.
5. Verify a non-blocked app, such as Chrome, still has internet.
6. Unblock the target app while firewall remains ON.
7. Verify the target app’s internet works again.
8. Block two apps and verify both fail while non-blocked apps still work.
9. Remove BlockNet from recents and verify the notification/VPN remain active.
10. Tap the notification and verify BlockNet opens normally.
11. Turn firewall OFF and verify all apps have normal internet.

## Performance Notes

- Installed app scans run on a native background executor.
- App icons are cached and resized before being sent to Flutter.
- BlockNet does not use wake locks.
- The VPN packet loop blocks on reads and does not spin/poll.
- Blocked-app updates rebuild the VPN only when the firewall is running.
