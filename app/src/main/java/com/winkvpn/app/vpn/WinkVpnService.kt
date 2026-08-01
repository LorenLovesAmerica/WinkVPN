package com.winkvpn.app.vpn

import android.net.VpnService
import android.content.Intent
import android.os.ParcelFileDescriptor

/**
 * ЗАГОТОВКА VPN-СЕРВИСА. Это НЕ рабочий VPN — только скелет с правильной
 * архитектурой Android VpnService, чтобы приложение уже сейчас могло
 * корректно запросить у системы разрешение на VPN-соединения.
 *
 * Что нужно добавить для реальной работы: зависимость WireGuard SDK,
 * конфиг сервера (публичный ключ, endpoint, allowed IPs) с бэкенда,
 * Builder().addAddress(...).addRoute(...).establish() — создание TUN-интерфейса.
 */
class WinkVpnService : VpnService() {

    private var tunInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // TODO: здесь будет реальная установка туннеля через Builder(), когда подключим WireGuard
        return START_STICKY
    }

    override fun onDestroy() {
        tunInterface?.close()
        tunInterface = null
        super.onDestroy()
    }

    override fun onRevoke() {
        tunInterface?.close()
        stopSelf()
    }
}

