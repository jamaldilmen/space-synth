#!/bin/bash
set -e

APP_NAME="SpaceSynth"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_NAME}.app..."

# 1. Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 2. Build the project
echo "🔨 Building project..."
# `build/` is gitignored, so it does NOT exist in a fresh clone or a new git
# worktree. Without this mkdir the `cd build` below fails, `set -e` aborts the
# script — and because SpaceSynth.app IS tracked in git, the tree still contains
# the COMMITTED binary. You get a failed build sitting next to an app bundle that
# looks perfectly valid, i.e. the 2026-06-14 stale-binary trap with a new cause.
# Found 2026-08-10 10:38:24 setting up the camera worktree.
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)
cd ..

# 3. Copy binary and assets
echo "🚚 Copying files..."
cp build/SpaceSynth "${MACOS_DIR}/"
strip -x "${MACOS_DIR}/SpaceSynth"

cp build/default.metallib "${RESOURCES_DIR}/"
cp -r presets "${RESOURCES_DIR}/"

# Embed Syphon.framework (if present) so the @rpath/Syphon load resolves.
if [ -d third_party/syphon/Syphon.framework ]; then
  echo "🔌 Embedding Syphon.framework..."
  mkdir -p "${CONTENTS_DIR}/Frameworks"
  ditto third_party/syphon/Syphon.framework "${CONTENTS_DIR}/Frameworks/Syphon.framework"
fi
mkdir -p "${RESOURCES_DIR}/fonts"
cp third_party/imgui/misc/fonts/Roboto-Medium.ttf "${RESOURCES_DIR}/fonts/"
# cp src/ui/fonts/*.ttf "${RESOURCES_DIR}/"

# 4. Create Info.plist
echo "📝 Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.airy.spacesynth</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ ${APP_NAME}.app created successfully!"
echo "🚀 You can now share this with your friends!"
