package com.blocknet.firewall

import android.content.Context

class FirewallPreferences(context: Context) {
    private val ownPackageName = context.packageName
    private val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun getBlockedPackages(): Set<String> {
        return normalizeBlockedPackages(
            preferences.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()).orEmpty(),
            ownPackageName,
        )
    }

    fun saveBlockedPackages(packageNames: Collection<String>): Set<String> {
        val normalizedPackages = normalizeBlockedPackages(packageNames, ownPackageName)
        preferences.edit()
            .putStringSet(KEY_BLOCKED_PACKAGES, normalizedPackages)
            .apply()
        return normalizedPackages
    }

    fun isFirewallEnabled(): Boolean {
        return preferences.getBoolean(KEY_FIREWALL_ENABLED, false)
    }

    fun saveFirewallEnabled(isEnabled: Boolean) {
        preferences.edit()
            .putBoolean(KEY_FIREWALL_ENABLED, isEnabled)
            .apply()
    }

    companion object {
        private const val PREFERENCES_NAME = "blocknet_firewall"
        private const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        private const val KEY_FIREWALL_ENABLED = "firewall_enabled"
        private val PACKAGE_NAME_PATTERN = Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")

        fun normalizeBlockedPackages(
            packageNames: Collection<String>,
            ownPackageName: String,
        ): Set<String> {
            return packageNames
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .filter { it != ownPackageName }
                .filter { PACKAGE_NAME_PATTERN.matches(it) }
                .toSortedSet()
        }
    }
}
