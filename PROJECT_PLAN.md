# API Signals - Kế hoạch phát triển

> Postman-like API client — Native macOS first, Windows later. Open source.

---

## 1. Tổng quan sản phẩm

### 1.1. Tên dự án
**API Signals** (working name, có thể đổi)

### 1.2. Trạng thái hiện tại
MVP đã được implement:
- Native macOS SwiftUI app với request editor, response viewer, collections, environments, history.
- URLSession network engine hỗ trợ GET/POST/PUT/DELETE/PATCH và các body types.
- Variable resolver (`{{variable}}`), Bearer/Basic/API Key auth, query params, headers.
- SQLite persistence (GRDB) cho workspaces, collections, requests, environments, history.
- Export/import workspace JSON từ menu.
- Unit tests skeleton cho core, network, persistence.

### 1.3. Mục tiêu
Xây dựng một API client mạnh mẽ, native, mã nguồn mở, hoạt động offline, tập trung vào trải nghiệm macOS trước, sau đó port sang Windows. Hướng đến developer cá nhân và team nhỏ cần công cụ debug/test API nhanh, nhẹ, không phụ thuộc cloud.

### 1.3. Đặc điểm chính
| Thuộc tính | Lựa chọn |
|---|---|
| Platform | macOS native (primary), Windows native (secondary) |
| UI Framework | SwiftUI + AppKit (macOS) / WinUI 3 (Windows) |
| Ngôn ngữ | Swift (macOS), C# (Windows) |
| Networking | `URLSession` + custom `URLProtocol` cho proxy/cert |
| Scripting/Tests | `JavaScriptCore` (macOS) / V8/JS engine (Windows) |
| Storage | SQLite local + file-based export/import |
| License | MIT (open source) |
| Cloud | Không có cloud, hoàn toàn offline |
| Import/Export | Postman Collection v2.1, OpenAPI 3.0, cURL, HAR |

---

## 2. Kiến trúc tổng thể

### 2.1. Clean Architecture + MVVM

```
┌─────────────────────────────────────────┐
│  Presentation Layer (SwiftUI/AppKit)    │
│  - Views, ViewModels, Routing             │
├─────────────────────────────────────────┤
│  Domain Layer (Pure Swift)                │
│  - Entities, Use Cases, Repository Protocols│
├─────────────────────────────────────────┤
│  Data Layer                               │
│  - SQLite repositories (GRDB.swift)       │
│  - File exporters (JSON, YAML, OpenAPI) │
├─────────────────────────────────────────┤
│  Infrastructure Layer                   │
│  - Network engine (URLSession)            │
│  - JavaScriptCore runner                  │
│  - Auth handlers                          │
│  - Proxy / Certificate manager            │
└─────────────────────────────────────────┘
```

### 2.2. Module chính (macOS)

| Module | Mô tả |
|---|---|
| `APISignalsCore` | Entities, Use Cases, Repository Interfaces |
| `APISignalsNetwork` | Networking engine, request builder, response parser |
| `APISignalsPersistence` | GRDB + SQLite schema, file exporters |
| `APISignalsScripting` | JavaScriptCore runner cho pre/post scripts |
| `APISignalsUI` | SwiftUI views, AppKit bridges |
| `APISignalsApp` | App entry point, DI container, lifecycle |

### 2.3. Chiến lược Windows sau này

- **Cách 1 (khuyên dùng):** Viết lại UI bằng WinUI 3 + C#, nhưng tái sử dụng spec/domain logic đã design từ macOS.
- **Cách 2:** Dùng .NET MAUI nhưng có thể compromise native feel.
- **Cách 3:** Swift on Windows (không ổn định, tránh).

**Quyết định:** Cách 1. Cùng một domain model, hai implementation UI khác nhau.

---

## 3. Tech Stack chi tiết

### 3.1. macOS
| Thành phần | Công nghệ |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI (primary), AppKit (custom controls) |
| Concurrency | Swift Concurrency (`async/await`) |
| Dependency | Swift Package Manager |
| Database | SQLite + GRDB.swift |
| Networking | URLSession, URLProtocol |
| Scripting | JavaScriptCore |
| JSON parsing | Codable |
| Testing | XCTest, Swift Testing |
| CI/CD | GitHub Actions |
| Packaging | `.dmg`, Homebrew cask, Mac App Store (optional) |

### 3.2. Dependencies (SPM)
```swift
// Package.swift
.package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
.package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"), // optional
```

Hạn chế dependencies để dễ bảo trì.

### 3.3. Windows
| Thành phần | Công nghệ |
|---|---|
| Language | C# |
| UI | WinUI 3 / Windows App SDK |
| Database | SQLite + SQLitePCLRaw |
| Networking | HttpClient + custom handlers |
| Scripting | ClearScript/V8 hoặc Jint |
| Packaging | MSIX, winget |

---

## 4. Data Model (Core Entities)

### 4.1. Workspace
```swift
struct Workspace: Identifiable {
    let id: UUID
    var name: String
    var collections: [Collection]
    var environments: [Environment]
    var createdAt: Date
    var updatedAt: Date
}
```

### 4.2. Collection
```swift
struct Collection: Identifiable {
    let id: UUID
    var name: String
    var description: String?
    var children: [CollectionItem] // folder hoặc request
    var variables: [Variable]
    var auth: Auth?
    var preRequestScript: String?
    var postResponseScript: String?
}

indirect enum CollectionItem: Identifiable {
    case request(APIRequest)
    case folder(name: String, children: [CollectionItem])
}
```

### 4.3. Request
```swift
struct APIRequest: Identifiable {
    let id: UUID
    var name: String
    var method: HTTPMethod
    var url: URLComponents
    var headers: [Header]
    var queryParams: [Parameter]
    var body: RequestBody?
    var auth: Auth?
    var scripts: Scripts?
    var settings: RequestSettings
}

enum RequestBody {
    case none
    case raw(text: String, mimeType: MIMEType)
    case json(String)
    case formData([FormField])
    case urlEncoded([Parameter])
    case binary(Data)
    case multipart(MultipartBody)
    case graphql(query: String, variables: String)
}
```

### 4.4. Response
```swift
struct APIResponse {
    let statusCode: Int
    let statusText: String
    let headers: [Header]
    let body: Data?
    let mimeType: String?
    let timing: RequestTiming
    let size: ResponseSize
    let cookies: [Cookie]
    let certificate: CertificateInfo?
}

struct RequestTiming {
    let dns: TimeInterval?
    let connect: TimeInterval?
    let tls: TimeInterval?
    let ttfb: TimeInterval
    let download: TimeInterval
    let total: TimeInterval
}
```

### 4.5. Environment
```swift
struct Environment: Identifiable {
    let id: UUID
    var name: String
    var variables: [Variable]
    var isActive: Bool
}

struct Variable: Identifiable {
    let id: UUID
    var key: String
    var value: String
    var type: VariableType // default, secret
    var isEnabled: Bool
}
```

### 4.6. Auth
```swift
enum Auth {
    case none
    case bearer(token: String)
    case basic(username: String, password: String)
    case apiKey(key: String, value: String, location: APIKeyLocation)
    case oauth2(OAuth2Config)
    case oauth1(OAuth1Config)
    case digest(username: String, password: String)
    case ntlm(username: String, password: String, domain: String?)
    case awsSignature(AWSSignatureConfig)
}
```

### 4.7. History
```swift
struct HistoryEntry: Identifiable {
    let id: UUID
    let request: APIRequest
    let response: APIResponse?
    let timestamp: Date
    let workspaceId: UUID
}
```

---

## 5. Database Schema (SQLite)

```sql
CREATE TABLE workspaces (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

CREATE TABLE collections (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    parent_id TEXT,
    sort_order INTEGER NOT NULL,
    variables_json TEXT,
    auth_json TEXT,
    pre_request_script TEXT,
    post_response_script TEXT,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE TABLE requests (
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    name TEXT NOT NULL,
    method TEXT NOT NULL,
    url TEXT NOT NULL,
    headers_json TEXT,
    query_params_json TEXT,
    body_json TEXT,
    auth_json TEXT,
    scripts_json TEXT,
    settings_json TEXT,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (collection_id) REFERENCES collections(id)
);

CREATE TABLE environments (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    name TEXT NOT NULL,
    is_active INTEGER NOT NULL,
    variables_json TEXT,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE TABLE history (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    request_json TEXT NOT NULL,
    response_json TEXT,
    timestamp REAL NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id)
);

CREATE INDEX idx_requests_collection ON requests(collection_id);
CREATE INDEX idx_history_workspace ON history(workspace_id);
CREATE INDEX idx_history_timestamp ON history(timestamp);
```

---

## 6. Feature Breakdown

### 6.1. MVP (Phase 1) — 4-6 tuần
- [ ] HTTP request: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- [ ] Headers, query params, body (raw, JSON, form-data, urlencoded)
- [ ] Response viewer: pretty print JSON, XML, HTML, raw
- [ ] Response metadata: status, headers, time, size
- [ ] Collections CRUD
- [ ] Environments & variables cơ bản
- [ ] History request
- [ ] Auth: Bearer, Basic, API Key
- [ ] Import/export JSON collection (custom format)
- [ ] Settings cơ bản: theme, timeout

### 6.2. Phase 2 — 3-4 tuần
- [ ] Import/export Postman Collection v2.1
- [ ] Import cURL command
- [ ] Pre-request & post-response scripts (JavaScriptCore)
- [ ] Tests/assertions trong scripts
- [ ] Auth: OAuth 2.0, OAuth 1.0
- [ ] Cookies manager
- [ ] Response preview: image, PDF
- [ ] Code snippet generator (cURL, Swift, Python, JS)

### 6.3. Phase 3 — 3-4 tuần
- [ ] WebSocket client
- [ ] Server-Sent Events (SSE)
- [ ] Proxy support
- [ ] SSL certificate pinning / client certificates
- [ ] Environment switching nhanh
- [ ] Request runner / collection runner
- [ ] Data import/export CSV cho form-data

### 6.4. Phase 4 — 2-4 tuần
- [ ] OpenAPI 3.0 import/export
- [ ] HAR import/export
- [ ] Team sharing qua file (không cloud)
- [ ] Workspaces
- [ ] Advanced request settings: redirect, encoding, compression
- [ ] Request diffs

### 6.5. Phase 5 — Windows
- [ ] Port domain model sang C#
- [ ] WinUI 3 UI implementation
- [ ] Feature parity với macOS

---

## 7. UI/UX Layout

### 7.1. Main Window
```
┌─────────────────────────────────────────────────────────┐
│ Sidebar │ Main Content                                 │
│         │  ┌─────────────────────────────────────────┐ │
│ Workspaces│  │ Request Bar (Method + URL + Send)      │ │
│         │  ├─────────────────────────────────────────┤ │
│ Collections│ │ Tabs: Params | Headers | Auth | Body | Scripts│ │
│         │  ├─────────────────────────────────────────┤ │
│ Environments│ │ Request Editor                         │ │
│         │  ├─────────────────────────────────────────┤ │
│ History │  │ Response: Body | Headers | Cookies | Tests│ │
│         │  │ Status: 200 OK | 245ms | 1.2KB            │ │
└─────────┴───────────────────────────────────────────────┘
```

### 7.2. Key UI Components
- **Sidebar:** 3 sections (Collections, Environments, History)
- **Request bar:** method picker + URL input + Send/Cancel/Save
- **Tab editor:** params, headers, auth, body, scripts
- **Response pane:** body viewer (tree/raw/preview), headers, cookies, tests
- **Status bar:** status code, time, size, environment selector

### 7.3. macOS Native Details
- Native toolbar (`NSToolbar`)
- Keyboard shortcuts (⌘+Enter = Send, ⌘+N = New Request, ⌘+Shift+N = New Collection)
- Right-click context menus
- Drag & drop reorder collections
- Spotlight-style quick open (⌘+P)
- Native window management (tabs, split view)
- Dark/Light mode auto

---

## 8. Networking Engine

### 8.1. Request Builder
```swift
protocol RequestBuilder {
    func build(from request: APIRequest, environment: Environment?) async throws -> URLRequest
}
```

### 8.2. Response Handler
```swift
protocol NetworkEngine {
    func execute(_ request: URLRequest, settings: RequestSettings) async throws -> APIResponse
}
```

### 8.3. Variable Resolution
- Support: `{{variable}}`
- Scope: global → environment → collection → request
- Precedence: request > collection > environment > global

### 8.4. Scripting Context
```javascript
// Pre-request
pm.environment.set("token", "abc123");
pm.variables.set("timestamp", new Date().toISOString());

// Post-response
pm.test("Status is 200", function () {
    pm.response.to.have.status(200);
});
pm.test("Response has token", function () {
    var json = pm.response.json();
    pm.expect(json.token).to.exist;
});
```

Cung cấp subset tương thích Postman `pm.*` API.

---

## 9. Persistence & File Export

### 9.1. Local Storage
- SQLite file mặc định: `~/Library/Application Support/API Signals/Workspace.sqlite`
- Mỗi workspace 1 file SQLite
- Tự động backup lightweight

### 9.2. Export/Import
| Format | Export | Import | Ghi chú |
|---|---|---|---|
| JSON (native) | ✅ | ✅ | Full fidelity |
| Postman v2.1 | ✅ | ✅ | Best effort |
| cURL | ✅ | ✅ | Import từ clipboard |
| OpenAPI 3.0 | ✅ | ✅ | Phase 4 |
| HAR | ✅ | ✅ | Phase 4 |
| Collection file (`.apisignals`) | ✅ | ✅ | Single file workspace snapshot |

### 9.3. File Structure (`.apisignals`)
```
workspace.apisignals/
├── workspace.json
├── collections/
│   ├── collection-1.json
│   └── collection-2.json
├── environments/
│   └── prod.json
└── history/
    └── history.json
```

---

## 10. Open Source Setup

### 10.1. Repository Structure
```
api-signals/
├── .github/
│   ├── workflows/
│   │   ├── build-macos.yml
│   │   ├── test.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE.md
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── CONTRIBUTING.md
│   └── ROADMAP.md
├── macOS/
│   ├── APISignals.xcodeproj
│   ├── Package.swift
│   ├── APISignalsApp/
│   ├── APISignalsUI/
│   ├── APISignalsCore/
│   ├── APISignalsNetwork/
│   ├── APISignalsPersistence/
│   └── APISignalsScripting/
├── windows/
│   └── APISignals.WinUI/
├── shared/
│   └── specs/ (domain specs, JSON schemas)
├── tests/
├── LICENSE (MIT)
├── README.md
└── PROJECT_PLAN.md
```

### 10.2. Contributing Guidelines
- Swift style guide
- XCTest coverage > 70%
- PR template
- Semantic commit messages

---

## 11. Testing Strategy

| Loại | Công cụ | Mục đích |
|---|---|---|
| Unit tests | XCTest | Domain logic, networking, scripting |
| Integration tests | XCTest | Database, import/export |
| UI tests | XCTest UI | Critical user flows |
| Performance | Instruments | Memory leak, network timing |
| Manual QA | Test checklist | Auth flows, file import |

### 11.1. Test Server
- Dùng `httpbin.org` hoặc tự host `httpbin` container bằng Docker cho CI.

---

## 12. Release & Distribution

### 12.1. macOS
- GitHub Releases với `.dmg`
- Homebrew cask
- Mac App Store (tùy chọn, cần sandbox xem xét)

### 12.2. Versioning
- Semantic Versioning: `MAJOR.MINOR.PATCH`
- Public beta: `0.x.x` cho đến khi đủ stable

### 12.3. Windows
- Microsoft Store (MSIX)
- GitHub Releases `.msix` / `.exe`
- winget

---

## 13. Timeline tổng thể

| Phase | Thời gian | Deliverable |
|---|---|---|
| Phase 1: MVP | 4-6 tuần | macOS app cơ bản chạy được request |
| Phase 2: Power user | 3-4 tuần | Scripts, Postman import, OAuth |
| Phase 3: Advanced | 3-4 tuần | WebSocket, proxy, certificates |
| Phase 4: Ecosystem | 2-4 tuần | OpenAPI, HAR, workspaces |
| Phase 5: Windows | 6-8 tuần | Windows app feature parity |

**Tổng thời gian ước tính:** 18-26 tuần cho cả hai nền tảng (macOS ~12-18 tuần, Windows ~6-8 tuần).

---

## 14. Risk & Mitigation

| Risk | Impact | Mitigation |
|---|---|---|
| Postman import không 100% | Medium | Document limitations, best effort |
| JavaScriptCore scripting hạn chế | Medium | Support subset `pm.*`, fallback đơn giản |
| macOS App Store sandbox | Medium | Ưu tiên distribution qua GitHub + Homebrew |
| Windows port lớn | High | Giữ domain model rõ ràng, tách UI hoàn toàn |
| Performance với response lớn | Medium | Pagination, streaming, lazy load |

---

## 15. Next Steps

1. **Khởi tạo repo:** Tạo cấu trúc thư mục, Xcode project, SPM packages.
2. **Domain model:** Viết entities, repository protocols, test đầu tiên.
3. **SQLite schema:** Setup GRDB, migration.
4. **UI skeleton:** Main window, sidebar, request bar, response pane.
5. **Network MVP:** Gửi được 1 request GET đơn giản.
6. **Mở issue tracking:** Tạo GitHub issues theo phase.

---

*Plan version: 1.0*
*Ngày cập nhật: 2026-07-25*
