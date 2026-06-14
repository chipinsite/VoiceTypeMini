#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:?Set VERSION, for example 0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:?Set BUILD_NUMBER, for example 2}"
REPOSITORY="${GITHUB_REPOSITORY:-chipinsite/VoiceTypeMini}"
TAG="${TAG:-v$VERSION}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="${VOICE_TYPE_APP_DIR:-$DIST_DIR/VoiceTypeMini.app}"
ZIP_NAME="${ZIP_NAME:-VoiceTypeMini-$VERSION.zip}"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
APPCAST_PATH="${APPCAST_PATH:-$DIST_DIR/appcast.xml}"
RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH:-$DIST_DIR/release-notes-$VERSION.md}"
APPCAST_URL="${VOICE_TYPE_APPCAST_URL:-https://raw.githubusercontent.com/$REPOSITORY/main/appcast.xml}"
DOWNLOAD_URL="${VOICE_TYPE_DOWNLOAD_URL:-https://github.com/$REPOSITORY/releases/download/$TAG/$ZIP_NAME}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-${VOICE_TYPE_SPARKLE_PUBLIC_ED_KEY:-}}"

if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY is required for release builds." >&2
  exit 1
fi

if [[ "${SIGN_IDENTITY:-}" == "" || "${SIGN_IDENTITY:-}" == "-" ]]; then
  if [[ "${ALLOW_AD_HOC_RELEASE:-0}" != "1" ]]; then
    echo "SIGN_IDENTITY must be a Developer ID Application identity for release builds." >&2
    exit 1
  fi
fi

mkdir -p "$DIST_DIR"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$ROOT_DIR/AppConfig/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$ROOT_DIR/AppConfig/Info.plist"

export VOICE_TYPE_APP_DIR="$APP_DIR"
export VOICE_TYPE_APPCAST_URL="$APPCAST_URL"
export VOICE_TYPE_SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY"

"$ROOT_DIR/Scripts/build-app.sh"

GENERATE_KEYS="${SPARKLE_GENERATE_KEYS:-$("$ROOT_DIR/Scripts/find-sparkle-tool.sh" generate_keys)}"
SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-$("$ROOT_DIR/Scripts/find-sparkle-tool.sh" sign_update)}"

if [[ -n "${SPARKLE_PRIVATE_KEY_BASE64:-}" ]]; then
  private_key_file="$DIST_DIR/sparkle_private_key"
  python3 - "$private_key_file" <<'PY'
import base64
import os
import sys

target = sys.argv[1]
data = os.environ["SPARKLE_PRIVATE_KEY_BASE64"]
with open(target, "wb") as handle:
    handle.write(base64.b64decode(data))
PY
  "$GENERATE_KEYS" -f "$private_key_file"
  rm -f "$private_key_file"
fi

if [[ "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
  notarization_zip="$DIST_DIR/VoiceTypeMini-notarization.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$notarization_zip"

  if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
    xcrun notarytool submit "$notarization_zip" \
      --keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE" \
      --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$notarization_zip" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  else
    echo "Notarization credentials are required. Set SKIP_NOTARIZATION=1 only for non-production dry runs." >&2
    exit 1
  fi

  xcrun stapler staple "$APP_DIR"
fi

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

signature_attributes="$("$SIGN_UPDATE" "$ZIP_PATH")"
pub_date="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

if [[ ! -f "$RELEASE_NOTES_PATH" ]]; then
  cat > "$RELEASE_NOTES_PATH" <<EOF
# VoiceTypeMini $VERSION

- Flow-style dictation dock with live audio waveform.
- Local correction learning and vocabulary tools.
- Sparkle-based update support for future releases.
EOF
fi

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>VoiceTypeMini Updates</title>
    <link>https://github.com/$REPOSITORY</link>
    <description>VoiceTypeMini release feed</description>
    <language>en</language>
    <item>
      <title>VoiceTypeMini $VERSION</title>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>$pub_date</pubDate>
      <link>https://github.com/$REPOSITORY/releases/tag/$TAG</link>
      <sparkle:releaseNotesLink>https://github.com/$REPOSITORY/releases/tag/$TAG</sparkle:releaseNotesLink>
      <enclosure
        url="$DOWNLOAD_URL"
        $signature_attributes
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

printf 'Built release app: %s\n' "$APP_DIR"
printf 'Built update archive: %s\n' "$ZIP_PATH"
printf 'Built appcast: %s\n' "$APPCAST_PATH"
