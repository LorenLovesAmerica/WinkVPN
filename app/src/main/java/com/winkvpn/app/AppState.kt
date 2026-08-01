package com.winkvpn.app

enum class Screen { SPLASH, WELCOME, TELEGRAM, TELEGRAM_THANKS, THANKS, MAIN }

data class VpnServer(
    val flag: String,
    val name: String,
    val ping: String,
    val ipPrefix: String,
    val speed: String
)

val servers = listOf(
    VpnServer("🇩🇪", "Германия", "11 мс", "185.220.10.", "92"),
    VpnServer("🇳🇱", "Нидерланды", "9 мс", "194.165.22.", "105"),
    VpnServer("🇫🇮", "Финляндия", "14 мс", "37.120.48.", "78"),
    VpnServer("🇸🇪", "Швеция", "13 мс", "46.166.18.", "88"),
)

