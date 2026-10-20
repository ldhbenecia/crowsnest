#!/usr/bin/env bash
# release 빌드 → dist/Crowsnest-<버전>.dmg (Applications 바로가기 포함) 와 .sha256
# 실제 릴리스는 v<버전> 태그를 push 하면 .github/workflows/release.yml 이 이걸 돌려서 올림
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

# 받은 사람이 shasum -c 로 확인할 수 있게 파일 이름만 적음 · Homebrew cask 에도 이 값을 씀
(cd "$(dirname "$DMG")" && shasum -a 256 "$(basename "$DMG")" >"$(basename "$DMG").sha256")

echo "만듦: $DMG"
echo "만듦: $DMG.sha256"
