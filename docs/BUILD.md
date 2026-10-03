# Build guide

API Signals ships as a **Tauri 2** desktop app. All commands below assume the repository root unless noted.

## Prerequisites (all platforms)

| Tool | Version |
| --- | --- |
| Node.js | 20 LTS |
| npm | 10+ (bundled with Node) |
| Rust | ≥ 1.77 ([rustup](https://rustup.rs/)) |

Clone and install frontend tooling once:

```bash
cd tauri
npm ci
```

## macOS

### Requirements

- macOS 12+
- **Xcode Command Line Tools** — `xcode-select --install`

### Development

```bash
cd tauri
npm run tauri dev
```

### Release bundle (local)

Universal binary (Apple Silicon + Intel), DMG and `.app`:

```bash
cd tauri
npm run tauri build -- --target universal-apple-darwin
```

Artifacts (typical paths):

- `tauri/src-tauri/target/universal-apple-darwin/release/bundle/dmg/*.dmg`
- `tauri/src-tauri/target/universal-apple-darwin/release/bundle/macos/*.app`

Single-architecture (faster local iteration on Apple Silicon):

```bash
cd tauri
npm run tauri build
```

### Code signing (optional)

For distribution outside your machine, sign and notarize with your Apple Developer ID. CI builds are ad-hoc unsigned; users may need to allow the app under **Privacy & Security**.

## Windows

### Requirements

- Windows 10/11 x64
- **[WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)** runtime (included on most Windows 11 installs)
- **Visual Studio Build Tools** with the **Desktop development with C++** workload (for the MSVC linker)

Install Rust MSVC target (if not already default):

```powershell
rustup default stable-msvc
```

### Development

```powershell
cd tauri
npm run tauri dev
```

### Release bundle (local)

```powershell
cd tauri
npm run tauri build
```

Artifacts (typical paths):

- `tauri\src-tauri\target\release\bundle\msi\*.msi`
- `tauri\src-tauri\target\release\bundle\nsis\*.exe`

## Tests

```bash
# Frontend (Vitest)
cd tauri && npm test

# Rust
cd tauri/src-tauri && cargo test
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `linker 'cc' not found` (macOS) | Install Xcode CLT |
| WebView2 missing (Windows) | Install Evergreen WebView2 bootstrapper |
| `npm run tauri` not found | Run from `tauri/` after `npm ci` |
| Slow first Rust build | Normal; later builds use `target/` cache |

## Legacy Swift macOS app

The [`../macOS/`](../macOS/) tree is an earlier native Swift implementation. It is **not** built by CI or release workflows. To build it:

```bash
cd macOS
swift build -c release
```

See the historical README section in git history if you still rely on that stack.
