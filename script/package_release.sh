#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
./script/build_and_run.sh --universal
APP_BUNDLE="dist/Simple Translator.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
ARCHIVE="Simple-Translator-$VERSION-macOS-universal.zip"
mkdir -p dist/releases
codesign --verify --deep --strict "$APP_BUNDLE"
[[ "$("$APP_BUNDLE/Contents/MacOS/SimpleTranslator" --version)" == "$VERSION" ]]
ARCHS="$(xcrun lipo -archs "$APP_BUNDLE/Contents/MacOS/SimpleTranslator")"
[[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]]
shopt -s nullglob
frameworks=(.build/release-"$(uname -m)"/artifacts/*/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework)
[[ ${#frameworks[@]} == 1 ]]
python3 script/package_zip.py "$APP_BUNDLE" "dist/releases/$ARCHIVE" "${frameworks[0]}"
cd dist/releases
shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt
echo "Created $ARCHIVE"
