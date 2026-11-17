#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
APP_BUNDLE="$PROJECT_ROOT/dist/Простой переводчик.app"
case "$MODE" in run|--verify|--debug|--logs|--telemetry|--build-only|--universal) ;; *) echo "Usage: $0 [--build-only|--universal|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;; esac
build_arch() {
    local arch="$1"
    swift build -c release --triple "$arch-apple-macosx14.0" \
        --scratch-path ".build/release-$arch" -debug-info-format none \
        -Xswiftc -file-prefix-map -Xswiftc "$PROJECT_ROOT=." \
        -Xswiftc -debug-prefix-map -Xswiftc "$PROJECT_ROOT=."
}
build_dir() {
    swift build -c release --triple "$1-apple-macosx14.0" \
        --scratch-path ".build/release-$1" --show-bin-path
}
HOST_ARCH="$(uname -m)"
build_arch "$HOST_ARCH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
if [[ "$MODE" == "--universal" ]]; then
    if [[ "$HOST_ARCH" == "arm64" ]]; then OTHER_ARCH=x86_64; else OTHER_ARCH=arm64; fi
    build_arch "$OTHER_ARCH"
    xcrun lipo -create \
        "$(build_dir arm64)/SimpleTranslator" \
        "$(build_dir x86_64)/SimpleTranslator" \
        -output "$APP_BUNDLE/Contents/MacOS/SimpleTranslator"
else
    cp "$(build_dir "$HOST_ARCH")/SimpleTranslator" "$APP_BUNDLE/Contents/MacOS/SimpleTranslator"
fi
xcrun strip -S "$APP_BUNDLE/Contents/MacOS/SimpleTranslator"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp docs/free-options-summary.json "$APP_BUNDLE/Contents/Resources/FreeOptions.json"
if [[ ! -f Resources/AppIcon.icns || script/generate_icon.swift -nt Resources/AppIcon.icns ]]; then
    mkdir -p .build/AppIcon.iconset
    swift script/generate_icon.swift .build/AppIcon.iconset
    iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
    cp .build/AppIcon.iconset/icon_512x512@2x.png Resources/AppIcon.png
fi
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
codesign --force --sign - --options runtime --entitlements Resources/Entitlements.plist "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"
case "$MODE" in
    --build-only|--universal) echo "$APP_BUNDLE" ;;
    --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/SimpleTranslator" ;;
    --logs|--telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "SimpleTranslator"' ;;
    --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x SimpleTranslator >/dev/null; echo "Application launched" ;;
    run) open -n "$APP_BUNDLE" ;;
esac
