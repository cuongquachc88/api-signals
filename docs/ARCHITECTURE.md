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

