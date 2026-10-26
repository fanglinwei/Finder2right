#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${FINDER2RIGHT_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/tests
xcrun swiftc Shared/FinderRequest.swift Shared/FileCreation.swift Shared/FileTypes.swift Shared/TerminalCommands.swift App/ConfigurationStores.swift Tests/main.swift -o build/tests/FileCreationTests
build/tests/FileCreationTests
