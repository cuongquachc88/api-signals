# Architecture

## Overview

API Signals follows Clean Architecture + MVVM on the presentation layer.

```
┌─────────────────────────────────────────┐
│  Presentation Layer (SwiftUI/AppKit)    │
│  - Views, ViewModels, Routing             │
├─────────────────────────────────────────┤
│  Domain Layer (Pure Swift)                │
│  - Entities, Use Cases, Repository Ifaces │
├─────────────────────────────────────────┤
│  Data Layer                               │
│  - SQLite repositories (GRDB.swift)       │
│  - File exporters (JSON, OpenAPI, HAR)    │
├─────────────────────────────────────────┤
│  Infrastructure Layer                     │
│  - Network engine (URLSession)            │
│  - JavaScriptCore runner                  │
│  - Auth handlers                          │
│  - Proxy / Certificate manager            │
└─────────────────────────────────────────┘
```

## Modules

| Module | Responsibility | Dependencies |
|---|---|---|
| `APISignalsCore` | Entities, repository protocols, domain errors | None |
| `APISignalsNetwork` | URLSession execution, request building, response mapping | Core |
| `APISignalsPersistence` | GRDB migrations, SQLite repositories, file export | Core, GRDB |
| `APISignalsScripting` | JavaScriptCore pre/post request scripts | Core |
| `APISignalsUI` | SwiftUI views and view models | Core, Network, Persistence |
| `APISignalsApp` | App entry, DI container, lifecycle | All above |

## Dependency Rule

- Domain layer does not depend on any other layer.
- Data and infrastructure layers depend on domain layer via protocols.
- UI layer depends on domain and concrete implementations.

## Concurrency

- Domain entities are `Sendable` and `Codable`.
- Network engine uses Swift actors for mutable state.
- Repositories use `async/await`.
- ViewModels use `@MainActor` for UI updates.

## Variable Resolution

Scope precedence (highest to lowest):
1. Request variables
2. Collection variables
3. Environment variables
4. Global variables

Syntax: `{{variableName}}`

## Scripting

Postman-compatible `pm.*` API subset:
- `pm.environment.get/set`
- `pm.variables.get/set`
- `pm.globals.get/set`
- `pm.request.*`
- `pm.response.*`
- `pm.test(name, fn)`
- `pm.expect(value)`

## GraphQL

Schema fetching and autocomplete are built into the GraphQL body editor:

- `GraphQLSchema` (Core) — type-safe model for types, fields, arguments, enums, input types.
- `GraphQLIntrospection` (Core) — standard introspection query string + JSON parser that unwraps `NON_NULL`/`LIST` wrappers to resolve leaf type names.
- `GraphQLSchemaFetcher` (Network) — Swift actor that POSTs the introspection query to the endpoint URL; caches results per URL; `invalidate(endpoint:)` forces a refresh.
- `GraphQLQueryEditor` (UI) — `NSTextView`-backed editor with syntax highlighting (keywords, directives, fields, variables, types, comments) and `NSTextViewDelegate` autocomplete using the fetched schema for context-aware field/type suggestions.

## Save Model

Requests are **not** auto-saved on every keystroke. Changes set a dirty flag (`isDirty`) which shows as a pulsing green dot on the tab. **⌘S** persists the request to SQLite and clears the dirty state. Sending a request also triggers a save.

## Tab Management

- `AppState.openTabs` — ordered list of open request tabs.
- `AppState.dirtyTabIds: Set<UUID>` — tracks which tabs have unsaved changes.
- Double-clicking a tab label opens an inline `TextField` for renaming; `Return` commits, `Escape` cancels.

