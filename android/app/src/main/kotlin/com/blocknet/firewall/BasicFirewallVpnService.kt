package com.blocknet.firewall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

class BasicFirewallVpnService : VpnService() {
    private val isPacketLoopRunning = AtomicBoolean(false)
    private var tunInterface: ParcelFileDescriptor? = null
    private var packetLoopThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopFirewallService()
                return START_NOT_STICKY
            }
            ACTION_REBUILD -> {
                rebuildFirewallService()
                return START_STICKY
            }
        }

        startFirewallService()
        return START_STICKY
    }

    override fun onDestroy() {
        cleanupVpnInterface()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (FirewallRuntimeState.tracker.isRunning) {
            FirewallPreferences(this).saveFirewallEnabled(true)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onRevoke() {
        FirewallPreferences(this).saveFirewallEnabled(false)
        cleanupVpnInterface()
        stopSelf()
        super.onRevoke()
    }

    private fun startFirewallService() {
        if (FirewallRuntimeState.tracker.isInterfaceEstablished) {
            return
        }

        createNotificationChannel()
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        tunInterface = establishVpnInterface()
        startPacketLoop(tunInterface)
        FirewallRuntimeState.tracker.markInterfaceEstablished()
        FirewallPreferences(this).saveFirewallEnabled(true)
    }

    private fun stopFirewallService() {
        FirewallPreferences(this).saveFirewallEnabled(false)
        cleanupVpnInterface()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun rebuildFirewallService() {
        cleanupVpnInterface()
        startFirewallService()
    }

    private fun establishVpnInterface(): ParcelFileDescriptor {
        val firewallPreferences = FirewallPreferences(this)
        val config = FirewallVpnConfig(
            blockedPackageNames = firewallPreferences.getBlockedPackages(),
        )
        val builder = Builder()
            .setSession(config.sessionName)
            .setMtu(config.mtu)
            .addAddress(config.ipv4Address, config.ipv4PrefixLength)
            // establish() is non-blocking by default. A blocking descriptor lets
            // the packet thread sleep while no blocked traffic is available.
            .setBlocking(true)

        val routedPackages = addBlockedAppsToVpn(builder, config.blockedPackageNames)
        if (routedPackages.isNotEmpty()) {
            builder.addRoute("0.0.0.0", 0)
        }
        if (routedPackages.size != config.blockedPackageNames.size) {
            firewallPreferences.saveBlockedPackages(routedPackages)
        }

        val vpnInterface = builder.establish()
        requireNotNull(vpnInterface) { "Android did not establish the VPN interface." }
        return vpnInterface
    }

    private fun addBlockedAppsToVpn(
        builder: Builder,
        blockedPackageNames: Set<String>,
    ): Set<String> {
        val routedPackages = linkedSetOf<String>()
        for (packageName in blockedPackageNames) {
            try {
                builder.addAllowedApplication(packageName)
                routedPackages.add(packageName)
            } catch (_: PackageManager.NameNotFoundException) {
                // The app was uninstalled after being blocked. Remove it from
                // persistence on the next save so service rebuilds stay healthy.
            }
        }
        return routedPackages
    }

    private fun startPacketLoop(vpnInterface: ParcelFileDescriptor?) {
        if (vpnInterface == null || isPacketLoopRunning.getAndSet(true)) {
            return
        }

        packetLoopThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            val buffer = ByteArray(PACKET_BUFFER_SIZE)

            try {
                FileInputStream(vpnInterface.fileDescriptor).use { input ->
                    while (isPacketLoopRunning.get()) {
                        val bytesRead = input.read(buffer)
                        if (bytesRead < 0) {
                            break
                        }
                        // Phase 4 has no forwarding engine. Packets are dropped
                        // deliberately if anything is routed here.
                    }
                }
            } catch (_: IOException) {
                // Closing the VPN descriptor during stop is expected to unblock reads.
            } finally {
                isPacketLoopRunning.set(false)
            }
        }, PACKET_THREAD_NAME).apply {
            isDaemon = true
            start()
        }
    }

    private fun cleanupVpnInterface() {
        isPacketLoopRunning.set(false)
        packetLoopThread?.interrupt()
        packetLoopThread = null

        try {
            tunInterface?.close()
        } catch (_: IOException) {
            // Nothing useful to do during service cleanup.
        } finally {
            tunInterface = null
            FirewallRuntimeState.tracker.markStopped()
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("BlockNet active")
            .setContentText("Blocked apps are routed through the local firewall.")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Firewall status",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows when the local firewall VPN service is running."
            setShowBadge(false)
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        private const val ACTION_START = "com.blocknet.firewall.START_FIREWALL"
        private const val ACTION_STOP = "com.blocknet.firewall.STOP_FIREWALL"
        private const val ACTION_REBUILD = "com.blocknet.firewall.REBUILD_FIREWALL"
        private const val NOTIFICATION_CHANNEL_ID = "blocknet_status"
        private const val NOTIFICATION_ID = 1001
        private const val PACKET_BUFFER_SIZE = 32_767
        private const val PACKET_THREAD_NAME = "BlockNetPacketLoop"

        fun start(context: Context) {
            FirewallPreferences(context).saveFirewallEnabled(true)
            val intent = Intent(context, BasicFirewallVpnService::class.java).apply {
                action = ACTION_START
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            FirewallPreferences(context).saveFirewallEnabled(false)
            val intent = Intent(context, BasicFirewallVpnService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun rebuild(context: Context) {
            val intent = Intent(context, BasicFirewallVpnService::class.java).apply {
                action = ACTION_REBUILD
            }
            context.startService(intent)
        }
    }
}
