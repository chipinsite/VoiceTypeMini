#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${VOICE_TYPE_APP_DIR:-/tmp/VoiceTypeMini.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SKIP_BUILD="${1:-}"

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "--skip-build" ]]; then
  swift build
fi

BUILD_DIR="${VOICE_TYPE_BUILD_DIR:-$(swift build --show-bin-path)}"

if [[ ! -x "$BUILD_DIR/VoiceTypeMini" ]]; then
  echo "Missing built executable at $BUILD_DIR/VoiceTypeMini" >&2
  echo "Run Scripts/build-app.sh without --skip-build first." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

ditto --noextattr --noqtn "$BUILD_DIR/VoiceTypeMini" "$MACOS_DIR/VoiceTypeMini"
ditto --noextattr --noqtn "$ROOT_DIR/AppConfig/Info.plist" "$CONTENTS_DIR/Info.plist"
ditto --noextattr --noqtn "$ROOT_DIR/AppAssets/VoiceTypeMini.icns" "$RESOURCES_DIR/VoiceTypeMini.icns"

find "$BUILD_DIR" -maxdepth 1 -type d -name "*.bundle" -print0 | while IFS= read -r -d '' bundle; do
  ditto --noextattr --noqtn "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
done

chmod +x "$MACOS_DIR/VoiceTypeMini"
/usr/bin/xattr -rc "$APP_DIR" 2>/dev/null || true
find "$APP_DIR" -print0 | xargs -0 /usr/bin/xattr -c 2>/dev/null || true
find "$APP_DIR" -print0 | while IFS= read -r -d '' item; do
  /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$item" 2>/dev/null || true
  /usr/bin/xattr -d 'com.apple.fileprovider.dir#N' "$item" 2>/dev/null || true
  /usr/bin/xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
  /usr/bin/xattr -d com.apple.ResourceFork "$item" 2>/dev/null || true
  /usr/bin/xattr -d com.apple.quarantine "$item" 2>/dev/null || true
done

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Apple Development/ { print $2; exit }')"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

codesign --force --sign "$SIGN_IDENTITY" \
  --entitlements "$ROOT_DIR/AppConfig/VoiceTypeMini.entitlements" \
  "$APP_DIR"

echo "$APP_DIR"
