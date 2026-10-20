#!/usr/bin/env bash
# release 빌드 → dist/Crowsnest-<버전>.dmg (Applications 바로가기 포함)
# 태그 · GitHub 릴리스는 손으로: git tag v<버전> → gh release create v<버전> dist/Crowsnest-<버전>.dmg
set -euo pipefail

APP_NAME="Crowsnest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
DMG="$ROOT_DIR/dist/$APP_NAME-$VERSION.dmg"

cd "$ROOT_DIR"
if ! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
  echo "경고: v$VERSION 태그가 없음 — 릴리스할 거면 git tag v$VERSION" >&2
fi

APP_BUNDLE="$("$SCRIPT_DIR/bundle.sh" release)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -fs APFS -format UDZO -ov "$DMG" >/dev/null

echo "만듦: $DMG"
# Homebrew cask 를 만들 때 쓰는 값
echo "sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
