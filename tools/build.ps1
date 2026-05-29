param(
    [ValidateSet("windows", "android", "all")]
    [string]$Target = "all",

    [ValidateSet("debug", "release")]
    [string]$Mode = "release"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Invoke-GodotExport {
    param(
        [string]$Preset,
        [string]$OutputPath
    )

    $OutputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    $ExportFlag = if ($Mode -eq "debug") { "--export-debug" } else { "--export-release" }
    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }
    godot --headless --path . $ExportFlag $Preset $OutputPath

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "Godot did not create expected export: $OutputPath"
    }
}

if ($Target -eq "windows" -or $Target -eq "all") {
    Invoke-GodotExport -Preset "Windows Desktop" -OutputPath "builds/windows/WilmerAlternitySidekick.exe"
}

if ($Target -eq "android" -or $Target -eq "all") {
    Invoke-GodotExport -Preset "Android APK" -OutputPath "builds/android/WilmerAlternitySidekick.apk"
}
