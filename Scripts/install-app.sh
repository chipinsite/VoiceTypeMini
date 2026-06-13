#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${VOICE_TYPE_BUILD_ROOT:-/tmp/VoiceTypeMini-build}"
APP_PATH="/Applications/VoiceTypeMini.app"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

rsync -a --delete \
  --exclude '.build' \
  --exclude '.git' \
  "$ROOT_DIR/" "$BUILD_ROOT/"

cd "$BUILD_ROOT"
swift build --jobs 1

if [[ "${VOICE_TYPE_RUN_TESTS:-0}" == "1" ]]; then
  swift test --jobs 1
fi

pkill -x VoiceTypeMini 2>/dev/null || true
rm -rf /tmp/VoiceTypeMini.app
Scripts/build-app.sh --skip-build

rm -rf "$APP_PATH"
ditto --noextattr --noqtn /tmp/VoiceTypeMini.app "$APP_PATH"
codesign --verify --verbose=4 "$APP_PATH"

open "$APP_PATH"
pgrep -lf VoiceTypeMini || true
