# Building Wilmer Alternity Sidekick

This project is configured to build for both **Windows Desktop** and **Android (Mobile)** targets. The layout is set to automatically adapt to each platform at runtime.

---

## 1. Directory Structure and Output Paths
- **Windows Desktop:** `builds/windows/WilmerAlternitySidekick.exe`
- **Android APK:** `builds/android/WilmerAlternitySidekick.apk`

*Note: The `manuals/` directory is excluded from final exports to minimize package sizes.*

---

## 2. Prerequisites Setup

### Java Development Kit (JDK)
Godot 4 Android exports require **OpenJDK 17**.
- Recommended distribution: Eclipse Temurin OpenJDK 17.
- Default setup path: `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`

### Android SDK Setup
An Android SDK must be set up at `C:\AndroidSDK` with the following components:
1. **Platform Tools**
2. **Build Tools** (v34.0.0 and v35.0.1)
3. **SDK Platforms** (API 34 & 35)
4. **Command-line Tools** (latest)
5. **NDK** (r28b or specifically `28.1.13356709`)
6. **CMake** (`3.10.2.4988404`)

You can install these components headlessly using the Android SDK manager:
```powershell
& "C:\AndroidSDK\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="C:\AndroidSDK" "platform-tools" "build-tools;34.0.0" "build-tools;35.0.1" "platforms;android-34" "platforms;android-35" "ndk;28.1.13356709" "cmake;3.10.2.4988404"
```

### Keystore Signature File
A signing keystore is required for Android exports. To generate the local `debug.keystore` file:
```powershell
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 36500
```
This file should remain in the root directory. It is already added to `.gitignore` to prevent committing signature files.

---

## 3. Configuration Layouts (Desktop vs Mobile)

Godot uses runtime feature tags to determine resolution and orientation overrides, defined in `project.godot`:

```ini
[display]
# Default Viewport Size (Windows Desktop Landscape)
window/size/viewport_width=1280
window/size/viewport_height=720

# Mobile Viewport Size Overrides (Android Portrait)
window/size/viewport_width.mobile=390
window/size/viewport_height.mobile=844

# Orientation Lock
window/handheld/orientation=1
```

> [!IMPORTANT]
> The orientation property `window/handheld/orientation` is serialized as an **Integer Enum**, not a string. Setting it to `1` locks the device orientation to **Portrait**. A string like `"portrait"` will default to `0` (Landscape).

---

## 4. Build Commands

We have structured the build process in `tools/build.ps1` to handle build folders and cleaning automatically.

### Environment Script
To compile Android, ensure your environment variables are configured in your shell:
```powershell
$env:ANDROID_HOME = "C:\AndroidSDK"
$env:ANDROID_SDK_ROOT = "C:\AndroidSDK"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
$env:PATH = "C:\AndroidSDK\platform-tools;C:\AndroidSDK\build-tools\34.0.0;" + $env:JAVA_HOME + "\bin;" + $env:PATH
```

### Using Build Script
```powershell
# Build both configured targets
powershell -ExecutionPolicy Bypass -File tools/build.ps1

# Build Windows only
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target windows

# Build Android only (debug APK)
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target android -Mode debug
```

### Raw Godot CLI Commands (Headless)
If you want to invoke Godot directly:
```powershell
# Windows Build
godot --headless --path . --export-release "Windows Desktop" builds/windows/WilmerAlternitySidekick.exe

# Android Build
godot --headless --path . --export-debug "Android APK" builds/android/WilmerAlternitySidekick.apk
```
