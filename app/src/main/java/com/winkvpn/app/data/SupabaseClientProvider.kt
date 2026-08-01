package com.winkvpn.app.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest

/**
 * Единая точка входа в Supabase — база данных + авторизация.
 * URL и anon-ключ безопасны для встраивания в клиентский код: это ПУБЛИЧНЫЕ
 * ключи, специально предназначенные для использования в приложениях, доступ
 * к данным всё равно регулируется правилами Row Level Security на стороне
 * самого Supabase. Секретный service_role ключ сюда никогда не должен попадать.
 */
object SupabaseClientProvider {

    val client = createSupabaseClient(
        supabaseUrl = "https://zzriuszuflbuwtbpmtob.supabase.co",
        supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6cml1c3p1ZmxidXd0YnBtdG9iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1NDM1ODgsImV4cCI6MjEwMTExOTU4OH0.r7iV4Y3huYX0PywOFIuXoLrExuomFaeb5GVDtaasF3g"
    ) {
        install(Auth)
        install(Postgrest)
    }
}

