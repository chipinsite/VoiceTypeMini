# VoiceTypeMini Transcription Benchmarks

Use this folder to compare transcription engines with the same audio.

## How To Add Samples

1. Create a folder such as `Benchmarks/Samples`.
2. Add audio files: `.m4a`, `.wav`, `.caf`, or `.mp3`.
3. For each audio file, add a matching `.txt` file with what you actually said.

Example:

```text
Benchmarks/Samples/intro.m4a
Benchmarks/Samples/intro.txt
```

## Suggested Phrases

Record short clips that sound like your real use:

- "Hi Henry, quick update from Sphiwe. The pipeline is looking good, but we need to check the OpenAI fallback."
- "Please remind me to follow up with Wispr Flow context awareness and WhisperKit model loading."
- "VoiceTypeMini should understand my accent, product names, and the way I speak in emails."
- "The issue is not the microphone button. The recording starts, but the transcript misses the context."
- "Let's ship the smart dictation cleanup and then benchmark Apple Speech, OpenAI, and WhisperKit."

## Run The Benchmark

```bash
swift run TranscriptionBenchmark --audio-dir Benchmarks/Samples
```

The tool writes:

- `Reports/transcription-benchmark.html`
- `Reports/transcription-benchmark.json`

## OpenAI Key

For OpenAI results, set:

```bash
export OPENAI_API_KEY="your-key"
```

Or pass:

```bash
swift run TranscriptionBenchmark --audio-dir Benchmarks/Samples --openai-key "your-key"
```
