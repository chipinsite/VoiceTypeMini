#!/usr/bin/env bash
set -euo pipefail

TOOL_NAME="${1:?Usage: Scripts/find-sparkle-tool.sh <tool-name>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

candidate_dirs=()

if [[ -n "${SPARKLE_BIN:-}" ]]; then
  candidate_dirs+=("$SPARKLE_BIN")
fi

if [[ -n "${SPARKLE_TOOL_DIR:-}" ]]; then
  candidate_dirs+=("$SPARKLE_TOOL_DIR")
fi

candidate_dirs+=(
  "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
  "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle/bin"
)

for dir in "${candidate_dirs[@]}"; do
  if [[ -x "$dir/$TOOL_NAME" ]]; then
    printf '%s\n' "$dir/$TOOL_NAME"
    exit 0
  fi
done

found="$(
  find "$ROOT_DIR/.build" "$HOME/Library/Developer/Xcode/DerivedData" \
    -path "*/Sparkle*/bin/$TOOL_NAME" \
    -type f \
    -perm -111 \
    -print 2>/dev/null \
    | head -n 1
)"

if [[ -n "$found" ]]; then
  printf '%s\n' "$found"
  exit 0
fi

SPARKLE_VERSION="${SPARKLE_VERSION:-}"
if [[ -z "$SPARKLE_VERSION" && -f "$ROOT_DIR/Package.resolved" ]]; then
  SPARKLE_VERSION="$(
    python3 - "$ROOT_DIR/Package.resolved" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

for pin in data.get("pins", []):
    if pin.get("identity") == "sparkle":
        print(pin.get("state", {}).get("version", ""))
        break
PY
  )"
fi

if [[ -n "$SPARKLE_VERSION" ]]; then
  cache_dir="$ROOT_DIR/.build/sparkle-tools-$SPARKLE_VERSION"
  archive_path="$cache_dir/Sparkle-for-Swift-Package-Manager.zip"
  mkdir -p "$cache_dir"

  if ! find "$cache_dir" -path "*/bin/$TOOL_NAME" -type f -perm -111 -print -quit | grep -q .; then
    curl -fL \
      "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-for-Swift-Package-Manager.zip" \
      -o "$archive_path"
    ditto -x -k "$archive_path" "$cache_dir"
  fi

  found="$(
    find "$cache_dir" -path "*/bin/$TOOL_NAME" -type f -perm -111 -print 2>/dev/null \
      | head -n 1
  )"

  if [[ -n "$found" ]]; then
    printf '%s\n' "$found"
    exit 0
  fi
fi

cat >&2 <<EOF
Could not find Sparkle tool '$TOOL_NAME'.

Run 'swift build' first, or set SPARKLE_BIN / SPARKLE_TOOL_DIR to the
directory that contains Sparkle's generate_keys and sign_update tools.
EOF
exit 1
