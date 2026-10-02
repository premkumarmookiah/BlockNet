package com.blocknet.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FirewallVpnConfigTest {
    @Test
    fun defaultConfigKeepsTrafficRoutingDisabledWhenNothingIsBlocked() {
        val config = FirewallVpnConfig()

        assertEquals("BlockNet", config.sessionName)
        assertEquals("10.8.0.2", config.ipv4Address)
        assertEquals(32, config.ipv4PrefixLength)
        assertEquals(1500, config.mtu)
        assertFalse(config.isTrafficRoutingEnabled)
    }

    @Test
    fun enablesTrafficRoutingWhenAppsAreBlocked() {
        val config = FirewallVpnConfig(
            blockedPackageNames = setOf("com.example.target"),
        )

        assertEquals(setOf("com.example.target"), config.blockedPackageNames)
        assertTrue(config.isTrafficRoutingEnabled)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidPrefix() {
        FirewallVpnConfig(ipv4PrefixLength = 33)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidMtu() {
        FirewallVpnConfig(mtu = 100)
    }
}
