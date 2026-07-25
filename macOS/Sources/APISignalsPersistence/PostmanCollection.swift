import Foundation
import APISignalsCore

public enum PostmanCollectionError: Error {
    case unsupportedSchema
    case invalidData
    case unsupportedAuthType
}

public struct PostmanCollectionConverter {
    public init() {}

    // MARK: - Import
    public func convert(
        postmanCollection: PostmanCollection,
        workspaceId: UUID
    ) -> (collection: Collection, requests: [APIRequest]) {
        let collection = Collection(
            workspaceId: workspaceId,
            name: postmanCollection.info.name,
            description: nil,
            variables: postmanCollection.variable?.compactMap { convertVariable($0) } ?? []
        )

        var requests: [APIRequest] = []
        for item in postmanCollection.item {
            if let request = convertItem(item, collectionId: collection.id) {
                requests.append(request)
            }
        }

        return (collection, requests)
    }

    private func convertItem(_ item: PostmanItem, collectionId: UUID) -> APIRequest? {
        guard let request = item.request else { return nil }

        var components = URLComponents()
        if let url = request.url {
            components = URLComponents(string: url.raw) ?? URLComponents()
        }

        let headers = request.header?.compactMap { convertHeader($0) } ?? []
        let queryParams = request.url?.query?.compactMap { convertParameter($0) } ?? []
        let body = convertBody(request.body)
        let auth = convertAuth(request.auth)

        return APIRequest(
            collectionId: collectionId,
            name: item.name,
            method: HTTPMethod(rawValue: request.method.uppercased()) ?? .get,
            url: components,
            headers: headers,
            queryParams: queryParams,
            body: body,
            auth: auth,
            preRequestScript: request.event?.first { $0.listen == "prerequest" }?.script?.exec?.joined(separator: "\n"),
            postResponseScript: request.event?.first { $0.listen == "test" }?.script?.exec?.joined(separator: "\n")
        )
    }

    private func convertHeader(_ header: PostmanHeader) -> Header? {
        guard !header.key.isEmpty else { return nil }
        return Header(key: header.key, value: header.value, isEnabled: header.disabled != true)
    }

    private func convertParameter(_ param: PostmanQueryParam) -> Parameter? {
        guard !param.key.isEmpty else { return nil }
        return Parameter(key: param.key, value: param.value ?? "", isEnabled: param.disabled != true)
    }

    private func convertVariable(_ variable: PostmanVariable) -> Variable? {
        guard !variable.key.isEmpty else { return nil }
        return Variable(key: variable.key, value: variable.value ?? "")
    }

    private func convertBody(_ body: PostmanBody?) -> RequestBody {
        guard let body = body else { return .none }
        switch body.mode {
        case "raw":
            return .raw(text: body.raw ?? "", mimeType: "text/plain")
        case "urlencoded":
            let params = body.urlencoded?.compactMap { convertParameter($0) } ?? []
            return .urlEncoded(params)
        case "formdata":
            let fields = body.formdata?.compactMap { convertFormField($0) } ?? []
            return .formData(fields)
        case "file":
            return .none
        case "graphql":
            return .graphql(query: body.graphql?.query ?? "", variables: body.graphql?.variables ?? "")
        default:
            return .none
        }
    }

    private func convertFormField(_ field: PostmanFormData) -> FormField? {
        guard !field.key.isEmpty else { return nil }
        let type: FormField.FieldType = field.type == "file" ? .file : .text
        return FormField(key: field.key, value: field.value ?? "", type: type, mimeType: field.contentType, isEnabled: field.disabled != true)
    }

    private func convertAuth(_ auth: PostmanAuth?) -> Auth {
        guard let auth = auth else { return .none }
        switch auth.type {
        case "bearer":
            let token = auth.bearer?.first { $0.key == "token" }?.value ?? ""
            return .bearer(token: token)
        case "basic":
            let username = auth.basic?.first { $0.key == "username" }?.value ?? ""
            let password = auth.basic?.first { $0.key == "password" }?.value ?? ""
            return .basic(username: username, password: password)
        case "apikey":
            let key = auth.apikey?.first { $0.key == "key" }?.value ?? ""
            let value = auth.apikey?.first { $0.key == "value" }?.value ?? ""
            let locationString = auth.apikey?.first { $0.key == "in" }?.value ?? "header"
            let location: APIKeyLocation = locationString == "query" ? .query : .header
            return .apiKey(key: key, value: value, location: location)
        default:
            return .none
        }
    }

    // MARK: - Export
    public func convert(
        collection: Collection,
        requests: [APIRequest]
    ) -> PostmanCollection {
        var items: [PostmanItem] = []

        for request in requests {
            items.append(convertRequest(request))
        }

        return PostmanCollection(
            info: PostmanInfo(
                postmanID: collection.id.uuidString,
                name: collection.name,
                schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
            ),
            item: items,
            variable: collection.variables.map { convertVariable($0) }
        )
    }

    private func convertRequest(_ request: APIRequest) -> PostmanItem {
        let url = PostmanURL(
            raw: request.url.url?.absoluteString ?? "",
            protocol: request.url.scheme,
            host: request.url.host?.components(separatedBy: "."),
            path: request.url.path.components(separatedBy: "/").filter { !$0.isEmpty },
            query: request.queryParams.map { convertParameter($0) }
        )

        let header = request.headers.map { convertHeader($0) }
        let body = convertBody(request.body)
        let auth = convertAuth(request.auth)

        var events: [PostmanEvent] = []
        if let preScript = request.preRequestScript, !preScript.isEmpty {
            events.append(PostmanEvent(listen: "prerequest", script: PostmanScript(exec: preScript.components(separatedBy: "\n"))))
        }
        if let postScript = request.postResponseScript, !postScript.isEmpty {
            events.append(PostmanEvent(listen: "test", script: PostmanScript(exec: postScript.components(separatedBy: "\n"))))
        }

        return PostmanItem(
            name: request.name,
            request: PostmanRequest(
                method: request.method.rawValue,
                header: header,
                body: body,
                url: url,
                auth: auth,
                event: events.isEmpty ? nil : events
            ),
            response: []
        )
    }

    private func convertHeader(_ header: Header) -> PostmanHeader {
        PostmanHeader(key: header.key, value: header.value, disabled: !header.isEnabled)
    }

    private func convertParameter(_ parameter: Parameter) -> PostmanQueryParam {
        PostmanQueryParam(key: parameter.key, value: parameter.value, disabled: !parameter.isEnabled)
    }

    private func convertVariable(_ variable: Variable) -> PostmanVariable {
        PostmanVariable(key: variable.key, value: variable.value, type: "default")
    }

    private func convertBody(_ body: RequestBody) -> PostmanBody? {
        switch body {
        case .none:
            return nil
        case .raw(let text, _):
            return PostmanBody(mode: "raw", raw: text)
        case .json(let text):
            return PostmanBody(mode: "raw", raw: text)
        case .urlEncoded(let params):
            return PostmanBody(mode: "urlencoded", urlencoded: params.map { convertParameter($0) })
        case .formData(let fields):
            return PostmanBody(mode: "formdata", formdata: fields.map { convertFormField($0) })
        case .binary:
            return PostmanBody(mode: "file")
        case .graphql(let query, let variables):
            return PostmanBody(mode: "graphql", graphql: PostmanGraphQL(query: query, variables: variables))
        }
    }

    private func convertFormField(_ field: FormField) -> PostmanFormData {
        PostmanFormData(
            key: field.key,
            value: field.value,
            type: field.type == .file ? "file" : "text",
            contentType: field.mimeType,
            disabled: !field.isEnabled
        )
    }

    private func convertAuth(_ auth: Auth) -> PostmanAuth? {
        switch auth {
        case .none:
            return nil
        case .bearer(let token):
            return PostmanAuth(type: "bearer", bearer: [PostmanAuthKeyValue(key: "token", value: token)])
        case .basic(let username, let password):
            return PostmanAuth(type: "basic", basic: [
                PostmanAuthKeyValue(key: "username", value: username),
                PostmanAuthKeyValue(key: "password", value: password)
            ])
        case .apiKey(let key, let value, let location):
            return PostmanAuth(type: "apikey", apikey: [
                PostmanAuthKeyValue(key: "key", value: key),
                PostmanAuthKeyValue(key: "value", value: value),
                PostmanAuthKeyValue(key: "in", value: location == .query ? "query" : "header")
            ])
        default:
            return nil
        }
    }
}

// MARK: - Postman Models

public struct PostmanCollection: Codable, Sendable {
    public var info: PostmanInfo
    public var item: [PostmanItem]
    public var variable: [PostmanVariable]?

    public init(info: PostmanInfo, item: [PostmanItem], variable: [PostmanVariable]? = nil) {
        self.info = info
        self.item = item
        self.variable = variable
    }
}

public struct PostmanInfo: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case postmanID = "_postman_id"
        case name
        case schema
    }

    public var postmanID: String
    public var name: String
    public var schema: String

    public init(postmanID: String, name: String, schema: String) {
        self.postmanID = postmanID
        self.name = name
        self.schema = schema
    }
}

public struct PostmanItem: Codable, Sendable {
    public var name: String
    public var request: PostmanRequest?
    public var item: [PostmanItem]?
    public var response: [PostmanResponse]?

    public init(name: String, request: PostmanRequest? = nil, item: [PostmanItem]? = nil, response: [PostmanResponse]? = nil) {
        self.name = name
        self.request = request
        self.item = item
        self.response = response
    }
}

public struct PostmanRequest: Codable, Sendable {
    public var method: String
    public var header: [PostmanHeader]?
    public var body: PostmanBody?
    public var url: PostmanURL?
    public var auth: PostmanAuth?
    public var event: [PostmanEvent]?

    public init(method: String, header: [PostmanHeader]? = nil, body: PostmanBody? = nil, url: PostmanURL? = nil, auth: PostmanAuth? = nil, event: [PostmanEvent]? = nil) {
        self.method = method
        self.header = header
        self.body = body
        self.url = url
        self.auth = auth
        self.event = event
    }
}

public struct PostmanHeader: Codable, Sendable {
    public var key: String
    public var value: String
    public var disabled: Bool?

    public init(key: String, value: String, disabled: Bool? = nil) {
        self.key = key
        self.value = value
        self.disabled = disabled
    }
}

public struct PostmanURL: Codable, Sendable {
    public var raw: String
    public var `protocol`: String?
    public var host: [String]?
    public var path: [String]?
    public var query: [PostmanQueryParam]?

    public init(raw: String, protocol: String? = nil, host: [String]? = nil, path: [String]? = nil, query: [PostmanQueryParam]? = nil) {
        self.raw = raw
        self.protocol = `protocol`
        self.host = host
        self.path = path
        self.query = query
    }
}

public struct PostmanQueryParam: Codable, Sendable {
    public var key: String
    public var value: String?
    public var disabled: Bool?

    public init(key: String, value: String? = nil, disabled: Bool? = nil) {
        self.key = key
        self.value = value
        self.disabled = disabled
    }
}

public struct PostmanBody: Codable, Sendable {
    public var mode: String?
    public var raw: String?
    public var urlencoded: [PostmanQueryParam]?
    public var formdata: [PostmanFormData]?
    public var graphql: PostmanGraphQL?

    public init(mode: String? = nil, raw: String? = nil, urlencoded: [PostmanQueryParam]? = nil, formdata: [PostmanFormData]? = nil, graphql: PostmanGraphQL? = nil) {
        self.mode = mode
        self.raw = raw
        self.urlencoded = urlencoded
        self.formdata = formdata
        self.graphql = graphql
    }
}

public struct PostmanFormData: Codable, Sendable {
    public var key: String
    public var value: String?
    public var type: String?
    public var contentType: String?
    public var disabled: Bool?

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case type
        case contentType = "contentType"
        case disabled
    }

    public init(key: String, value: String? = nil, type: String? = nil, contentType: String? = nil, disabled: Bool? = nil) {
        self.key = key
        self.value = value
        self.type = type
        self.contentType = contentType
        self.disabled = disabled
    }
}

public struct PostmanGraphQL: Codable, Sendable {
    public var query: String
    public var variables: String

    public init(query: String, variables: String) {
        self.query = query
        self.variables = variables
    }
}

public struct PostmanAuth: Codable, Sendable {
    public var type: String
    public var bearer: [PostmanAuthKeyValue]?
    public var basic: [PostmanAuthKeyValue]?
    public var apikey: [PostmanAuthKeyValue]?

    public init(type: String, bearer: [PostmanAuthKeyValue]? = nil, basic: [PostmanAuthKeyValue]? = nil, apikey: [PostmanAuthKeyValue]? = nil) {
        self.type = type
        self.bearer = bearer
        self.basic = basic
        self.apikey = apikey
    }
}

public struct PostmanAuthKeyValue: Codable, Sendable {
    public var key: String
    public var value: String
    public var type: String?

    public init(key: String, value: String, type: String? = nil) {
        self.key = key
        self.value = value
        self.type = type
    }
}

public struct PostmanEvent: Codable, Sendable {
    public var listen: String
    public var script: PostmanScript?

    public init(listen: String, script: PostmanScript? = nil) {
        self.listen = listen
        self.script = script
    }
}

public struct PostmanScript: Codable, Sendable {
    public var exec: [String]?

    public init(exec: [String]? = nil) {
        self.exec = exec
    }
}

public struct PostmanVariable: Codable, Sendable {
    public var key: String
    public var value: String?
    public var type: String?

    public init(key: String, value: String? = nil, type: String? = nil) {
        self.key = key
        self.value = value
        self.type = type
    }
}

public struct PostmanResponse: Codable, Sendable {
    public var name: String?
    public var originalRequest: PostmanRequest?
    public var status: String?
    public var code: Int?

    public init(name: String? = nil, originalRequest: PostmanRequest? = nil, status: String? = nil, code: Int? = nil) {
        self.name = name
        self.originalRequest = originalRequest
        self.status = status
        self.code = code
    }
}

// MARK: - Import/Export Convenience

public extension PostmanCollection {
    static func importFromFile(url: URL) throws -> PostmanCollection {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(PostmanCollection.self, from: data)
    }

    func exportToFile(url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
