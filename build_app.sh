#
//  build_app.sh
//  SitReminder
//
//  Created by Hu Gang on 2025/5/6.
//


#!/bin/bash

set -e

APP_NAME="SitReminder"
SCHEME="SitReminder"
CONFIGURATION="Release"
PROJECT="SitReminder.xcodeproj"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
EXPORT_OPTIONS_PLIST="ExportOptions.plist"
DMG_NAME="${APP_NAME}.dmg"

echo "🧹 清理旧构建..."
rm -rf build

echo "🏗️ 开始归档..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination 'generic/platform=macOS' \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "📦 导出 .app..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

echo "💿 打包为 .dmg..."
create-dmg \
  --volname "SitReminder" \
  --window-size 1000 700 \
  --background "background.png" \
  --icon-size 128 \
  --icon "SitReminder.app" 280 400 \
  --app-drop-link 640 400 \
  "SitReminder.dmg" \
  "build/export/"

echo "✅ 打包完成: ${DMG_NAME}"
