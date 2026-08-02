package com.winkvpn.app.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.Serializable

@Serializable
data class Profile(
    val id: String,
    val user_number: Long = 0,
    val email: String? = null,
    val nickname: String? = null,
    val language: String = "ru"
)

object ProfileRepository {

    /** Достаёт профиль текущего вошедшего пользователя (строка уже создана
     * автоматически триггером в Supabase в момент первой регистрации). */
    suspend fun fetchCurrentProfile(): Profile? {
        val userId = SupabaseClientProvider.client.auth.currentUserOrNull()?.id ?: return null
        return SupabaseClientProvider.client.from("profiles")
            .select {
                filter { eq("id", userId) }
            }
            .decodeSingleOrNull<Profile>()
    }

    suspend fun updateNickname(nickname: String) {
        val userId = SupabaseClientProvider.client.auth.currentUserOrNull()?.id ?: return
        SupabaseClientProvider.client.from("profiles").update(
            { set("nickname", nickname) }
        ) {
            filter { eq("id", userId) }
        }
    }

    suspend fun updateLanguage(language: String) {
        val userId = SupabaseClientProvider.client.auth.currentUserOrNull()?.id ?: return
        SupabaseClientProvider.client.from("profiles").update(
            { set("language", language) }
        ) {
            filter { eq("id", userId) }
        }
    }
}

