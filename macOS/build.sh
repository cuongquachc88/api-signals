#!/usr/bin/env bash
# build.sh — release build + install + sign + open
set -euo pipefail

cd "$(dirname "$0")"

echo "▶ Building release..."
swift build -c release

echo "▶ Installing binary..."
cp -f .build/release/APISignalsApp "API Signals.app/Contents/MacOS/APISignals"

echo "▶ Signing..."
codesign --force --deep --sign - "API Signals.app"

echo "▶ Opening..."
open -n "API Signals.app"

echo "✓ Done."
