#!/usr/bin/env bash
# 빌드 → .app 번들 조립 → 실행을 한 번에
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Crowsnest"
BUNDLE_ID="com.ldhbenecia.crowsnest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$MODE" in
  run|--logs|--verify) CONFIGURATION=debug ;;
  --install) CONFIGURATION=release ;;
  *) echo "usage: $0 [run|--logs|--verify|--install]" >&2; exit 2 ;;
esac

APP_BUNDLE="$("$SCRIPT_DIR/bundle.sh" "$CONFIGURATION")"

# 빌드가 성공한 뒤에만 끔 — 실패하면 돌던 앱이 그대로 남음
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

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
