#Requires -Version 5.1
<#
.SYNOPSIS
    Strips the Godot AI MCP addon's local-only entries from project.godot.

.DESCRIPTION
    The Godot AI MCP addon is an editor-only development tool (gitignored at
    /addons/godot_ai/). Enabling it in the Godot editor writes two things into
    project.godot:

        [autoload]
        _mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"

        [editor_plugins]
        enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")

    Neither may be committed. The autoload is the dangerous one: it makes the
    addon a *runtime* dependency, so a clone or CI runner without addons/ fails
    at export with an unresolvable autoload path.

    Run this before committing whenever project.godot shows unexpected changes.

.EXAMPLE
    pwsh tools/clean_project_settings.ps1
    pwsh tools/clean_project_settings.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

$projectFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'project.godot'
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "project.godot not found at $projectFile"
}

$lines = @(Get-Content -LiteralPath $projectFile)
$result = New-Object System.Collections.Generic.List[string]
$removals = New-Object System.Collections.Generic.List[string]

# Pass 1 - drop autoload entries pointing into the addon.
foreach ($line in $lines) {
    if ($line -match '^\s*[A-Za-z_]\w*\s*=\s*"\*?res://addons/godot_ai/') {
        $removals.Add("autoload: $($line.Trim())")
        continue
    }
    $result.Add($line)
}

# Pass 2 - remove the addon from [editor_plugins] enabled=PackedStringArray(...).
for ($i = 0; $i -lt $result.Count; $i++) {
    if ($result[$i] -notmatch '^\s*enabled\s*=\s*PackedStringArray\(') { continue }

    $entries = @([regex]::Matches($result[$i], '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
    $kept = @($entries | Where-Object { $_ -notlike '*addons/godot_ai/*' })
    if ($kept.Count -eq $entries.Count) { continue }

    $removals.Add("editor_plugin: $(($entries | Where-Object { $_ -like '*addons/godot_ai/*' }) -join ', ')")

    if ($kept.Count -gt 0) {
        $quoted = ($kept | ForEach-Object { '"' + $_ + '"' }) -join ', '
        $result[$i] = "enabled=PackedStringArray($quoted)"
    }
    else {
        # Array is now empty - drop the enabled= line and its [editor_plugins] header.
        $result.RemoveAt($i)
        for ($j = $i - 1; $j -ge 0; $j--) {
            if ($result[$j] -match '^\s*\[editor_plugins\]\s*$') { $result.RemoveAt($j); break }
            if ($result[$j] -match '^\s*\[') { break }        # a different section - stop
            if ($result[$j].Trim() -ne '') { break }          # real content - stop
        }
    }
    break
}

# Collapse runs of blank lines left behind by the removals.
$normalized = New-Object System.Collections.Generic.List[string]
$blankRun = 0
foreach ($line in $result) {
    if ($line.Trim() -eq '') {
        $blankRun++
        if ($blankRun -gt 1) { continue }
    }
    else { $blankRun = 0 }
    $normalized.Add($line)
}

if ($removals.Count -eq 0) {
    Write-Host 'project.godot is already clean - nothing to remove.'
    exit 0
}

if ($PSCmdlet.ShouldProcess($projectFile, "Remove $($removals.Count) Godot AI MCP entr(y/ies)")) {
    # Godot writes project.godot as BOM-less UTF-8 with LF endings. Set-Content
    # -Encoding utf8 emits a BOM on Windows PowerShell 5.1, which Godot rewrites
    # on next save and which shows up as a spurious whole-file diff.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($projectFile, ($normalized -join "`n") + "`n", $utf8NoBom)
    Write-Host "Cleaned project.godot - removed $($removals.Count) entr(y/ies):"
    $removals | ForEach-Object { Write-Host "  - $_" }
    Write-Host ''
    Write-Host 'The addon stays enabled in your editor session until you restart Godot.'
}
