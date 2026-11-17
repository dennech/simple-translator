#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
./script/build_and_run.sh --universal
APP_BUNDLE="dist/Простой переводчик.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
ARCHIVE="Simple-Translator-$VERSION-macOS-universal.zip"
mkdir -p dist/releases
codesign --verify --strict "$APP_BUNDLE"
ARCHS="$(xcrun lipo -archs "$APP_BUNDLE/Contents/MacOS/SimpleTranslator")"
[[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]]
python3 script/package_zip.py "$APP_BUNDLE" "dist/releases/$ARCHIVE"
cd dist/releases
shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt
echo "Created $ARCHIVE"
