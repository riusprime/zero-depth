# Ported from riusprime/deathventory@1d697803:scripts/verify.ps1.
# Changes: import first; --fixed-fps 60; JUnit output; summary guards (passing count, error strings).
param(
    [string]$TestDirectory = "res://tests"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
Set-Location $RepoRoot
New-Item -ItemType Directory -Force -Path build | Out-Null
# On CI the console wrapper is called by full path (it can't be renamed); locally `godot` on PATH works.
$Godot = if ($env:GODOT_CONSOLE) { $env:GODOT_CONSOLE } else { "godot" }

& $Godot --headless --path . --editor --import --quit *> build/import.log
$importErrors = Select-String -Path build/import.log -Pattern '^(ERROR|SCRIPT ERROR)'
if ($importErrors) { $importErrors | Select-Object -First 10; Write-Error "verify: import reported errors" }

& $Godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd "-gdir=$TestDirectory" -ginclude_subdirs `
    "-gjunit_xml_file=build/gut.xml" -gexit *> build/gut.log
$gutExit = $LASTEXITCODE
Get-Content build/gut.log
if ($gutExit -ne 0) { exit $gutExit }

$log = (Get-Content build/gut.log -Raw) -replace '\x1B\[[0-9;]*[mK]', ''
if ($log -notmatch 'Passing Tests\s+(\d+)') { Write-Error "verify: no GUT summary" }
$passing = [int]$Matches[1]
foreach ($p in @('SCRIPT ERROR', 'Parse Error', 'Failed to load script', '\[GUT ERROR\]')) {
    if ($log -match $p) { Write-Error "verify: log contains '$p'" }
}
if ($TestDirectory -eq "res://tests") {
    $min = [int](Get-Content tests/MIN_TEST_COUNT -Raw).Trim()
    if ($passing -lt $min) { Write-Error "verify: $passing passing tests, below the minimum of $min" }
}
Write-Output "verify: ok ($passing passing)"
exit 0
