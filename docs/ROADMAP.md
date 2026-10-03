# Roadmap

Cross-platform delivery (Tauri on **macOS** and **Windows**) is the current focus. Items below mix shipped capabilities and planned work.

## Platform

- [x] Tauri 2 app (React + Rust)
- [x] macOS universal builds (CI + release)
- [x] Windows MSI / NSIS builds (CI + release)
- [ ] Linux packages (AppImage/deb) — not in CI yet
- [ ] Auto-update channel

## Core HTTP client

- [x] Methods, headers, query, body, auth
- [x] Response viewer (JSON, headers, timing)
- [x] cURL import/export
- [x] Postman Collection v2.1 import/export
- [x] OpenAPI and HAR import
- [x] WebSocket and SSE
- [x] GraphQL editor with introspection
- [ ] Proxy support
- [ ] Client TLS certificates

## Workspace & UX

- [x] Workspaces, collections, environments, history
- [x] Multi-tab editor with dirty indicator and ⌘S save
- [x] Command palette
- [x] Mock server
- [x] Collection documentation (Markdown)
- [ ] Image/PDF response preview
- [ ] Team sharing via file sync

## Quality & community

- [x] Frontend unit tests (Vitest)
- [x] Rust unit tests (import/export, HTTP helpers)
- [x] CI: test + macOS/Windows build on `main`
- [x] Release workflow on version tags
- [ ] Expanded E2E tests
- [ ] Contributor onboarding video / wiki tour

## Legacy macOS (Swift)

The Swift/SwiftUI app in `macOS/` remains in the repo for reference. New features should land in `tauri/` unless explicitly maintaining the Swift stack.
