#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${VOICE_TYPE_APP_DIR:-/tmp/VoiceTypeMini.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
SKIP_BUILD="${1:-}"

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "--skip-build" ]]; then
  swift build --product VoiceTypeMini
fi

BUILD_DIR="${VOICE_TYPE_BUILD_DIR:-$(swift build --show-bin-path)}"

if [[ ! -x "$BUILD_DIR/VoiceTypeMini" ]]; then
  echo "Missing built executable at $BUILD_DIR/VoiceTypeMini" >&2
  echo "Run Scripts/build-app.sh without --skip-build first." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

ditto --noextattr --noqtn "$BUILD_DIR/VoiceTypeMini" "$MACOS_DIR/VoiceTypeMini"
ditto --noextattr --noqtn "$ROOT_DIR/AppConfig/Info.plist" "$CONTENTS_DIR/Info.plist"
ditto --noextattr --noqtn "$ROOT_DIR/AppAssets/VoiceTypeMini.icns" "$RESOURCES_DIR/VoiceTypeMini.icns"

if [[ -n "${VOICE_TYPE_APPCAST_URL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL ${VOICE_TYPE_APPCAST_URL}" "$CONTENTS_DIR/Info.plist"
fi

if [[ -n "${VOICE_TYPE_SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${VOICE_TYPE_SPARKLE_PUBLIC_ED_KEY}" "$CONTENTS_DIR/Info.plist"
fi

SPARKLE_FRAMEWORK="${SPARKLE_FRAMEWORK:-}"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(
    find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d -print 2>/dev/null \
      | head -n 1
  )"
fi

if [[ -n "$SPARKLE_FRAMEWORK" && -d "$SPARKLE_FRAMEWORK" ]]; then
  ditto --noextattr --noqtn "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
fi

if ! otool -l "$MACOS_DIR/VoiceTypeMini" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/VoiceTypeMini"
fi

copy_resource_bundles() {
  local search_dir="$1"
  [[ -d "$search_dir" ]] || return 0

  find "$search_dir" -maxdepth 4 -type d -name "*.bundle" -print0 | while IFS= read -r -d '' bundle; do
    ditto --noextattr --noqtn "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
  done
}

copy_resource_bundles "$BUILD_DIR"
copy_resource_bundles "$ROOT_DIR/.build/debug"
copy_resource_bundles "$ROOT_DIR/.build/release"
copy_resource_bundles "$ROOT_DIR/.build/arm64-apple-macosx/debug"
copy_resource_bundles "$ROOT_DIR/.build/arm64-apple-macosx/release"

WHISPERKIT_MODELS_SOURCE="${VOICE_TYPE_WHISPERKIT_MODELS_DIR:-$ROOT_DIR/WhisperKitModels}"
if [[ -d "$WHISPERKIT_MODELS_SOURCE" ]]; then
  ditto --noextattr --noqtn "$WHISPERKIT_MODELS_SOURCE" "$RESOURCES_DIR/WhisperKitModels"
fi

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

SIGN_ARGS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi

find "$APP_DIR" -depth \( -name "*.xpc" -o -name "*.framework" -o -name "*.dylib" \) -print0 |
  while IFS= read -r -d '' signable; do
    codesign "${SIGN_ARGS[@]}" "$signable"
  done

codesign "${SIGN_ARGS[@]}" \
  --entitlements "$ROOT_DIR/AppConfig/VoiceTypeMini.entitlements" \
  "$APP_DIR"

echo "$APP_DIR"
