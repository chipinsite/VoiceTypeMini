# VoiceTypeMini

VoiceTypeMini is a tiny personal macOS push-to-talk speech-to-text menu-bar app.

The target workflow is:

1. Hold a global hotkey.
2. Speak.
3. Release the hotkey.
4. Transcribe the short recording.
5. Paste the transcript into the active app.

## Install On Another Mac

Requirements:

- macOS 14 or newer.
- Xcode Command Line Tools with Swift 6 support.
- Internet access for the first dependency/model download.

Install or update from GitHub with one command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/chipinsite/VoiceTypeMini/main/install.sh)"
```

The installer clones the source into `~/Developer/VoiceTypeMini`, builds and signs the app, installs it into `/Applications/VoiceTypeMini.app`, verifies the signature, and opens the app.

To run development tests on a Mac with a full compatible Swift test toolchain:

```sh
VOICE_TYPE_RUN_TESTS=1 Scripts/install-app.sh
```

You can also clone and install manually:

```sh
git clone https://github.com/chipinsite/VoiceTypeMini.git
cd VoiceTypeMini
Scripts/install-app.sh
```

First-run permissions:

- Microphone: allow when macOS asks.
- Accessibility: `System Settings > Privacy & Security > Accessibility > VoiceTypeMini`.
- Input Monitoring: `System Settings > Privacy & Security > Input Monitoring > VoiceTypeMini`, if macOS asks.

## Build Plan

## Local App Bundle

Build and package the menu-bar app:

```sh
Scripts/build-app.sh
```

If `swift build` was already run and you only want to repackage the existing binary:

```sh
Scripts/build-app.sh --skip-build
```

Run the app:

```sh
open .build/app/VoiceTypeMini.app
```

The app is packaged as a menu-bar-only app with microphone permission text in `Info.plist`.

The app icon source lives at `AppAssets/VoiceTypeMiniIcon.svg`, with generated `.icns` output at `AppAssets/VoiceTypeMini.icns`.

Push-to-talk uses `Control + Option + Space`. It is registered as a normal global hotkey, so it should not need Input Monitoring. Accessibility will be needed later for auto-paste.

Auto-paste needs Accessibility permission:

```text
System Settings > Privacy & Security > Accessibility > VoiceTypeMini
```

Install the current build into Applications:

```sh
ditto .build/app/VoiceTypeMini.app /Applications/VoiceTypeMini.app
```

### Slice 1: Menu-Bar Shell

Status: in progress

- Build a standalone Swift project.
- Show a menu-bar microphone item.
- Add basic status states.
- Add a stub transcriber so the app flow can be tested without microphone or cloud setup.

Test: `swift test`

### Slice 2: Recording

Status: in progress

- Request microphone permission.
- Record short push-to-talk audio with `AVAudioEngine`.
- Save a temporary audio file.
- Delete the temporary file after transcription.

Current state:

- The local `.app` bundle exists.
- The bundle includes `NSMicrophoneUsageDescription`.
- The app is ad-hoc signed with the audio input entitlement.
- The menu includes a "Record 5 Second Clip" debug action.
- The app includes a native push-to-talk hotkey: Control + Option + Space.

Test: record a five-second clip and verify a playable local file.

### Slice 3: Apple Transcription

Status: planned

- Add Apple Speech backend.
- Prefer `SpeechAnalyzer` on macOS 26+.
- Keep the backend behind `TranscriptionClient`.

Test: transcribe a local recording and show the result in the menu.

### Slice 4: OpenAI Backend

Status: in progress

- Add an OpenAI REST client for pre-recorded clips.
- Store API key in Keychain.
- Default to `gpt-4o-mini-transcribe`.
- Add a menu action to transcribe the last saved recording.

Test: transcribe the same local file through OpenAI and compare output.

### Slice 5: Paste Into Active App

Status: planned

- Copy transcript to `NSPasteboard`.
- Use synthetic Command+V when Accessibility is granted.
- Fall back to "copied to clipboard" when Accessibility is missing.

Test: paste into Notes, Safari, VS Code, Terminal, and Slack.

## Transcription Backend Decision

Apple has its own transcription stack:

- `SpeechAnalyzer` is the modern local option on macOS 26+.
- `SFSpeechRecognizer` is the older compatibility path.

Deepgram remains worth testing later as a comparison backend, but the first cloud path is OpenAI so the provider stack stays simple.

Default direction: use WhisperKit as the local/private transcription backend, keep OpenAI as the first cloud fallback, then compare Deepgram later only if accuracy or latency needs it.

WhisperKit model options:

- `tiny`: fastest, best for testing.
- `base`: better balanced default for dictation. This is the default.
- `small`: better accuracy, slower and a larger first download.

Transcript history stores the last 10 transcripts locally in Application Support. Raw audio is not stored.

## License

MIT. See `LICENSE`.
