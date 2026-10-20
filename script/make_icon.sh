#!/usr/bin/env bash
# Resources/AppIcon.icns 를 다시 만듦 — 글리프나 색을 바꿨을 때만 돌리면 됨
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$ROOT_DIR"
swift run -c release IconRenderer "$WORK_DIR/AppIcon.iconset"
mkdir -p Resources
iconutil -c icns "$WORK_DIR/AppIcon.iconset" -o Resources/AppIcon.icns
# GitHub 은 .icns 를 못 보여줘서 README 용 PNG 도 둠
mkdir -p docs/images
cp "$WORK_DIR/AppIcon.iconset/icon_128x128@2x.png" docs/images/icon.png
echo "만듦: Resources/AppIcon.icns · docs/images/icon.png"
