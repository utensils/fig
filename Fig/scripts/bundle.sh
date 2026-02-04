#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$PROJECT_ROOT")"

# Change to project root where Package.swift lives
cd "$PROJECT_ROOT"

# Absolute path for output
ABS_BUILD_DIR="$(pwd)/.build"

CONFIG="${1:-debug}"

# Build the executable
echo "Building Fig (${CONFIG})..."
swift build -c "${CONFIG}" --quiet
APP_NAME="Fig"
BUNDLE_DIR=".build/${CONFIG}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Create bundle structure
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp ".build/${CONFIG}/${APP_NAME}" "${MACOS_DIR}/"

# Copy entitlements if they exist
if [ -f "Fig.entitlements" ]; then
	cp "Fig.entitlements" "${CONTENTS_DIR}/"
fi

# Create app icon from fig-logo.png
LOGO_PATH="${REPO_ROOT}/docs/public/fig-logo.png"
if [ -f "$LOGO_PATH" ]; then
	ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
	mkdir -p "$ICONSET_DIR"

	# Generate all required icon sizes
	sips -z 16 16 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
	sips -z 32 32 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
	sips -z 32 32 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
	sips -z 64 64 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
	sips -z 128 128 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
	sips -z 256 256 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
	sips -z 256 256 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
	sips -z 512 512 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
	sips -z 512 512 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
	sips -z 1024 1024 "$LOGO_PATH" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

	# Convert iconset to icns
	iconutil -c icns "$ICONSET_DIR" -o "${RESOURCES_DIR}/AppIcon.icns"
	rm -rf "$(dirname "$ICONSET_DIR")"
	echo "Created app icon from fig-logo.png"
fi

# Create Info.plist
cat >"${CONTENTS_DIR}/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>io.utensils.fig</string>
    <key>CFBundleName</key>
    <string>Fig</string>
    <key>CFBundleDisplayName</key>
    <string>Fig</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Fig</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign the bundle
codesign --force --deep --sign - "${BUNDLE_DIR}" 2>/dev/null

echo "Run: open ${ABS_BUILD_DIR}/${CONFIG}/${APP_NAME}.app"
