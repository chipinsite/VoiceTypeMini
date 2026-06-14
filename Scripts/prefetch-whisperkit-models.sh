#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${VOICE_TYPE_WHISPERKIT_MODELS_DIR:-$ROOT_DIR/WhisperKitModels}"

if [[ "$#" -eq 0 ]]; then
  set -- base
fi

cd "$ROOT_DIR"
swift run WhisperKitModelPrefetch --output "$OUTPUT_DIR" "$@"

echo "WhisperKit model weights are ready in $OUTPUT_DIR"
