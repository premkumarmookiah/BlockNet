package com.blocknet.firewall

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

class InstalledAppsHelper(
    private val packageManager: PackageManager,
    private val ownPackageName: String,
) {
    private val iconCache = ConcurrentHashMap<String, String?>()

    fun getInstalledApps(): List<Map<String, String?>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val launchableActivities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }

        return launchableActivities
            .mapNotNull { resolveInfo ->
                val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
                val appInfo = activityInfo.applicationInfo ?: return@mapNotNull null
                val packageName = activityInfo.packageName ?: return@mapNotNull null

                if (packageName == ownPackageName || isSystemOnlyApp(appInfo)) {
                    return@mapNotNull null
                }

                mapOf(
                    "name" to resolveInfo.loadLabel(packageManager).toString(),
                    "packageName" to packageName,
                    "iconBase64" to iconCache.getOrPut(packageName) {
                        iconToBase64(resolveInfo.loadIcon(packageManager))
                    },
                )
            }
            .distinctBy { it["packageName"] }
            .sortedWith(
                compareBy<Map<String, String?>> {
                    it["name"]?.lowercase(Locale.getDefault()).orEmpty()
                }.thenBy { it["packageName"].orEmpty() },
            )
    }

    fun isLaunchablePackage(packageName: String): Boolean {
        if (packageName == ownPackageName) {
            return false
        }
        return packageManager.getLaunchIntentForPackage(packageName) != null
    }

    private fun isSystemOnlyApp(appInfo: ApplicationInfo): Boolean {
        val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        val isUpdatedSystemApp = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        return isSystem && !isUpdatedSystemApp
    }

    private fun iconToBase64(drawable: Drawable?): String? {
        if (drawable == null) {
            return null
        }

        return try {
            val bitmap = drawableToBitmap(drawable)
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return Bitmap.createScaledBitmap(drawable.bitmap, ICON_SIZE_PX, ICON_SIZE_PX, true)
        }

        val bitmap = Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private companion object {
        const val ICON_SIZE_PX = 48
    }
}
