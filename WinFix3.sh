#!/usr/bin/env bash
# WinFix3.sh — фикс: gradle-version в workflow YAML был БЕЗ кавычек, поэтому
# "8.10" парсилось как число 8.10 == 8.1 (незначащий ноль отбрасывается),
# и реально ставился Gradle 8.1 вместо 8.10. Теперь версия в кавычках как строка.
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

      - name: Set up Android SDK
        uses: android-actions/setup-android@v3

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@v3
        with:
          gradle-version: "8.10"

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
echo "Дальше: git add -A && git commit -m fix_gradle_yaml && git push"
