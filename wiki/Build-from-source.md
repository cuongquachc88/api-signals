# Build from source

See the canonical guide in the repository: [docs/BUILD.md](https://github.com/apisignals/api-signals/blob/main/docs/BUILD.md).

## Short version

```bash
cd tauri
npm ci
npm run tauri dev        # development
npm run tauri build      # local installers
```

**macOS:** Xcode Command Line Tools. Universal release: `npm run tauri build -- --target universal-apple-darwin`.

**Windows:** WebView2 + MSVC build tools. Artifacts under `tauri\src-tauri\target\release\bundle\`.
