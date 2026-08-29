import SwiftUI
import APISignalsCore
import APISignalsNetwork
import APISignalsScripting

@MainActor
public final class RequestViewModel: ObservableObject {
    @Published public var request: APIRequest
    @Published public var response: APIResponse?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var selectedBodyTab: BodyTab = .json
    @Published public var selectedResponseTab: ResponseTab = .body
    @Published public var scriptTests: [ScriptTest] = []
    @Published public var scriptErrors: [String] = []
    @Published public var isDirty: Bool = false
    /// Bumped when a cURL import should focus a request editor tab.
    @Published public var editorFocusToken = UUID()
    @Published public var editorFocusTabRaw: String?

    private var activeRequestId: UUID?
    private var persistGeneration: UInt64 = 0
    private let onMarkDirty: (UUID) -> Void
    private let onClearDirty: (UUID) -> Void

    public enum BodyTab: String, CaseIterable {
        case none = "None"
        case raw = "Raw"
        case json = "JSON"
        case form = "Form"
        case urlencoded = "URL Encoded"
        case graphql = "GraphQL"
    }

    public enum ResponseTab: String, CaseIterable {
        case body = "Body"
        case headers = "Headers"
        case cookies = "Cookies"
        case tests = "Tests"
    }

    private let networkEngine: URLSessionNetworkEngine
    private let environment: WorkspaceEnvironment?
    private let collection: Collection?
    private let workspaceId: UUID
    private let onRequestUpdated: (APIRequest) async -> Void
    private let onHistoryEntry: (HistoryEntry) async -> Void
    private let onEnvironmentUpdated: (WorkspaceEnvironment) async -> Void
    private let scriptRunner = JavaScriptCoreRunner()

    public init(
        request: APIRequest,
        networkEngine: URLSessionNetworkEngine,
        environment: WorkspaceEnvironment?,
        collection: Collection?,
        workspaceId: UUID,
        onRequestUpdated: @escaping (APIRequest) async -> Void,
        onHistoryEntry: @escaping (HistoryEntry) async -> Void,
        onEnvironmentUpdated: @escaping (WorkspaceEnvironment) async -> Void,
        onMarkDirty: @escaping (UUID) -> Void = { _ in },
        onClearDirty: @escaping (UUID) -> Void = { _ in }
    ) {
        self.request = request
        self.networkEngine = networkEngine
        self.environment = environment
        self.collection = collection
        self.workspaceId = workspaceId
        self.onRequestUpdated = onRequestUpdated
        self.onHistoryEntry = onHistoryEntry
        self.onEnvironmentUpdated = onEnvironmentUpdated
        self.onMarkDirty = onMarkDirty
        self.onClearDirty = onClearDirty
        self.selectedBodyTab = Self.bodyTab(for: request.body)
    }

    public func updateRequest() {
        markDirty()
    }

    /// Mark the tab as having unsaved changes.
    public func markDirty() {
        isDirty = true
        onMarkDirty(request.id)
    }

    /// Save the current request immediately (Ctrl+S).
    public func saveRequest() {
        let snapshot = request
        Task { @MainActor in
            await onRequestUpdated(snapshot)
            isDirty = false
            onClearDirty(snapshot.id)
        }
    }

    /// Mark dirty only — actual persist happens on Ctrl+S or sendRequest.
    public func schedulePersist(delayNanoseconds: UInt64 = 350_000_000) {
        markDirty()
    }

    /// Apply a parsed cURL import into the editor and persist once.
    public func applyImportedRequest(_ imported: APIRequest) {
        request.method = imported.method
        request.url = imported.url
        request.headers = imported.headers
        request.queryParams = imported.queryParams
        request.body = imported.body
        request.auth = imported.auth
        if imported.name.hasPrefix("Imported cURL") {
            request.name = imported.name
        }
        selectedBodyTab = Self.bodyTab(for: imported.body)
        // Prefer JSON tab when body is JSON-looking raw.
        if case .raw(let text, let mime) = imported.body,
           mime.lowercased().contains("json") || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            request.body = .json(text)
            selectedBodyTab = .json
        }
        if case .json(let text) = request.body, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Skip sync beautify on large payloads — freezes the UI; use Beautify in the editor instead.
            if text.count < JSONFormatter.largeJSONCharacterThreshold,
               let pretty = try? JSONFormatter.beautify(text) {
                request.body = .json(pretty)
            }
        }
        if imported.body != .none {
            editorFocusTabRaw = "Body"
        } else if imported.auth != .none {
            editorFocusTabRaw = "Auth"
        } else if !imported.headers.isEmpty {
            editorFocusTabRaw = "Headers"
        } else if !imported.queryParams.isEmpty {
            editorFocusTabRaw = "Params"
        } else {
            editorFocusTabRaw = nil
        }
        editorFocusToken = UUID()
        saveRequest()
    }

    public func cancelRequest() {
        guard let id = activeRequestId else { return }
        Task {
            await networkEngine.cancel(requestId: id)
        }
        isLoading = false
        activeRequestId = nil
    }

    public func sendRequest() {
        isLoading = true
        errorMessage = nil
        response = nil
        scriptTests = []
        scriptErrors = []
        activeRequestId = request.id

        Task {
            await onRequestUpdated(request)
            isDirty = false
            onClearDirty(request.id)

            // Run pre-request script
            let currentEnvironment = environment
            var effectiveEnvironment = currentEnvironment
            if let preScript = request.preRequestScript, !preScript.isEmpty {
                let preResult = await scriptRunner.runPreRequest(
                    script: preScript,
                    request: request,
                    environment: currentEnvironment,
                    collectionVariables: collection?.variables ?? [],
                    globalVariables: []
                )
                await applyScriptResult(preResult, to: &effectiveEnvironment)
                scriptErrors.append(contentsOf: preResult.errors)
            }

            let result = await networkEngine.execute(request, environment: effectiveEnvironment)
            isLoading = false

            let entry = HistoryEntry(
                workspaceId: workspaceId,
                request: request,
                response: nil,
                timestamp: Date()
            )

            switch result {
            case .success(let response):
                self.response = response
                self.activeRequestId = nil

                // Run post-response script
                if let postScript = request.postResponseScript, !postScript.isEmpty {
                    let postResult = await scriptRunner.runPostResponse(
                        script: postScript,
                        request: request,
                        response: response,
                        environment: effectiveEnvironment,
                        collectionVariables: collection?.variables ?? [],
                        globalVariables: []
                    )
                    await applyScriptResult(postResult, to: &effectiveEnvironment)
                    scriptTests = postResult.tests
                    scriptErrors.append(contentsOf: postResult.errors)
                }

                let successEntry = HistoryEntry(
                    workspaceId: workspaceId,
                    request: request,
                    response: response,
                    timestamp: Date()
                )
                await onHistoryEntry(successEntry)
            case .failure(let error):
                self.activeRequestId = nil
                self.errorMessage = error.localizedDescription
                await onHistoryEntry(entry)
            }
        }
    }

    private func applyScriptResult(_ result: ScriptResult, to environment: inout WorkspaceEnvironment?) async {
        guard var env = environment else { return }

        var variables = env.variables
        var changed = false

        for (key, value) in result.environmentVariables {
            if let index = variables.firstIndex(where: { $0.key == key }) {
                variables[index].value = value
            } else {
                variables.append(Variable(key: key, value: value))
            }
            changed = true
        }

        if changed {
            env.variables = variables
            await onEnvironmentUpdated(env)
            environment = env
        }
    }

    public func setBodyTab(_ tab: BodyTab) {
        selectedBodyTab = tab
        switch tab {
        case .none:
            request.body = .none
        case .raw:
            if case .raw(_, _) = request.body { break }
            if case .json(let text) = request.body {
                request.body = .raw(text: text, mimeType: "application/json")
                break
            }
            request.body = .raw(text: "", mimeType: "text/plain")
        case .json:
            if case .json(_) = request.body { break }
            // Preserve existing JSON-looking raw body instead of wiping it.
            if case .raw(let text, _) = request.body {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") || trimmed.isEmpty {
                    request.body = .json(text)
                    break
                }
            }
            request.body = .json("{\n  \n}")
        case .form:
            if case .formData(_) = request.body { break }
            request.body = .formData([])
        case .urlencoded:
            if case .urlEncoded(_) = request.body { break }
            request.body = .urlEncoded([])
        case .graphql:
            if case .graphql(_, _) = request.body { break }
            if request.method == .get {
                request.method = .post
            }
            request.body = .graphql(
                query: "query {\n  __typename\n}\n",
                variables: "{\n  \n}"
            )
        }
        updateRequest()
    }

    public func bodyTab() -> BodyTab {
        return selectedBodyTab
    }

    private static func bodyTab(for body: RequestBody) -> BodyTab {
        switch body {
        case .none: return .none
        case .raw: return .raw
        case .json: return .json
        case .formData: return .form
        case .urlEncoded: return .urlencoded
        case .graphql: return .graphql
        case .binary: return .raw
        }
    }
}
