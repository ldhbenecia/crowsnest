#!/usr/bin/env bash
# Resources/AppIcon.icns 와 dmg 창 배경을 다시 만듦 — 글리프 · 색 · dmg 배치를 바꿨을 때만 돌리면 됨
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$ROOT_DIR"
swift run -c release IconRenderer "$WORK_DIR/AppIcon.iconset" "$WORK_DIR/dmg"
mkdir -p Resources
iconutil -c icns "$WORK_DIR/AppIcon.iconset" -o Resources/AppIcon.icns
# 1x · 2x 를 한 tiff 에 넣어야 Finder 가 레티나에서 선명한 쪽을 고름
tiffutil -cathidpicheck "$WORK_DIR/dmg/background.png" "$WORK_DIR/dmg/background@2x.png" -out Resources/dmg-background.tiff
# GitHub 은 .icns 를 못 보여줘서 README 용 PNG 도 둠
mkdir -p docs/images
cp "$WORK_DIR/AppIcon.iconset/icon_128x128@2x.png" docs/images/icon.png
echo "만듦: Resources/AppIcon.icns · Resources/dmg-background.tiff · docs/images/icon.png"
