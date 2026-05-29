# Building

This Godot project is set up with export presets for:

- `Windows Desktop` -> `builds/windows/WilmerAlternitySidekick.exe`
- `Android APK` -> `builds/android/WilmerAlternitySidekick.apk`

The `manuals/` folder is excluded from exports so packaged builds stay small. The app uses the generated Core rules JSON under `data/rules/`.

## Prerequisites

Install Godot export templates for the exact editor version in use. This project was verified with Godot `4.6.3.stable`.

For Android, also configure Godot's Android export settings:

- Android SDK
- Android build tools
- JDK
- debug or release signing keystore

For local phone testing, a debug APK is usually enough. For distribution, configure a release keystore in Godot before making a release APK.

## Commands

From the project root:

```powershell
# Build both configured targets.
powershell -ExecutionPolicy Bypass -File tools/build.ps1

# Build Windows only.
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target windows

# Build Android only.
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target android

# Build a debug Android APK for local device testing.
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target android -Mode debug
```

Equivalent raw Godot commands:

```powershell
New-Item -ItemType Directory -Force builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/WilmerAlternitySidekick.exe

New-Item -ItemType Directory -Force builds/android
godot --headless --path . --export-debug "Android APK" builds/android/WilmerAlternitySidekick.apk
```
