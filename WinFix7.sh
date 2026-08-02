#!/usr/bin/env bash
# WinFix7.sh — создаёт debug.keystore ДО сборки (явной командой), чтобы:
# 1) сборка гарантированно подписывала APK именно этим ключом
# 2) финальный SHA-1 в конце лога реально совпадал с тем, чем подписан APK
set -e
echo "Обновляю workflow..."
mkdir -p ".github/workflows"
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

      - name: Ensure debug keystore exists
        run: |
          mkdir -p ~/.android
          if [ ! -f ~/.android/debug.keystore ]; then
            keytool -genkeypair -v -keystore ~/.android/debug.keystore \
              -storepass android -alias androiddebugkey -keypass android \
              -dname "CN=Android Debug,O=Android,C=US" \
              -validity 10950 -keyalg RSA -keysize 2048
          fi

      - name: Set up Android SDK
        uses: android-actions/setup-android@v3

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@v3
        with:
          gradle-version: "8.14.4"

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
echo "Дальше: git add -A && git commit -m fix_keystore && git push"
