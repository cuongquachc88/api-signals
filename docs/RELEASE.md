# Release process

Releases are automated with GitHub Actions. Maintainers tag a version; CI builds macOS and Windows installers and publishes a GitHub Release.

## Version numbers

Keep these in sync when bumping a release:

| File | Field |
| --- | --- |
| `tauri/package.json` | `"version"` |
| `tauri/src-tauri/Cargo.toml` | `version` |
| `tauri/src-tauri/tauri.conf.json` | `"version"` |

## Tag format

Push an annotated or lightweight tag:

```text
release-v1.0.0
```

Pattern matched by CI: `release-v*.*.*` (semver suffix).

Example:

```bash
git tag release-v1.0.0
git push origin release-v1.0.0
```

## Workflow

File: [`.github/workflows/release.yml`](../.github/workflows/release.yml)

1. **Trigger** — push of tag `release-v*.*.*`
2. **Build matrix**
   - `macos-latest` — Tauri build with `--target universal-apple-darwin` → `.dmg`, `.app`
   - `windows-latest` — Tauri build → `.msi`, NSIS `.exe`
3. **Release job** — downloads artifacts, attaches files to a GitHub Release, enables auto-generated release notes

## Artifacts

| Platform | Files |
| --- | --- |
| macOS | `.dmg`, optionally `.app` in artifact bundle |
| Windows | `.msi`, `.exe` (NSIS) |

## Pre-release checklist

- [ ] Changelog or release notes drafted (workflow can generate notes from merged PRs)
- [ ] Version bumped in all three manifest files
- [ ] `npm test` and `cargo test` pass locally
- [ ] CI green on `main`
- [ ] Tag pushed with `release-v` prefix

## Draft releases

To ship a pre-release, set `prerelease: true` in `release.yml` temporarily or edit the release in the GitHub UI after automation completes.

## CI vs release

| Workflow | When | Purpose |
| --- | --- | --- |
| [ci.yml](../.github/workflows/ci.yml) | Push/PR to `main` | Tests + verify cross-platform build |
| [release.yml](../.github/workflows/release.yml) | Version tags | Publish installers to GitHub Releases |
