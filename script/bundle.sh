#!/usr/bin/env bash
# 빌드하고 dist/Crowsnest.app 으로 조립함 — build_and_run.sh · package.sh 가 같이 씀
# usage: script/bundle.sh [debug|release]
set -euo pipefail

CONFIGURATION="${1:-debug}"
APP_NAME="Crowsnest"
BUNDLE_ID="com.ldhbenecia.crowsnest"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION 파일은 0.1.0 같은 형식이어야 함: '$VERSION'" >&2
  exit 1
fi

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --product "$APP_NAME" >&2
BUILD_BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"

# 정보 창에 보여줄 값 — 커밋 안 된 변경(새 파일 포함)이 있으면 해시 뒤에 표시
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  COMMIT="$COMMIT-dirty"
  echo "경고: 커밋 안 된 변경이 있어서 버전에 -dirty 가 붙음" >&2
fi
BUILD_DATE="$(date '+%Y-%m-%d')"
# CFBundleVersion 은 빌드마다 올라가야 함 — 같은 값이면 macOS 가 예전 아이콘 · 알림 정보를 계속 씀
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat >"$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CrowsnestCommit</key><string>$COMMIT</string>
  <key>CrowsnestBuildDate</key><string>$BUILD_DATE</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# 알림 권한이 번들 ID 에 붙어서 ad-hoc 으로라도 서명해 둠 — Apple 개발자 계정이 없어서 공증은 못 함
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE" >&2

echo "$APP_BUNDLE"
