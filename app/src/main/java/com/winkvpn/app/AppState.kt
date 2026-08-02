package com.winkvpn.app

enum class Screen { SPLASH, WELCOME, TELEGRAM, TELEGRAM_THANKS, THANKS, MAIN, PROFILE }

enum class AppLanguage { RU, EN }

data class VpnServer(
    val flag: String,
    val name: String,
    val ping: String,
    val ipPrefix: String,
    val speed: String
)

// Пока только одна честная рабочая локация — Германия.
// Остальные страны уберём из выбора, пока не поднимем для них отдельные серверы.
val servers = listOf(
    VpnServer("🇩🇪", "Германия", "11 мс", "185.220.10.", "92"),
)

