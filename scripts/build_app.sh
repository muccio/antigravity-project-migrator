#!/usr/bin/env bash
set -e

APP_NAME="Antigravity Migrator"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="build"

echo "🔨 Preparazione bundle per ${APP_NAME}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "📄 Copia risorse (Info.plist e Icona)..."
cp src/Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
if [ -f src/Resources/AppIcon.icns ]; then
    cp src/Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "🚀 Compilazione sorgenti Swift in corso con swiftc..."
SWIFT_FILES=$(find src -name "*.swift")

swiftc -O \
    -parse-as-library \
    -target arm64-apple-macos12.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    -lsqlite3 \
    ${SWIFT_FILES} \
    -o "${APP_BUNDLE}/Contents/MacOS/AntigravityMigrator"

echo "🔏 Applicazione firma ad-hoc macOS..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Compilazione completata con successo!"
echo "📍 Applicazione standalone creata in: $(pwd)/${APP_BUNDLE}"
