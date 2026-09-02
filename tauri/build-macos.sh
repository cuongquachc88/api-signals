#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Installing dependencies..."
npm install
echo "Building macOS app (universal binary)..."
npm run tauri build -- --target universal-apple-darwin
echo "Done. App is at:"
echo "  src-tauri/target/universal-apple-darwin/release/bundle/macos/"
