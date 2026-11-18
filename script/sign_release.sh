#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tools="${1:?Pass the bin directory of the official Sparkle distribution}"
account=app.simpletranslator.mac
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
public_key=$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' Resources/Info.plist)
[[ "$("$tools/generate_keys" --account "$account" -p)" == "$public_key" ]] || {
    echo "The signing key must match the public key in Info.plist." >&2
    exit 1
}
archive="Simple-Translator-$version-macOS-universal.zip"
(cd dist/releases && shasum -a 256 -c SHA256SUMS.txt)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp "dist/releases/$archive" "$stage/"
"$tools/generate_appcast" --account "$account" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/dennech/simple-translator/releases/download/v$version/" "$stage"
"$tools/sign_update" --account "$account" --verify "$stage/appcast.xml"
cp "$stage/appcast.xml" dist/releases/appcast.xml
