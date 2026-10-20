#!/usr/bin/env bash
# Xcode 없이 Command Line Tools 만 있으면 swift-testing 이 검색 경로에 안 잡혀서 직접 넘김
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

DEVELOPER_DIR="$(xcode-select -p)"
FRAMEWORKS="$DEVELOPER_DIR/Library/Developer/Frameworks"
LIBRARIES="$DEVELOPER_DIR/Library/Developer/usr/lib"

if [[ "$DEVELOPER_DIR" == *CommandLineTools* && -d "$FRAMEWORKS/Testing.framework" ]]; then
  exec swift test \
    -Xswiftc -F"$FRAMEWORKS" \
    -Xlinker -F"$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$LIBRARIES" \
    "$@"
fi

exec swift test "$@"
