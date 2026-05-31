# Wilmer Alternity Sidekick

A mobile-friendly companion application for the **Alternity Sci-Fi Tabletop Roleplaying Game (RPG)**, built using **Godot 4.6.3**. 

This application serves as a handy digital assistant to quickly reference core rules, track achievements, audit equipment catalog databases, and reference character mutations.

---

## Motivation

This companion application was born out of a simple, practical frustration: playing **Alternity** often requires referencing up to five separate core manuals just to calculate a single action roll with all its corresponding situation steps, situational adjustments, skill interactions, and gear parameters. By digitizing these lookups, this sidekick app aims to keep players and Game Masters in the flow of the game rather than buried in rulebooks.

Godot was chosen as the engine for this project to ensure seamless cross-platform performance across both mobile (for quick table lookups) and desktop screens.

Future plans include integrating a robust in-app dice roller to calculate rolls and steps dynamically.

This project is a labor of love for the classic Alternity Sci-Fi system. Feel free to open issues, submit pull requests, or fork the repository to expand it further!

---

## Features

- **Mobile Viewport Optimization**: Structured for modern mobile displays (defaulting to a `390x844` viewport).
- **Responsive Layout Safety**: Protects compact screen boundaries using custom size constraints and smart word-wrapping to prevent empty list elements or wide layouts from breaking layout containers.
- **Accurate Rules Evaluation**: Translates the full Alternity tabletop rules for derived attributes, checking perks (*Tough as Nails*, *Reflexes*, *Willpower*), flaws (*Spineless*), and specialty/melee combat skill ranks to calculate exact Resistance Modifiers on character sheets.
- **Core Database Engine**: Fast offline searching and viewing of data sourced directly from JSON rulesheets.
- **Excluded Media Size Optimization**: Keeps packaged builds lightweight by automatically excluding raw reference manuals (PDFs) from the final binary files.
- **Developer Tools**: Automated build utility (`tools/build.ps1`) and GDScript smoke-test scripts for verification.

---

## Directory Structure

* `data/rules/`: Contains the core dataset in JSON format (e.g., equipment lists, mutations, achievements, and core rules).
* `manuals/`: Local PDF documents used for developer references (automatically ignored during exports to minimize size).
* `scripts/`: GDScript files implementing the UI controller (`main.gd`) and rules database engine (`alternity_rules.gd`).
* `tools/`: Diagnostic smoke test scripts and the PowerShell build automation script.
* `export_presets.cfg`: The export presets configured for desktop and mobile targets.
* `project.godot`: The Godot project configuration file.

---

## Prerequisites

Before building the application, ensure you have:

1. **Godot Editor**: Version `4.6.3.stable` (configured with the required export templates).
2. **For Windows Build**:
   - Standard Godot desktop export templates installed.
3. **For Android Build**:
   - **Android SDK & Build Tools**: Configured within Godot (`Editor -> Editor Settings -> Export -> Android`).
   - **Java Development Kit (JDK)**: Recommended version 17.
   - **Android Keystore**: A debug or release signing keystore configured in Godot under the Android export settings.

---

## Build Instructions

You can build the project either using the automated PowerShell wrapper script or manually via the Godot CLI.

### Option A: Using the PowerShell Build Tool (Recommended)

From the project root, open PowerShell and run one of the following commands:

```powershell
# 1. Build both Windows and Android (Release mode)
powershell -ExecutionPolicy Bypass -File tools/build.ps1

# 2. Build Windows Desktop only
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target windows

# 3. Build Android APK only
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target android

# 4. Build a Debug Android APK (for testing directly on connected phones)
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target android -Mode debug
```

Outputs will be saved to the `builds/` directory:
- Windows Desktop: `builds/windows/WilmerAlternitySidekick.exe`
- Android APK: `builds/android/WilmerAlternitySidekick.apk`

---

### Option B: Manual Compilation via Godot CLI

If you prefer to run raw commands, you can export directly via the Godot executable:

#### Windows Desktop Build:
```powershell
New-Item -ItemType Directory -Force builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/WilmerAlternitySidekick.exe
```

#### Android APK Build (Debug):
```powershell
New-Item -ItemType Directory -Force builds/android
godot --headless --path . --export-debug "Android APK" builds/android/WilmerAlternitySidekick.apk
```

---

## Running Smoke Tests

You can run automated diagnostic tests headless using Godot to verify database integrity:

```powershell
# Run mutations diagnostic tests
godot --headless --path . -s tools/smoke_mutations.gd

# Run achievements diagnostic tests
godot --headless --path . -s tools/smoke_achievements.gd

# Run achievement math diagnostic tests
godot --headless --path . -s tools/smoke_achievement_math.gd

# Run equipment catalog diagnostic tests
godot --headless --path . -s tools/smoke_equipment_catalog.gd

# Run resistance modifier rules validation tests
godot --headless -s scratch/test_resistance_modifier.gd

# Run resistance modifier verification on saved character sheets
godot --headless -s scratch/test_characters_rm.gd
```
