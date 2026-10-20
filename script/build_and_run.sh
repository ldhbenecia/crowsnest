#!/usr/bin/env bash
# 빌드 → .app 번들 조립 → 실행을 한 번에
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Crowsnest"
BUNDLE_ID="com.ldhbenecia.crowsnest"
MIN_SYSTEM_VERSION="14.0"
VERSION="0.1.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"

case "$MODE" in
  run|--logs|--verify) CONFIGURATION=debug ;;
  --install) CONFIGURATION=release ;;
  *) echo "usage: $0 [run|--logs|--verify|--install]" >&2; exit 2 ;;
esac

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" --product "$APP_NAME"
BUILD_BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"

# 빌드가 성공한 뒤에만 끔 — 실패하면 돌던 앱이 그대로 남음
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat >"$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# 알림 권한이 번들 ID 에 붙어서 ad-hoc 으로라도 서명해 둠
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE" >/dev/null

case "$MODE" in
  run)
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  --logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null && echo "실행 중 (pid $(pgrep -x "$APP_NAME"))"
    ;;
  --install)
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" /Applications/
    /usr/bin/open -n "/Applications/$APP_NAME.app"
    echo "설치됨: /Applications/$APP_NAME.app"
    ;;
esac
