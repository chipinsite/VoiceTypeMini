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

Source installs and signed release builds prefetch and bundle the WhisperKit
`base` model by default so the first launch has local model weights available.
Set `VOICE_TYPE_WHISPERKIT_MODELS="base small"` to bundle more models, or
`VOICE_TYPE_SKIP_WHISPERKIT_PREFETCH=1` to keep the release smaller and let the
app download the selected model into Application Support on first launch.

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

## Releases And Updates

VoiceTypeMini uses Sparkle for app updates in signed release builds. A source
build will not start the updater unless the release bundle has a real Sparkle
public EdDSA key in `SUPublicEDKey`.

Important rollout note: users who already installed a build before Sparkle was
added must manually install one Sparkle-enabled release. After that, future
published releases can be discovered from inside the app.

Required GitHub repository secrets for release publishing:

- `DEVELOPER_ID_APPLICATION_CERT_BASE64`: base64-encoded Developer ID
  Application `.p12`.
- `DEVELOPER_ID_APPLICATION_CERT_PASSWORD`: password for the `.p12`.
- `DEVELOPER_ID_APPLICATION_IDENTITY`: codesign identity name, for example
  `Developer ID Application: Example Ltd (TEAMID)`.
- `SPARKLE_PUBLIC_ED_KEY`: public key printed by Sparkle `generate_keys`.
- `SPARKLE_PRIVATE_KEY_BASE64`: base64-encoded Sparkle private key export.
- `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD`: notarization
  credentials for `notarytool`.

Create a release from GitHub Actions:

1. Open **Actions > Release VoiceTypeMini**.
2. Run the workflow with a marketing version such as `0.2.0` and an incrementing
   build number such as `2`.
3. The workflow builds, signs, notarizes, creates a GitHub Release ZIP, and
   commits the generated `appcast.xml` back to `main`.

Local dry run, without notarization:

```sh
VERSION=0.2.0 \
BUILD_NUMBER=2 \
SPARKLE_PUBLIC_ED_KEY="<public-key>" \
ALLOW_AD_HOC_RELEASE=1 \
SKIP_NOTARIZATION=1 \
Scripts/release-build.sh
```

To explicitly prefetch model weights before packaging:

```sh
Scripts/prefetch-whisperkit-models.sh base
Scripts/build-app.sh
```

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
