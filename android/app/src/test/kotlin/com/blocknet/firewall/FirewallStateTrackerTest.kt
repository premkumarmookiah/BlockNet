package com.blocknet.firewall

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FirewallStateTrackerTest {
    @Test
    fun startsStopped() {
        val tracker = FirewallStateTracker()

        assertFalse(tracker.isRunning)
    }

    @Test
    fun marksRunningAndStopped() {
        val tracker = FirewallStateTracker()

        tracker.markRunning()
        assertTrue(tracker.isRunning)

        tracker.markStopped()
        assertFalse(tracker.isRunning)
    }

    @Test
    fun marksInterfaceEstablishedAndStopped() {
        val tracker = FirewallStateTracker()

        tracker.markInterfaceEstablished()
        assertTrue(tracker.isRunning)
        assertTrue(tracker.isInterfaceEstablished)

        tracker.markStopped()
        assertFalse(tracker.isRunning)
        assertFalse(tracker.isInterfaceEstablished)
    }
}
