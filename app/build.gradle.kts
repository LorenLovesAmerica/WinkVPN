import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.winkvpn.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.winkvpn.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.2.0-alpha"
    }

    buildFeatures {
        compose = true
    }

    // ПРИМЕЧАНИЕ: начиная с Kotlin 2.0, компилятор Compose — отдельный плагин
    // (org.jetbrains.kotlin.plugin.compose, подключён выше), поэтому старый
    // блок composeOptions { kotlinCompilerExtensionVersion = ... } больше не нужен.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

// Начиная с новых версий Kotlin Gradle Plugin, старый синтаксис
// `kotlinOptions { jvmTarget = "17" }` внутри android{} стал ошибкой —
// теперь настройки компилятора Kotlin задаются отдельным top-level блоком.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.1")

    // ── Supabase (база данных + авторизация) ──
    implementation(platform("io.github.jan-tennert.supabase:bom:3.7.0"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.ktor:ktor-client-okhttp:3.5.0")
    implementation("io.ktor:ktor-client-core:3.5.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // ── Google Sign-In через современный Credential Manager API ──
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    // Куда позже добавим:
    // implementation("com.wireguard.android:tunnel:1.0.20230706") // реальный WireGuard туннель
}

