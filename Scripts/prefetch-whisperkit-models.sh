#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${VOICE_TYPE_WHISPERKIT_MODELS_DIR:-$ROOT_DIR/WhisperKitModels}"
LOCAL_ONLY=0
MODELS=()
if [[ "$#" -eq 0 ]]; then set -- base; fi
FORWARDED_ARGS=("$@")

# Mirror the tool's options so tokenizer files follow the actual output path.
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output)
      [[ "$#" -ge 2 ]] || { echo "Missing value for --output." >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --local-only) LOCAL_ONLY=1; shift ;;
    --load|--help|-h) shift ;;
    *) MODELS+=("$1"); shift ;;
  esac
done
if [[ "${#MODELS[@]}" -eq 0 ]]; then MODELS=(base); fi

cd "$ROOT_DIR"
swift run WhisperKitModelPrefetch --output "$OUTPUT_DIR" "${FORWARDED_ARGS[@]}"

if [[ "$LOCAL_ONLY" -eq 1 ]]; then
  echo "Local model preparation complete; tokenizer downloads skipped."
  exit 0
fi

for model in "${MODELS[@]}"; do
  variant="${model#openai_whisper-}"
  model_dir="$(find "$OUTPUT_DIR" -type d -name "openai_whisper-$variant" -print -quit)"
  if [[ -z "$model_dir" ]]; then
    echo "Could not locate the downloaded model folder for $model." >&2
    exit 1
  fi

  # Core ML variants retain the canonical Whisper model's tokenizer vocabulary.
  # Keep this mapping aligned with WhisperKit's ModelUtilities.tokenizerNameForVariant.
  case "$variant" in
    tiny.en*) repo_model=tiny.en ;;
    tiny*) repo_model=tiny ;;
    base.en*) repo_model=base.en ;;
    base*) repo_model=base ;;
    small.en*) repo_model=small.en ;;
    small*) repo_model=small ;;
    medium.en*) repo_model=medium.en ;;
    medium*) repo_model=medium ;;
    large-v3*) repo_model=large-v3 ;;
    large-v2*) repo_model=large-v2 ;;
    large*) repo_model=large ;;
    *) echo "No tokenizer repository mapping for $model." >&2; exit 1 ;;
  esac

  for file in tokenizer.json tokenizer_config.json special_tokens_map.json; do
    temporary_file="$(mktemp "$model_dir/.tokenizer.XXXXXX")"
    if curl -fL "https://huggingface.co/openai/whisper-$repo_model/resolve/main/$file" -o "$temporary_file"; then
      mv "$temporary_file" "$model_dir/$file"
    else
      rm -f "$temporary_file"
      exit 1
    fi
  done
done

echo "WhisperKit model weights and tokenizers are ready in $OUTPUT_DIR"
