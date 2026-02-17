#!/usr/bin/env bash
# Copy the compiled Rust library to the Godot addon bin directory.
# Usage: ./copy_lib.sh [debug|release]

set -euo pipefail

PROFILE="${1:-debug}"

SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

TARGET_DIR="$SCRIPT_DIR/target"
BIN_DIR="$PROJECT_ROOT/bin"

# Detect platform
case "$(uname -s)" in
    Linux*)
        PLATFORM="linux"
        LIB_PREFIX="lib"
        LIB_EXT="so"
        ARCH="x86_64"
        ;;
    Darwin*)
        PLATFORM="macos"
        LIB_PREFIX="lib"
        LIB_EXT="dylib"
        # macOS target uses 'universal' in the filename per cutout.gdextension
        ARCH="universal"
        ;;
    *)
        echo "Unsupported platform: $(uname -s)" >&2
        exit 1
        ;;
esac

# Determine template type
if [[ "$PROFILE" == "release" ]]; then
    TEMPLATE="template_release"
else
    TEMPLATE="template_debug"
fi

# Cargo converts hyphens to underscores in output library names
SOURCE_LIB="$TARGET_DIR/$PROFILE/${LIB_PREFIX}cutout_gdext.$LIB_EXT"

# Destination name matches what cutout.gdextension expects
DEST_LIB="libcutout.$PLATFORM.$TEMPLATE.$ARCH.$LIB_EXT"
DEST_PATH="$BIN_DIR/$DEST_LIB"

if [[ ! -f "$SOURCE_LIB" ]]; then
    echo "Error: source library not found: $SOURCE_LIB" >&2
    if [[ "$PROFILE" == "release" ]]; then
        echo "Please run 'cargo build --release' first." >&2
    else
        echo "Please run 'cargo build' first." >&2
    fi
    exit 1
fi

mkdir -p "$BIN_DIR"

echo "Copying $SOURCE_LIB"
echo "     to $DEST_PATH"
cp "$SOURCE_LIB" "$DEST_PATH"

echo "Library copied successfully."
