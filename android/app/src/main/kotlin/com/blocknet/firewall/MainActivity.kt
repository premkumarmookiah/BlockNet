package com.blocknet.firewall

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingVpnPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val installedAppsHelper = InstalledAppsHelper(
            packageManager = packageManager,
            ownPackageName = packageName,
        )
        val firewallPreferences = FirewallPreferences(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        backgroundExecutor.execute {
                            try {
                                val apps = installedAppsHelper.getInstalledApps()
                                mainHandler.post { result.success(apps) }
                            } catch (error: Exception) {
                                mainHandler.post {
                                    result.error(
                                        "INSTALLED_APPS_FAILED",
                                        error.message ?: "Unable to load installed apps.",
                                        null,
                                    )
                                }
                            }
                        }
                    }
                    "prepareVpn" -> prepareVpn(result)
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "startFirewall" -> startFirewall(result)
                    "stopFirewall" -> {
                        BasicFirewallVpnService.stop(this)
                        result.success(true)
                    }
                    "getFirewallStatus" -> {
                        val shouldBeRunning = firewallPreferences.isFirewallEnabled()
                        if (
                            shouldBeRunning &&
                            !FirewallRuntimeState.tracker.isRunning &&
                            VpnService.prepare(this) == null
                        ) {
                            BasicFirewallVpnService.start(this)
                        }
                        result.success(FirewallRuntimeState.tracker.isRunning || shouldBeRunning)
                    }
                    "getBlockedApps" -> {
                        val installedBlockedPackages = firewallPreferences
                            .getBlockedPackages()
                            .filter { installedAppsHelper.isLaunchablePackage(it) }
                            .toSet()
                        firewallPreferences.saveBlockedPackages(installedBlockedPackages)
                        result.success(installedBlockedPackages.toList())
                    }
                    "updateBlockedApps" -> updateBlockedApps(
                        result,
                        firewallPreferences,
                        call.argument<List<String>>("packageNames").orEmpty(),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        backgroundExecutor.shutdown()
        super.onDestroy()
    }

    @Deprecated("Deprecated Android callback is sufficient for this minimal Flutter bridge.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != VPN_PERMISSION_REQUEST_CODE) {
            return
        }

        pendingVpnPermissionResult?.success(resultCode == Activity.RESULT_OK)
        pendingVpnPermissionResult = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) {
            return
        }

        val isGranted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingNotificationPermissionResult?.success(isGranted)
        pendingNotificationPermissionResult = null
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        if (pendingVpnPermissionResult != null) {
            result.error(
                "VPN_PERMISSION_IN_PROGRESS",
                "A VPN permission request is already active.",
                null,
            )
            return
        }

        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent == null) {
            result.success(true)
            return
        }

        pendingVpnPermissionResult = result
        startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (pendingNotificationPermissionResult != null) {
            result.error(
                "NOTIFICATION_PERMISSION_IN_PROGRESS",
                "A notification permission request is already active.",
                null,
            )
            return
        }

        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun startFirewall(result: MethodChannel.Result) {
        if (VpnService.prepare(this) != null) {
            result.error(
                "VPN_PERMISSION_REQUIRED",
                "VPN permission must be granted before starting the firewall.",
                null,
            )
            return
        }

        try {
            BasicFirewallVpnService.start(this)
            result.success(true)
        } catch (error: Exception) {
            result.error(
                "FIREWALL_START_FAILED",
                error.message ?: "Unable to start firewall service.",
                null,
            )
        }
    }

    private fun updateBlockedApps(
        result: MethodChannel.Result,
        firewallPreferences: FirewallPreferences,
        packageNames: List<String>,
    ) {
        try {
            firewallPreferences.saveBlockedPackages(packageNames)
            if (FirewallRuntimeState.tracker.isRunning) {
                BasicFirewallVpnService.rebuild(this)
            }
            result.success(true)
        } catch (error: Exception) {
            result.error(
                "BLOCKED_APPS_UPDATE_FAILED",
                error.message ?: "Unable to update blocked applications.",
                null,
            )
        }
    }

    private companion object {
        const val CHANNEL_NAME = "blocknet/firewall"
        const val VPN_PERMISSION_REQUEST_CODE = 4101
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4102
    }
}
