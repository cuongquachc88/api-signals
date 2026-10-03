# Contributing

Thank you for contributing to API Signals.

## Code of conduct

Participation is governed by the [Code of Conduct](../CODE_OF_CONDUCT.md). Be respectful and constructive.

## Getting started

### Requirements

| Tool | Notes |
| --- | --- |
| Node.js 20+ | Frontend build and Tauri CLI |
| Rust 1.77+ | Backend and Tauri shell |
| macOS or Windows | Linux is supported for tests only (no desktop bundle in CI matrix) |

Platform-specific tooling: [BUILD.md](./BUILD.md).

### Setup

```bash
git clone https://github.com/apisignals/api-signals.git
cd api-signals/tauri
npm ci
npm run tauri dev
```

### Tests

```bash
cd tauri
npm test
cd src-tauri && cargo test
```

CI runs the same checks on every pull request — see [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Project structure

```
tauri/
├── src/              # React UI (TypeScript, Zustand, CodeMirror)
├── src-tauri/src/    # Tauri commands, HTTP, SQLite, import/export
└── src-tauri/        # Tauri config, icons, Capabilities
docs/                 # Documentation (you are here)
macOS/                # Legacy Swift app — avoid unless explicitly scoped
```

## Pull request process

1. Open an issue for large features or breaking changes (optional for small fixes).
2. Fork, branch from `main`, keep commits focused.
3. Update docs when behavior or build steps change.
4. Ensure tests pass locally.
5. Open a PR with:
   - **What** changed
   - **Why** it is needed
   - **How** you tested (OS, commands)

Use [Conventional Commits](https://www.conventionalcommits.org/) when possible:

```text
feat: add HAR export for single request
fix: normalize Content-Type on form uploads
docs: document Windows WebView2 requirement
test: cover Postman import edge cases
```

## Code style

- **TypeScript / React** — match existing patterns in `tauri/src/`; run `npm run build` for typecheck.
- **Rust** — idiomatic Rust 2021; keep Tauri commands thin and test pure logic where practical.
- **Scope** — prefer small PRs; avoid unrelated refactors.

## Security

Report vulnerabilities privately — see [SECURITY.md](../SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the [MIT License](../LICENSE).
