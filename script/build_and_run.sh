#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${FINDER2RIGHT_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
MODE="${1:-run}"
case "$MODE" in run|--verify|--build|--debug|--logs) ;; *) echo "Usage: $0 [--build|--verify|--debug|--logs]" >&2; exit 2;; esac
if [[ "$MODE" != --build ]]; then pkill -x Finder2right || true; fi
xcodebuild -project Finder2right.xcodeproj -scheme Finder2right -configuration Debug -derivedDataPath build build
APP="$PWD/build/Build/Products/Debug/Finder2right.app"
case "$MODE" in
  --build) ;;
  --debug) lldb "$APP/Contents/MacOS/Finder2right" ;;
  --logs) open "$APP"; /usr/bin/log stream --info --predicate 'process == "Finder2right" OR process == "FinderExtension"' ;;
  --verify) open "$APP"; sleep 2; pgrep -x Finder2right ;;
  run) open "$APP" ;;
esac
