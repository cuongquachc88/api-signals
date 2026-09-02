#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Installing dependencies..."
npm install
echo "Building Windows installer..."
npm run tauri build -- --target x86_64-pc-windows-msvc
echo "Done. Installer at:"
echo "  src-tauri/target/x86_64-pc-windows-msvc/release/bundle/msi/"
