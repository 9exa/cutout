#!/usr/bin/env bash
# Build script for cutout-gdext GDExtension.
# Usage: ./build.sh [debug|release]

set -euo pipefail

PROFILE="${1:-release}"

SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "Building cutout-gdext ($PROFILE)..."

cd "$SCRIPT_DIR"

if [[ "$PROFILE" == "release" ]]; then
    cargo build --release
else
    cargo build
fi

echo ""
echo "Copying library to addon bin directory..."

bash "$SCRIPT_DIR/copy_lib.sh" "$PROFILE"

echo ""
echo "Build complete. Library ready for Godot."
