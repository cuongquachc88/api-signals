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

    private var activeRequestId: UUID?

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
        onEnvironmentUpdated: @escaping (WorkspaceEnvironment) async -> Void
    ) {
        self.request = request
        self.networkEngine = networkEngine
        self.environment = environment
        self.collection = collection
        self.workspaceId = workspaceId
        self.onRequestUpdated = onRequestUpdated
        self.onHistoryEntry = onHistoryEntry
        self.onEnvironmentUpdated = onEnvironmentUpdated
        self.selectedBodyTab = Self.bodyTab(for: request.body)
    }

    public func updateRequest() {
        Task {
            await onRequestUpdated(request)
        }
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
            request.body = .raw(text: "", mimeType: "text/plain")
        case .json:
            if case .json(_) = request.body { break }
            request.body = .json("")
        case .form:
            if case .formData(_) = request.body { break }
            request.body = .formData([])
        case .urlencoded:
            if case .urlEncoded(_) = request.body { break }
            request.body = .urlEncoded([])
        case .graphql:
            if case .graphql(_, _) = request.body { break }
            request.body = .graphql(query: "", variables: "")
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
