#!/usr/bin/env bash
# WinFix4.sh — берём официальную таблицу совместимости AGP 8.13.0:
# AGP 8.5.0 -> 8.13.0, compileSdk/targetSdk -> 36, Gradle -> 8.13.
# Это стабильная версия AGP 8.x (не 9.x, где ломается старый DSL).
set -e
echo "Обновляю файлы..."

mkdir -p ".github/workflows"
mkdir -p "app"
mkdir -p "gradle/wrapper"

cat > "build.gradle.kts" << 'WINKVPN_EOF'
// Top-level build file
plugins {
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "1.9.24" apply false
}

WINKVPN_EOF

cat > "app/build.gradle.kts" << 'WINKVPN_EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
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

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

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
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
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

cat > "gradle/wrapper/gradle-wrapper.properties" << 'WINKVPN_EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists

WINKVPN_EOF

cat > ".github/workflows/android-build.yml" << 'WINKVPN_EOF'
name: Build Android APK

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Android SDK
        uses: android-actions/setup-android@v3

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@v3
        with:
          gradle-version: "8.13"

      - name: Build debug APK
        run: gradle assembleDebug --no-daemon

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: wink-vpn-debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk

      - name: Print debug SHA-1 fingerprint
        run: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

WINKVPN_EOF

echo "Готово!"
echo "Дальше: git add -A && git commit -m fix_agp_8_13 && git push"