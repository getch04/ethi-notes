# EthioNote

A minimalist speech-to-text mobile app built with Flutter, powered by the **ElevenLabs Scribe API**.

## Features
- **ElevenLabs Scribe API**: High-quality transcription for English and Amharic.
- **Minimalist UI**: Simple, dark-themed interface with a large central record button.
- **Language Support**: Toggle between English (eng) and Amharic (አማርኛ - amh).
- **Transcript Management**: Copy to clipboard and clear transcript with simple buttons.
- **Privacy First**: Local recording at 16kHz mono, processed only via ElevenLabs.

## Setup Instructions

### 1. Prerequisites
- Flutter SDK installed.
- An ElevenLabs account and API Key.

### 2. Configuration
Create a `.env` file in the root directory of the project:
```env
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
```
Alternatively, you can provide the API key at build time using `--dart-define`:
```bash
flutter run --dart-define=ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
```

### 3. Permissions
- **Android**: Ensure `RECORD_AUDIO` permission is granted (configured in `AndroidManifest.xml`).
- **iOS**: Ensure `NSMicrophoneUsageDescription` is configured (in `Info.plist`).

### 4. Run the App
```bash
flutter pub get
flutter run
```

### 5. Android release build (APK)
The Android release build needs the **Android NDK** (used by Flutter and plugins like `record`). If you see *"Android NDK Clang could not be found"*:

**Option A – Android Studio**
1. Open **Android Studio** → **Settings** (or **Preferences** on macOS) → **Languages & Frameworks** → **Android SDK** → **SDK Tools**.
2. Enable **NDK (Side by side)** and install. Use version **28.2.13676358** if offered, or install the latest and let Gradle use it.
3. Click **Apply** and wait for the install to finish.

**Option B – Command line**
```bash
# Use your Android SDK path (from android/local.properties)
export ANDROID_HOME=/Users/getch/Library/Android/sdk
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --install "ndk;28.2.13676358"
```
If `cmdline-tools` is not installed, install it from SDK Manager first, or use the path `$ANDROID_HOME/tools/bin/sdkmanager` if you have the legacy tools.

Then build the APK:
```bash
flutter clean && flutter pub get && flutter build apk --release
```
The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

**If it still fails:** Flutter picks the *newest* NDK in `$ANDROID_HOME/ndk/`. If an incomplete or broken NDK (e.g. a placeholder) is newest, force the working one:
```bash
export ANDROID_NDK_HOME=/Users/getch/Library/Android/sdk/ndk/28.2.13676358
flutter build apk --release
```
(Adjust the path if your SDK or NDK version is different.)

### 6. Windows desktop build (share with Windows users)
You can’t build a Windows `.exe` on a Mac. Use one of these:

**Option A – GitHub Actions (recommended, no Windows PC needed)**  
1. Push the project to GitHub (including the `.github/workflows/build-windows.yml` file).  
2. Open the repo on GitHub → **Actions** tab → workflow **"Build Windows"** → **Run workflow**.  
3. When the run finishes, open it and download the **EthioNote-Windows** artifact (a zip).  
4. Share that zip with your friend. They unzip it and double‑click **Runner.exe** (or **ethionote.exe**).  
   - Windows may show “Windows protected your PC” the first time; they can click “More info” → “Run anyway” if they trust you.

**Option B – Build on a Windows PC**  
On a machine with Flutter installed and Windows desktop enabled:
```bash
flutter pub get
flutter build windows --release
```
The app is in `build\windows\x64\runner\Release\`. Zip that folder and share it; they run the `.exe` inside.

## Implementation Details
- **Audio Recording**: Uses the `record` package to capture 16kHz mono WAV audio.
- **API Requests**: Uses `dio` for multipart POST requests to the ElevenLabs `/v1/speech-to-text` endpoint.
- **State Management**: Simple `StatefulWidget` handling "Ready", "Listening", and "Transcribing" states.
