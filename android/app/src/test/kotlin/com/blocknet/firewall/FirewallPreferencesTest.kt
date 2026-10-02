package com.blocknet.firewall

import org.junit.Assert.assertEquals
import org.junit.Test

class FirewallPreferencesTest {
    @Test
    fun normalizesBlockedPackages() {
        val normalized = FirewallPreferences.normalizeBlockedPackages(
            listOf(
                " com.example.one ",
                "com.example.one",
                "not valid",
                "com.blocknet.firewall",
                "org.example.two",
            ),
            ownPackageName = "com.blocknet.firewall",
        )

        assertEquals(setOf("com.example.one", "org.example.two"), normalized)
    }
}
