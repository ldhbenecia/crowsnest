#!/usr/bin/env bash
# 직전 태그부터 이번 태그까지의 커밋을 종류별로 묶어 릴리스 노트(마크다운)를 stdout 으로 냄
# usage: script/release_notes.sh <태그 또는 커밋> [dmg 경로]
#   태그를 달기 전에 미리 보려면: script/release_notes.sh HEAD
set -euo pipefail

TARGET="${1:?usage: $0 <tag-or-commit> [dmg-path]}"
DMG="${2:-}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# 첫 릴리스면 직전 태그가 없어서 처음 커밋부터
PREVIOUS_TAG="$(git describe --tags --abbrev=0 --match 'v*' "$TARGET^" 2>/dev/null || true)"
RANGE="${PREVIOUS_TAG:+$PREVIOUS_TAG..}$TARGET"

# 사용자가 체감하는 것만 — chore · ci · docs · test · build · style 은 뺌
section() {
  local title="$1" pattern="$2"
  local lines
  lines="$(git log --reverse --format='%s' "$RANGE" | grep -E "^($pattern)(\([^)]*\))?!?: " | sed -E 's/^[a-z]+(\([^)]*\))?!?: /- /' || true)"
  if [[ -n "$lines" ]]; then
    printf '## %s\n\n%s\n\n' "$title" "$lines"
  fi
}

section "Features" "feat"
section "Fixes" "fix"
section "Performance" "perf"
section "Changes" "refactor"

if [[ -n "$DMG" ]]; then
  printf '## Download\n\n`%s` · SHA-256 `%s`\n\n' "$(basename "$DMG")" "$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
fi

cat <<'EOF'
## Install

Drag **Crowsnest** into **Applications**. The app is not notarized, so on first launch either allow it in **System Settings → Privacy & Security → Open Anyway**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Crowsnest.app
```
EOF

if [[ -n "$PREVIOUS_TAG" ]]; then
  REPOSITORY="${GITHUB_REPOSITORY:-$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')}"
  TAG_NAME="$(git describe --tags --exact-match "$TARGET" 2>/dev/null || echo "$TARGET")"
  printf '\n**Full changelog**: https://github.com/%s/compare/%s...%s\n' "$REPOSITORY" "$PREVIOUS_TAG" "$TAG_NAME"
fi
