#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:?Expected the built Finder2right.app path}"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == local.finder2right ]]
LAUNCHER="$APP/Contents/Helpers/Finder2right Launcher.app"
WORK="$(mktemp -d "${DERIVED_FILE_DIR:-${TMPDIR:-/tmp}}/finder2right-launcher.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$LAUNCHER/Contents/MacOS" "$LAUNCHER/Contents/Resources"
cp Finder2right/ToolbarLauncher/Info.plist "$LAUNCHER/Contents/Info.plist"
for KEY in CFBundleShortVersionString CFBundleVersion LSMinimumSystemVersion; do
    VALUE="$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$APP/Contents/Info.plist")"
    /usr/libexec/PlistBuddy -c "Add :$KEY string $VALUE" "$LAUNCHER/Contents/Info.plist"
done
MINIMUM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
BINARIES=()
for ARCH in $(lipo -archs "$APP/Contents/MacOS/Finder2right"); do
    xcrun swiftc -O -target "$ARCH-apple-macosx$MINIMUM" Finder2right/ToolbarLauncher/main.swift -o "$WORK/$ARCH"
    BINARIES+=("$WORK/$ARCH")
done
lipo -create "${BINARIES[@]}" -output "$LAUNCHER/Contents/MacOS/Finder2rightLauncher"
cp "$APP/Contents/Resources/AppIcon.icns" "$LAUNCHER/Contents/Resources/AppIcon.icns"
codesign --force --sign - --timestamp=none "$LAUNCHER"
