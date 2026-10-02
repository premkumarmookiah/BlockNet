package com.blocknet.firewall

class FirewallStateTracker {
    @Volatile
    var isRunning: Boolean = false
        private set

    @Volatile
    var isInterfaceEstablished: Boolean = false
        private set

    fun markRunning() {
        isRunning = true
    }

    fun markInterfaceEstablished() {
        isInterfaceEstablished = true
        markRunning()
    }

    fun markStopped() {
        isRunning = false
        isInterfaceEstablished = false
    }
}

object FirewallRuntimeState {
    val tracker = FirewallStateTracker()
}
