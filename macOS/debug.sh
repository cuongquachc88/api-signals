#!/usr/bin/env bash
# debug.sh — debug build + install + sign + open
# For full debugger support, use: open Package.swift in Xcode → ⌘R
set -euo pipefail

cd "$(dirname "$0")"

echo "▶ Building debug..."
swift build

echo "▶ Installing binary..."
cp -f .build/debug/APISignalsApp "API Signals.app/Contents/MacOS/APISignals"

echo "▶ Signing..."
codesign --force --deep --sign - "API Signals.app"

echo "▶ Opening..."
open -n "API Signals.app"

echo "✓ Done. (Tip: open Package.swift in Xcode for breakpoints & debugger)"
