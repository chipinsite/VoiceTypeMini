# VoiceTypeMini Build Plan

Date: 2026-06-13

## Product Shape

VoiceTypeMini is a personal macOS push-to-talk speech-to-text menu-bar app.

The intended first real workflow is:

1. Press and hold a global hotkey.
2. Speak.
3. Release the hotkey.
4. Transcribe the recorded clip.
5. Paste the transcript into the active app.

## Backend Decision

Apple does have its own transcription stack.

- Preferred local backend: WhisperKit.
- Future Apple-native backend: Apple `SpeechAnalyzer` on macOS 26+.
- Cloud backend to evaluate first: OpenAI speech-to-text.
- Cloud backend to compare later: Deepgram Nova-3.

For the first implementation, keep transcription behind this protocol:

```swift
protocol TranscriptionClient: Sendable {
    func transcribe(audioFileURL: URL) async throws -> String
}
```

This lets us test Apple, Deepgram, and WhisperKit without rewriting the app shell.

## Slice 1: Buildable Menu-Bar Shell

Status: done

Goal:

- Create standalone Swift project.
- Add menu-bar app entry.
- Add status state.
- Add settings view.
- Add backend selector.
- Add stub transcription client.

Verification:

- `swift test`

Current result:

- Passing.

## Slice 2: Local Recording

Status: in progress

Goal:

- Add microphone permission check.
- Add `NSMicrophoneUsageDescription` when we move to an app bundle.
- Use `AVAudioEngine` to record a short clip.
- Save the clip to a temporary file.
- Add a debug menu action: record five seconds, then show the file path.

Verification:

- Build passes.
- Manual run creates a playable audio file.
- Temporary file is deleted when reset.

Packaging:

```sh
Scripts/build-app.sh
open .build/app/VoiceTypeMini.app
```

Current state:

- `.app` packaging is implemented.
- `Info.plist` includes microphone and speech recognition purpose strings.
- The app is menu-bar-only via `LSUIElement`.
- The debug app bundle is ad-hoc signed with the audio input entitlement.

## Slice 3: Apple Speech Backend

Status: planned

Goal:

- Add `AppleSpeechTranscriptionClient`.
- Use `SpeechAnalyzer` on macOS 26+.
- Convert audio to the analyzer's expected format.
- Return plain text through `TranscriptionClient`.

Verification:

- Transcribe the debug recording.
- Show transcript in the menu.
- Confirm behavior when assets/language are unavailable.

## Slice 4: WhisperKit Backend

Status: in progress

Goal:

- Add WhisperKit as a Swift Package dependency.
- Use the local `tiny` model first for fast debugging.
- Transcribe the last saved `.m4a` recording locally.

Verification:

- First run may download the model.
- Record a short clip.
- Transcribe with backend set to WhisperKit.

## Slice 5: OpenAI Backend

Status: in progress

Goal:

- Add `OpenAITranscriptionClient`.
- Use REST pre-recorded endpoint first, not streaming.
- Send local recorded file to:

```text
https://api.openai.com/v1/audio/transcriptions
```

- Default to `gpt-4o-mini-transcribe`.
- Read API key from environment or Keychain.
- Never commit the key.

Current state:

- OpenAI client exists.
- API key is stored in Keychain from Settings.
- The menu can transcribe the last saved recording.

## Slice 6: Push-To-Talk Hotkey

Status: in progress

Goal:

- Use Control + Option + Space.
- Key down starts recording.
- Key up stops recording.
- Release triggers transcription using the selected backend.

Verification:

- Enable VoiceTypeMini in Input Monitoring if macOS asks.
- Hold Control + Option + Space, speak, release.
- Confirm transcript appears in the menu.

Verification:

- Transcribe the same debug recording with OpenAI.
- Compare result to Apple output.
- Confirm failure state with missing/invalid key.

## Slice 5: Global Hotkey

Status: planned

Goal:

- Add push-to-talk hotkey.
- Start with a normal combo such as Control + Option + Space.
- Avoid modifier-only hotkeys until the main flow works.

Verification:

- Press hotkey starts recording.
- Release hotkey triggers transcription.
- Repeated keydown does not start duplicate sessions.

## Slice 6: Paste Into Active App

Status: planned

Goal:

- Copy transcript to `NSPasteboard`.
- Add Accessibility permission detection.
- If Accessibility is granted, synthesize Command+V.
- If not, leave the transcript copied and show a clear status.

Verification:

- Paste into Notes, Safari/Chrome, VS Code, Terminal, Slack.
- Confirm secure fields fail gracefully.

## Slice 7: Polish For Personal Use

Status: planned

Goal:

- Launch at login.
- Last transcript history.
- Clear history.
- Private mode.
- Backend setting.
- Basic signing/app bundle packaging.

Verification:

- App can be launched from Finder.
- Permissions persist across rebuilds as much as possible.
- App can be quit cleanly from menu bar.

## Current Research Notes

- Apple `SpeechAnalyzer` is the lightest local path if targeting macOS 26+.
- OpenAI is the first cloud backend because it keeps our provider stack simple.
- Deepgram Nova-3 remains a good later cloud comparison backend.
- For v1, file-based transcription is simpler than live streaming and easier to test.
