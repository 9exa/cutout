#!/bin/bash
# Export script for Godot Asset Library
# Creates a clean ZIP file containing only the plugin files

set -e

PLUGIN_NAME="cutout"
VERSION="${1:-1.0.0}"
OUTPUT_DIR="asset_library_export"
ZIP_NAME="godot-${PLUGIN_NAME}-plugin-${VERSION}.zip"

echo "========================================="
echo "Cutout Plugin Export Script"
echo "========================================="
echo "Version: ${VERSION}"
echo "Output: ${OUTPUT_DIR}/${ZIP_NAME}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Clean previous export
rm -f "${OUTPUT_DIR}/${ZIP_NAME}"

echo "Creating plugin archive..."

# Create temporary directory for staging
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Copy plugin files
echo "  - Copying addons/${PLUGIN_NAME}/"
cp -r "addons/${PLUGIN_NAME}" "${TEMP_DIR}/"

# Copy required root files
echo "  - Copying LICENSE"
cp LICENSE "${TEMP_DIR}/"

echo "  - Copying README.md"
cp README.md "${TEMP_DIR}/"

# Create the ZIP file
echo "  - Creating ZIP archive..."
cd "${TEMP_DIR}"
zip -r -q "${ZIP_NAME}" ./*

# Move to output directory
mv "${ZIP_NAME}" "${OLDPWD}/${OUTPUT_DIR}/"
cd "${OLDPWD}"

# Show file size
FILE_SIZE=$(du -h "${OUTPUT_DIR}/${ZIP_NAME}" | cut -f1)

echo ""
echo "========================================="
echo "✓ Export successful!"
echo "========================================="
echo "File: ${OUTPUT_DIR}/${ZIP_NAME}"
echo "Size: ${FILE_SIZE}"
echo ""
echo "Contents:"
unzip -l "${OUTPUT_DIR}/${ZIP_NAME}" | head -20
echo ""
echo "This file is ready for upload to:"
echo "  - Godot Asset Library"
echo "  - GitHub Releases"
echo "  - itch.io"
echo ""
