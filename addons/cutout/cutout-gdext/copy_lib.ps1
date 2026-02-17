# PowerShell script to copy the compiled library to the Godot addon bin directory
# Usage: .\copy_lib.ps1 [debug|release]

param(
    [string]$Profile = "debug"
)

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Source and destination paths
$TargetDir = Join-Path $ScriptDir "target"
$BinDir = Join-Path $ProjectRoot "bin"

# Platform-specific settings (use built-in $IsWindows, $IsMacOS, $IsLinux variables)
if ($IsWindows) {
    $Platform = "windows"
    $LibPrefix = ""
    $LibExtension = "dll"
} elseif ($IsMacOS) {
    $Platform = "macos"
    $LibPrefix = "lib"
    $LibExtension = "dylib"
} else {
    $Platform = "linux"
    $LibPrefix = "lib"
    $LibExtension = "so"
}

$Arch = "x86_64"

# Determine template type
$Template = if ($Profile -eq "debug") { "template_debug" } else { "template_release" }

# Source library path (Cargo converts hyphens to underscores in library names)
$SourceLib = Join-Path (Join-Path $TargetDir $Profile) "${LibPrefix}cutout_gdext.$LibExtension"

# Destination library name
$DestLib = "libcutout.$Platform.$Template.$Arch.$LibExtension"
$DestPath = Join-Path $BinDir $DestLib

# Check if source exists
if (-not (Test-Path $SourceLib)) {
    Write-Error "Source library not found: $SourceLib"
    Write-Host "Please run 'cargo build $(if ($Profile -eq 'release') {'--release'})' first"
    exit 1
}

# Create bin directory if it doesn't exist
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
    Write-Host "Created bin directory: $BinDir"
}

# Copy the library
Write-Host "Copying $SourceLib"
Write-Host "     to $DestPath"
Copy-Item -Path $SourceLib -Destination $DestPath -Force

Write-Host "✓ Library copied successfully!" -ForegroundColor Green
