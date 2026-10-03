# Release process

Maintainers only. Canonical doc: [docs/RELEASE.md](https://github.com/apisignals/api-signals/blob/main/docs/RELEASE.md).

1. Bump version in `tauri/package.json`, `tauri/src-tauri/Cargo.toml`, and `tauri/src-tauri/tauri.conf.json`.
2. Merge to `main`, ensure CI is green.
3. Tag and push: `git tag release-v1.0.0 && git push origin release-v1.0.0`
4. GitHub Actions builds macOS (`.dmg`) and Windows (`.msi`, `.exe`) and creates a Release.
