package com.blocknet.firewall

data class FirewallVpnConfig(
    val sessionName: String = "BlockNet",
    val ipv4Address: String = "10.8.0.2",
    val ipv4PrefixLength: Int = 32,
    val mtu: Int = 1500,
    val blockedPackageNames: Set<String> = emptySet(),
) {
    val isTrafficRoutingEnabled: Boolean
        get() = blockedPackageNames.isNotEmpty()

    init {
        require(sessionName.isNotBlank()) { "Session name cannot be blank." }
        require(ipv4Address.isNotBlank()) { "IPv4 address cannot be blank." }
        require(ipv4PrefixLength in 0..32) { "IPv4 prefix must be between 0 and 32." }
        require(mtu in 1280..10_000) { "MTU must be in a practical VPN range." }
    }
}
