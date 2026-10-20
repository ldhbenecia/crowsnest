#!/usr/bin/env bash
# README 스크린샷을 docs/images 에 다시 만듦 — 실제 뷰를 예시 데이터로 그림
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/docs/images"
CROWSNEST_SCREENSHOT_DIRECTORY="$ROOT_DIR/docs/images" "$ROOT_DIR/script/test.sh" --filter ScreenshotTests
ls "$ROOT_DIR/docs/images"
