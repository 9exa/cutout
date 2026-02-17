# Build script for cutout-gdext GDExtension
# Usage: .\build.ps1 [debug|release]

param(
    [string]$Profile = "release"
)

$ErrorActionPreference = "Stop"

Write-Host "Building cutout-gdext ($Profile)..." -ForegroundColor Cyan

# Build the library
if ($Profile -eq "release") {
    cargo build --release
} else {
    cargo build
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    exit 1
}

Write-Host ""
Write-Host "Copying library to addon bin directory..." -ForegroundColor Cyan

# Run the copy script
& "$PSScriptRoot\copy_lib.ps1" -Profile $Profile

if ($LASTEXITCODE -ne 0) {
    Write-Error "Copy failed!"
    exit 1
}

Write-Host ""
Write-Host "Build complete! Library ready for Godot." -ForegroundColor Green
