#!/usr/bin/env bash
# release 빌드 → dist/Crowsnest-<버전>.dmg (Applications 바로가기 포함), 터미널 설치용 dist/Crowsnest.zip, 각각의 .sha256
# 실제 릴리스는 v<버전> 태그를 push 하면 .github/workflows/release.yml 이 이걸 돌려서 올림
set -euo pipefail

APP_NAME="Crowsnest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
DMG="$ROOT_DIR/dist/$APP_NAME-$VERSION.dmg"
# 버전 없는 이름 — releases/latest/download/Crowsnest.zip 주소가 늘 최신을 가리키게
ZIP="$ROOT_DIR/dist/$APP_NAME.zip"

cd "$ROOT_DIR"
if ! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
  echo "경고: v$VERSION 태그가 없음 — 릴리스할 거면 git tag v$VERSION" >&2
fi

APP_BUNDLE="$("$SCRIPT_DIR/bundle.sh" release)"

# dmg 창 배치는 dmgbuild 로 — 버전을 고정해서 .build 아래 가상환경에 한 번만 깔아 둠
DMGBUILD_ENV="$ROOT_DIR/.build/dmgbuild-venv"
if [[ ! -x "$DMGBUILD_ENV/bin/dmgbuild" ]]; then
  python3 -m venv "$DMGBUILD_ENV"
  "$DMGBUILD_ENV/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.5"
fi

rm -f "$DMG"
"$DMGBUILD_ENV/bin/dmgbuild" \
  -s "$SCRIPT_DIR/dmg_settings.py" \
  -D app="$APP_BUNDLE" \
  -D background="$ROOT_DIR/Resources/dmg-background.tiff" \
  "$APP_NAME $VERSION" "$DMG" >/dev/null

# curl 로 받아 ditto 로 풀면 격리 표시가 안 붙어서 공증 경고 없이 바로 열림
rm -f "$ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"

# 받은 사람이 shasum -c 로 확인할 수 있게 파일 이름만 적음
for file in "$DMG" "$ZIP"; do
  (cd "$(dirname "$file")" && shasum -a 256 "$(basename "$file")" >"$(basename "$file").sha256")
  echo "만듦: $file"
  echo "만듦: $file.sha256"
done
