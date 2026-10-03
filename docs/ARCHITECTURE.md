# Architecture

API Signals is a **Tauri 2** desktop application: a React frontend talks to a Rust backend over Tauri `invoke` commands. Data lives in **SQLite** under the OS app data directory.

## High-level diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Webview (React 18 + Vite + TypeScript)                      │
│  Zustand store · TanStack Query · CodeMirror editors         │
├─────────────────────────────────────────────────────────────┤
│  Tauri IPC (invoke / events)                                 │
├─────────────────────────────────────────────────────────────┤
│  Rust backend (tauri/src-tauri)                              │
│  commands/* · models · db (rusqlite)                         │
│  reqwest HTTP · axum mock server                             │
└─────────────────────────────────────────────────────────────┘
```

## Frontend (`tauri/src/`)

| Area | Role |
| --- | --- |
| `store/appStore.ts` | Workspaces, tabs, collections, UI state |
| `hooks/useRequest.ts` | Send requests via Tauri HTTP command |
| `components/*` | Request editor, response viewer, sidebar, tabs |
| `types/` | Shared TypeScript models aligned with Rust serde types |

The UI is offline-first: persistence goes through Rust commands, not browser storage.

## Backend (`tauri/src-tauri/src/`)

| Module | Role |
| --- | --- |
| `db.rs` | Schema migrations, SQLite connection |
| `models.rs` | Serde structs shared with the frontend |
| `commands/workspace.rs` | Workspace CRUD |
| `commands/collection.rs` | Collections and ordering |
| `commands/request.rs` | Saved requests |
| `commands/environment.rs` | Environments and active env |
| `commands/history.rs` | Request history |
| `commands/http.rs` | Outbound HTTP execution (reqwest) |
| `commands/import_export.rs` | cURL, Postman, HAR, OpenAPI |
| `commands/mock_server.rs` | Local stub server (axum) |
| `commands/snippet.rs` | Code snippet generation |
| `commands/settings.rs` | App settings |

On startup, `lib.rs` initializes the database in the Tauri app data directory and registers all command handlers.

## Data storage

- **Engine:** SQLite via `rusqlite` (bundled).
- **Location:** platform app data dir (`app.path().app_data_dir()`), file `api_signals.db`.
- **Export:** JSON / Postman / OpenAPI / HAR through import-export commands.

## HTTP execution

`commands/http::execute_request` builds a reqwest request from the saved request model (method, URL, headers, body, auth), executes it asynchronously, and returns status, headers, timing, and body to the UI.

## Variable resolution

Scope precedence (highest to lowest):

1. Request variables  
2. Collection variables  
3. Environment variables  
4. Global variables  

Syntax: `{{variableName}}`

## Scripting

Postman-compatible `pm.*` subset for pre-request and test scripts (see product README for supported APIs).

## Mock server

Routes are stored in SQLite; when started, an axum server listens on a configurable localhost port and returns configured status/body per route.

## Legacy Swift app

The [`../macOS/`](../macOS/) package implemented a similar feature set with Clean Architecture + GRDB. The Tauri app is the **active** release target; Swift modules are listed here only for historical comparison:

| Swift module | Tauri equivalent |
| --- | --- |
| APISignalsPersistence | `db.rs` + collection/request commands |
| APISignalsNetwork | `commands/http.rs` |
| APISignalsUI | `tauri/src/components/*` |

## Concurrency

- Rust: Tokio for async HTTP; `Mutex` around SQLite connection in Tauri state.
- Frontend: async invoke calls; React state updates on completion.
