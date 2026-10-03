# Architecture

Full document: [docs/ARCHITECTURE.md](https://github.com/apisignals/api-signals/blob/main/docs/ARCHITECTURE.md).

Tauri splits the app into a React webview and a Rust backend connected by `invoke` commands. SQLite stores workspaces, collections, requests, and history locally.

Key Rust modules: `commands/http`, `commands/import_export`, `commands/mock_server`, `db`, `models`.
