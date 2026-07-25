# API Signals

A native, open-source API client for macOS and Windows.

> ⚠️ This project is currently in planning phase. See [PROJECT_PLAN.md](./PROJECT_PLAN.md) for the full development roadmap.

## Vision

API Signals is a fast, native, offline-first API client inspired by Postman. It focuses on a polished macOS experience first, then brings feature parity to Windows.

- **Native first**: SwiftUI + AppKit on macOS, WinUI 3 on Windows.
- **Offline first**: Local SQLite storage, no cloud required.
- **File-based**: Export/import workspaces, collections, and environments.
- **Open source**: MIT license.

## Platforms

| Platform | Status | Stack |
|---|---|---|
| macOS | Planning | Swift, SwiftUI, AppKit, GRDB |
| Windows | Planning | C#, WinUI 3 |

## Current Status

MVP is implemented for macOS:
- Request editor with URL, method, headers, query params, body, auth.
- Response viewer with pretty JSON, headers, cookies, status, timing, size.
- Collections, environments, history.
- Local SQLite persistence with GRDB.
- Native `.apisignals.json` export/import.

## Planned Features

- HTTP/HTTPS requests (GET, POST, PUT, DELETE, PATCH, etc.)
- Headers, query params, form-data, URL-encoded, raw, JSON, GraphQL bodies
- Authentication: Bearer, Basic, API Key, OAuth 2.0, OAuth 1.0, Digest, NTLM, AWS Signature
- Collections, folders, and request history
- Environments and variables (`{{variable}}`)
- Pre-request and post-response scripts (Postman-compatible `pm.*` subset)
- Response viewer with JSON, XML, HTML, image, and raw modes
- Import/Export: Postman Collection v2.1, cURL, OpenAPI 3.0, HAR
- WebSocket and Server-Sent Events support
- Proxy and SSL client certificate support
- Collection runner

## Repository Layout

```
api-signals/
├── docs/              # Documentation
├── macOS/             # macOS app (Swift, SPM, Xcode)
├── windows/           # Windows app (C#, WinUI 3)
├── shared/            # Shared specs and JSON schemas
├── tests/             # Cross-platform tests
├── PROJECT_PLAN.md    # Detailed plan
├── README.md          # This file
└── LICENSE            # MIT
```

## License

MIT License — see [LICENSE](./LICENSE) for details.

## Contributing

Contributions are welcome! Please check [PROJECT_PLAN.md](./PROJECT_PLAN.md) and open an issue before starting major work.
