# Ported from riusprime/deathventory@1d697803:scripts/export_windows.ps1. Changes: artifact names (game.*).
<#
.SYNOPSIS
    Exports the game for Windows x86-64 using Godot 4.7.2.

.DESCRIPTION
    Automates the export of the Windows Desktop preset, packages the executable
    and PCK into a clean distribution archive, and calculates SHA-256 hashes.

.PARAMETER OutputDir
    Target directory for the exported binaries and zip archive. Default: "build/windows".

.PARAMETER PresetName
    Name of the export preset in export_presets.cfg. Default: "Windows Desktop".

.PARAMETER ArchiveName
    Name of the output zip archive. Default: "game_windows_x86_64.zip".

.PARAMETER Debug
    Export in debug mode instead of release mode.
#>
param(
    [string]$OutputDir = "build/windows",
    [string]$PresetName = "Windows Desktop",
    [string]$ArchiveName = "game_windows_x86_64.zip",
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
Set-Location $RepoRoot

Write-Host "=== Windows x86-64 Export ==="
Write-Host "Repository root: $RepoRoot"
Write-Host "Preset name:     $PresetName"
Write-Host "Output dir:      $OutputDir"

# 1. Ensure output directory exists
$ResolvedOutputDir = Join-Path $RepoRoot $OutputDir
if (-not (Test-Path $ResolvedOutputDir)) {
    New-Item -ItemType Directory -Path $ResolvedOutputDir -Force | Out-Null
}

$ExePath = Join-Path $ResolvedOutputDir "game.exe"
$PckPath = Join-Path $ResolvedOutputDir "game.pck"
$ArchivePath = Join-Path $ResolvedOutputDir $ArchiveName
$ChecksumsPath = Join-Path $ResolvedOutputDir "SHA256SUMS.txt"

# 2. Verify export presets file exists
$PresetsFile = Join-Path $RepoRoot "export_presets.cfg"
if (-not (Test-Path $PresetsFile)) {
    Write-Error "Missing export_presets.cfg in repository root."
    exit 1
}

# 3. Clean any existing build artifacts
if (Test-Path $ExePath) { Remove-Item $ExePath -Force }
if (Test-Path $PckPath) { Remove-Item $PckPath -Force }
if (Test-Path $ArchivePath) { Remove-Item $ArchivePath -Force }
if (Test-Path $ChecksumsPath) { Remove-Item $ChecksumsPath -Force }

# 4. Locate Godot binary
$GodotBin = $null

# On Windows, prefer the console executable (*console.exe) for full CLI output and logging
$ConsoleExe = Get-ChildItem -Path "$env:USERPROFILE\godot" -Filter "*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ConsoleExe) {
    $GodotBin = $ConsoleExe.FullName
}

# Check environment variables
if (-not $GodotBin -and $env:GODOT -and (Test-Path $env:GODOT)) {
    if ($env:GODOT.EndsWith(".exe")) {
        $GodotBin = $env:GODOT
    } elseif (Test-Path "$($env:GODOT).exe") {
        $GodotBin = "$($env:GODOT).exe"
    } else {
        # Extensionless file created by setup-godot on Windows: create .exe copy
        Copy-Item -Path $env:GODOT -Destination "$($env:GODOT).exe" -Force
        $GodotBin = "$($env:GODOT).exe"
    }
}

# Check for Godot executables in standard setup-godot directories
if (-not $GodotBin -or -not (Test-Path $GodotBin)) {
    $GodotExe = Get-ChildItem -Path "$env:USERPROFILE\godot" -Filter "Godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($GodotExe) {
        $GodotBin = $GodotExe.FullName
    }
}

# Check PATH
if (-not $GodotBin) {
    $Cmd = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($Cmd) {
        $GodotBin = $Cmd.Source
    }
}

if (-not $GodotBin) {
    $GodotBin = "godot"
}

Write-Host "Using Godot binary: $GodotBin"

# 5. Run Godot export
$ExportMode = if ($Debug) { "--export-debug" } else { "--export-release" }
Write-Host "Executing: $GodotBin --headless --path `"$RepoRoot`" $ExportMode `"$PresetName`" `"$ExePath`""

$StdOutLog = Join-Path $ResolvedOutputDir "godot_export_stdout.log"
$StdErrLog = Join-Path $ResolvedOutputDir "godot_export_stderr.log"

$ArgString = "--headless --path `"$RepoRoot`" $ExportMode `"$PresetName`" `"$ExePath`""
$p = Start-Process -FilePath $GodotBin -ArgumentList $ArgString -NoNewWindow -Wait -PassThru -RedirectStandardOutput $StdOutLog -RedirectStandardError $StdErrLog
$GodotExit = $p.ExitCode

Write-Host "Godot export exited with code: $GodotExit"

if (Test-Path $StdOutLog) {
    Write-Host "=== Godot stdout ==="
    Get-Content $StdOutLog | Write-Host
    Remove-Item $StdOutLog -Force
}
if (Test-Path $StdErrLog) {
    Write-Host "=== Godot stderr ==="
    Get-Content $StdErrLog | Write-Host
    Remove-Item $StdErrLog -Force
}

if ($GodotExit -ne 0) {
    Write-Error "Godot export failed with exit code $GodotExit"
    exit $GodotExit
}

# 6. Verify build outputs
if (-not (Test-Path $ExePath)) {
    Write-Error "Export failed: $ExePath was not produced."
    exit 1
}

Write-Host "Export binary produced: $ExePath"

# 7. Package into clean distribution archive
Write-Host "Packaging archive: $ArchivePath"
Push-Location $ResolvedOutputDir
try {
    $ArchiveFiles = @("game.exe")
    if (Test-Path "game.pck") {
        Write-Host "Including data pack: game.pck"
        $ArchiveFiles += "game.pck"
    }
    Compress-Archive -Path $ArchiveFiles -DestinationPath $ArchiveName -Force
} finally {
    Pop-Location
}

# 8. Generate and display SHA-256 hashes
Write-Host "Calculating SHA-256 checksums..."
$ChecksumLines = @()

$ExeHash = (Get-FileHash -Path $ExePath -Algorithm SHA256).Hash.ToLower()
$ChecksumLines += "$ExeHash  game.exe"
Write-Host "  game.exe: $ExeHash"

if (Test-Path $PckPath) {
    $PckHash = (Get-FileHash -Path $PckPath -Algorithm SHA256).Hash.ToLower()
    $ChecksumLines += "$PckHash  game.pck"
    Write-Host "  game.pck: $PckHash"
}

$ArchiveHash = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLower()
$ChecksumLines += "$ArchiveHash  $ArchiveName"
Write-Host ("  {0}: {1}" -f $ArchiveName, $ArchiveHash)

$ChecksumLines | Out-File -FilePath $ChecksumsPath -Encoding utf8 -Force
Write-Host "Checksums written to $ChecksumsPath"
Write-Host "=== Windows Export Complete ==="
exit 0
