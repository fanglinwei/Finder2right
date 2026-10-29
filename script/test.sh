#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${FINDER2RIGHT_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/tests
xcrun swiftc Finder2right/Shared/*.swift Finder2right/App/ConfigurationStores.swift Finder2right/Tests/main.swift -o build/tests/FileCreationTests
build/tests/FileCreationTests

xcrun swiftc Finder2right/Shared/*.swift Finder2right/App/AppDelegate.swift Finder2right/App/TerminalCommandAlert.swift Finder2right/App/ConfigurationStores.swift Finder2right/App/MainView.swift Finder2right/App/FileTypesView.swift Finder2right/App/TerminalCommandsView.swift Finder2right/App/LauncherSettingsView.swift Finder2right/Tests/ToolbarLauncher/main.swift -o build/tests/ToolbarLauncherTests
build/tests/ToolbarLauncherTests
