#!/usr/bin/env bash
# WinFix5.sh — транзитивная зависимость притащила Kotlin stdlib 2.4.0,
# а наш компилятор Kotlin 1.9.24 её не читает. Поднимаю Kotlin до 2.4.10
# и добавляю новый обязательный плагин Compose-компилятора
# (с Kotlin 2.0+ он больше не встроен в AGP, а идёт отдельным плагином).
set -e
echo "Обновляю файлы..."
mkdir -p "app"

cat > "build.gradle.kts" << 'WINKVPN_EOF'
// Top-level build file
plugins {
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.4.10" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.10" apply false
}

WINKVPN_EOF

cat > "app/build.gradle.kts" << 'WINKVPN_EOF'
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
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
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

    // ── Google Sign-In через современный Credential Manager API ──
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    // Куда позже добавим:
    // implementation("com.wireguard.android:tunnel:1.0.20230706") // реальный WireGuard туннель
}

WINKVPN_EOF

echo "Готово!"
echo "Дальше: git add -A && git commit -m fix_kotlin_2_4 && git push"