import Foundation
import GRDB
import APISignalsCore

struct WorkspaceRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "workspaces"

    var id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from workspace: Workspace) {
        self.id = workspace.id.uuidString
        self.name = workspace.name
        self.createdAt = workspace.createdAt
        self.updatedAt = workspace.updatedAt
    }

    func toWorkspace() -> Workspace {
        Workspace(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct CollectionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "collections"

    var id: String
    var workspaceId: String
    var name: String
    var description: String?
    var parentId: String?
    var sortOrder: Int
    var variablesJson: String?
    var authJson: String?
    var preRequestScript: String?
    var postResponseScript: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case name
        case description
        case parentId = "parent_id"
        case sortOrder = "sort_order"
        case variablesJson = "variables_json"
        case authJson = "auth_json"
        case preRequestScript = "pre_request_script"
        case postResponseScript = "post_response_script"
    }

    init(from collection: Collection) {
        self.id = collection.id.uuidString
        self.workspaceId = collection.workspaceId.uuidString
        self.name = collection.name
        self.description = collection.description
        self.parentId = collection.parentId?.uuidString
        self.sortOrder = collection.sortOrder
        self.variablesJson = try? JSON.encode(collection.variables)
        self.authJson = try? JSON.encode(collection.auth)
        self.preRequestScript = collection.preRequestScript
        self.postResponseScript = collection.postResponseScript
    }

    func toCollection() -> Collection {
        Collection(
            id: UUID(uuidString: id) ?? UUID(),
            workspaceId: UUID(uuidString: workspaceId) ?? UUID(),
            name: name,
            description: description,
            parentId: parentId.flatMap(UUID.init(uuidString:)),
            sortOrder: sortOrder,
            variables: JSON.decode(variablesJson, as: [Variable].self, default: []),
            auth: JSON.decode(authJson, as: Auth.self, default: .none),
            preRequestScript: preRequestScript,
            postResponseScript: postResponseScript
        )
    }
}

struct RequestRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "requests"

    var id: String
    var collectionId: String
    var name: String
    var method: String
    var url: String
    var headersJson: String?
    var queryParamsJson: String?
    var bodyJson: String?
    var authJson: String?
    var scriptsJson: String?
    var settingsJson: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case collectionId = "collection_id"
        case name
        case method
        case url
        case headersJson = "headers_json"
        case queryParamsJson = "query_params_json"
        case bodyJson = "body_json"
        case authJson = "auth_json"
        case scriptsJson = "scripts_json"
        case settingsJson = "settings_json"
        case sortOrder = "sort_order"
    }

    init(from request: APIRequest) {
        self.id = request.id.uuidString
        self.collectionId = request.collectionId.uuidString
        self.name = request.name
        self.method = request.method.rawValue
        self.url = request.url.url?.absoluteString ?? ""
        self.headersJson = try? JSON.encode(request.headers)
        self.queryParamsJson = try? JSON.encode(request.queryParams)
        self.bodyJson = try? JSON.encode(request.body)
        self.authJson = try? JSON.encode(request.auth)
        self.scriptsJson = try? JSON.encode(RequestScripts(
            preRequest: request.preRequestScript,
            postResponse: request.postResponseScript
        ))
        self.settingsJson = try? JSON.encode(request.settings)
        self.sortOrder = 0
    }

    func toRequest() -> APIRequest {
        let scripts = JSON.decode(scriptsJson, as: RequestScripts.self, default: RequestScripts())

        var components = URLComponents(string: url)
        if components == nil {
            components = URLComponents()
        }

        return APIRequest(
            id: UUID(uuidString: id) ?? UUID(),
            collectionId: UUID(uuidString: collectionId) ?? UUID(),
            name: name,
            method: HTTPMethod(rawValue: method) ?? .get,
            url: components ?? URLComponents(),
            headers: JSON.decode(headersJson, as: [Header].self, default: []),
            queryParams: JSON.decode(queryParamsJson, as: [Parameter].self, default: []),
            body: JSON.decode(bodyJson, as: RequestBody.self, default: .none),
            auth: JSON.decode(authJson, as: Auth.self, default: .none),
            preRequestScript: scripts.preRequest,
            postResponseScript: scripts.postResponse,
            settings: JSON.decode(settingsJson, as: RequestSettings.self, default: RequestSettings())
        )
    }
}

struct RequestScripts: Codable {
    var preRequest: String?
    var postResponse: String?

    init(preRequest: String? = nil, postResponse: String? = nil) {
        self.preRequest = preRequest
        self.postResponse = postResponse
    }
}

struct EnvironmentRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "environments"

    var id: String
    var workspaceId: String
    var name: String
    var isActive: Bool
    var variablesJson: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case name
        case isActive = "is_active"
        case variablesJson = "variables_json"
    }

    init(from environment: Environment) {
        self.id = environment.id.uuidString
        self.workspaceId = environment.workspaceId.uuidString
        self.name = environment.name
        self.isActive = environment.isActive
        self.variablesJson = try? JSON.encode(environment.variables)
    }

    func toEnvironment() -> Environment {
        Environment(
            id: UUID(uuidString: id) ?? UUID(),
            workspaceId: UUID(uuidString: workspaceId) ?? UUID(),
            name: name,
            variables: JSON.decode(variablesJson, as: [Variable].self, default: []),
            isActive: isActive
        )
    }
}

struct HistoryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "history"

    var id: String
    var workspaceId: String
    var requestJson: String
    var responseJson: String?
    var timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case requestJson = "request_json"
        case responseJson = "response_json"
        case timestamp
    }

    init(from entry: HistoryEntry) {
        self.id = entry.id.uuidString
        self.workspaceId = entry.workspaceId.uuidString
        self.requestJson = (try? JSON.encode(entry.request)) ?? ""
        self.responseJson = entry.response.flatMap { try? JSON.encode($0) }
        self.timestamp = entry.timestamp
    }

    func toHistoryEntry() -> HistoryEntry? {
        guard let request = try? JSON.decode(requestJson, as: APIRequest.self) else {
            return nil
        }
        let response = responseJson.flatMap { try? JSON.decode($0, as: APIResponse.self) }
        return HistoryEntry(
            id: UUID(uuidString: id) ?? UUID(),
            workspaceId: UUID(uuidString: workspaceId) ?? UUID(),
            request: request,
            response: response,
            timestamp: timestamp
        )
    }
}
