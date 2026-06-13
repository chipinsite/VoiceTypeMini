#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${VOICE_TYPE_REPO_URL:-https://github.com/chipinsite/VoiceTypeMini.git}"
BRANCH="${VOICE_TYPE_BRANCH:-main}"
SOURCE_DIR="${VOICE_TYPE_SOURCE_DIR:-$HOME/Developer/VoiceTypeMini}"

log() {
  printf '==> %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    return 1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "VoiceTypeMini installs on macOS only." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. macOS should open the installer now." >&2
  xcode-select --install 2>/dev/null || true
  exit 1
fi

require_command git
require_command swift

if [[ -f "Package.swift" && -x "Scripts/install-app.sh" ]]; then
  SOURCE_DIR="$(pwd)"
  log "Using current checkout at $SOURCE_DIR"
else
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    log "Updating existing checkout at $SOURCE_DIR"
    if ! git -C "$SOURCE_DIR" diff --quiet || ! git -C "$SOURCE_DIR" diff --cached --quiet; then
      echo "The checkout at $SOURCE_DIR has local changes. Commit, stash, or remove them, then rerun this installer." >&2
      exit 1
    fi
    git -C "$SOURCE_DIR" fetch origin "$BRANCH"
    git -C "$SOURCE_DIR" checkout "$BRANCH"
    git -C "$SOURCE_DIR" pull --ff-only origin "$BRANCH"
  else
    if [[ -e "$SOURCE_DIR" && ! -d "$SOURCE_DIR" ]]; then
      echo "$SOURCE_DIR already exists and is not a directory." >&2
      echo "Set VOICE_TYPE_SOURCE_DIR to another path or move that file aside." >&2
      exit 1
    fi
    if [[ -e "$SOURCE_DIR" && -n "$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
      echo "$SOURCE_DIR already exists and is not an empty VoiceTypeMini git checkout." >&2
      echo "Set VOICE_TYPE_SOURCE_DIR to another path or move that folder aside." >&2
      exit 1
    fi
    log "Cloning VoiceTypeMini into $SOURCE_DIR"
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
  fi
fi

log "Building, testing, signing, and installing VoiceTypeMini"
cd "$SOURCE_DIR"
Scripts/install-app.sh

cat <<'EOF'

VoiceTypeMini is installed in /Applications.

First-run permissions:
- Microphone: allow when macOS asks.
- Accessibility: System Settings > Privacy & Security > Accessibility > VoiceTypeMini.
- Input Monitoring: System Settings > Privacy & Security > Input Monitoring > VoiceTypeMini, if macOS asks.

Run the same install command again later to update the app.
EOF
