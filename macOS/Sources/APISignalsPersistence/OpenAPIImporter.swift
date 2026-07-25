import Foundation
import APISignalsCore

public enum OpenAPIImporterError: Error {
    case invalidData
    case unsupportedVersion
    case missingInfo
}

public struct OpenAPIImporter {
    public init() {}

    public func importFromFile(url: URL) throws -> (collection: Collection, requests: [APIRequest], workspaceId: UUID) {
        let data = try Data(contentsOf: url)
        return try importFromData(data, workspaceId: UUID())
    }

    public func importFromData(_ data: Data, workspaceId: UUID) throws -> (collection: Collection, requests: [APIRequest], workspaceId: UUID) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAPIImporterError.invalidData
        }

        // Support OpenAPI 3.0 and 3.1
        if let openapi = json["openapi"] as? String {
            guard openapi.hasPrefix("3.") else { throw OpenAPIImporterError.unsupportedVersion }
        } else if let swagger = json["swagger"] as? String, swagger.hasPrefix("2.") {
            return try importSwagger2(json: json, workspaceId: workspaceId)
        } else {
            throw OpenAPIImporterError.unsupportedVersion
        }

        return try importOpenAPI3(json: json, workspaceId: workspaceId)
    }

    private func importOpenAPI3(json: [String: Any], workspaceId: UUID) throws -> (Collection, [APIRequest], UUID) {
        guard let info = json["info"] as? [String: Any],
              let title = info["title"] as? String else {
            throw OpenAPIImporterError.missingInfo
        }

        let collection = Collection(workspaceId: workspaceId, name: title)
        var requests: [APIRequest] = []

        let servers = (json["servers"] as? [[String: Any]])?.compactMap { $0["url"] as? String } ?? []
        let baseUrl = servers.first ?? ""

        guard let paths = json["paths"] as? [String: Any] else {
            return (collection, requests, workspaceId)
        }

        for (path, pathValue) in paths.sorted(by: { $0.key < $1.key }) {
            guard let methods = pathValue as? [String: Any] else { continue }

            for (method, operationValue) in methods where isHTTPMethod(method) {
                guard let operation = operationValue as? [String: Any] else { continue }

                let requestUrl = baseUrl + path
                var components = URLComponents(string: requestUrl) ?? URLComponents()
                if components.scheme == nil { components.scheme = "https" }

                let operationId = operation["operationId"] as? String
                let summary = operation["summary"] as? String
                let name = operationId ?? summary ?? "\(method.uppercased()) \(path)"

                var headers: [Header] = []
                var queryParams: [Parameter] = []

                if let parameters = operation["parameters"] as? [[String: Any]] {
                    for param in parameters {
                        guard let paramName = param["name"] as? String,
                              let paramIn = param["in"] as? String else { continue }
                        let required = param["required"] as? Bool ?? false
                        let description = param["description"] as? String ?? ""
                        let _ = description // suppress unused warning

                        switch paramIn {
                        case "header":
                            headers.append(Header(
                                key: paramName,
                                value: "",
                                isEnabled: required
                            ))
                        case "query":
                            queryParams.append(Parameter(
                                key: paramName,
                                value: "",
                                isEnabled: required
                            ))
                        default:
                            break
                        }
                    }
                }

                var body: RequestBody = .none
                if let requestBody = operation["requestBody"] as? [String: Any],
                   let content = requestBody["content"] as? [String: Any] {
                    if content.keys.contains("application/json") {
                        body = .raw(text: "{\n  \n}", mimeType: "application/json")
                    } else if content.keys.contains("application/x-www-form-urlencoded") {
                        body = .urlEncoded([])
                    } else if content.keys.contains("multipart/form-data") {
                        body = .formData([])
                    }
                }

                let apiRequest = APIRequest(
                    collectionId: collection.id,
                    name: name,
                    method: HTTPMethod(rawValue: method.uppercased()) ?? .get,
                    url: components,
                    headers: headers,
                    queryParams: queryParams,
                    body: body,
                    auth: .none
                )
                requests.append(apiRequest)
            }
        }

        return (collection, requests, workspaceId)
    }

    private func importSwagger2(json: [String: Any], workspaceId: UUID) throws -> (Collection, [APIRequest], UUID) {
        guard let info = json["info"] as? [String: Any],
              let title = info["title"] as? String else {
            throw OpenAPIImporterError.missingInfo
        }

        let collection = Collection(workspaceId: workspaceId, name: title)
        var requests: [APIRequest] = []

        let host = json["host"] as? String ?? "localhost"
        let basePath = json["basePath"] as? String ?? "/"
        let schemes = json["schemes"] as? [String] ?? ["https"]
        let scheme = schemes.first ?? "https"
        let baseUrl = "\(scheme)://\(host)\(basePath)"

        guard let paths = json["paths"] as? [String: Any] else {
            return (collection, requests, workspaceId)
        }

        for (path, pathValue) in paths.sorted(by: { $0.key < $1.key }) {
            guard let methods = pathValue as? [String: Any] else { continue }

            for (method, operationValue) in methods where isHTTPMethod(method) {
                guard let operation = operationValue as? [String: Any] else { continue }

                let url = baseUrl.hasSuffix("/") && path.hasPrefix("/")
                    ? baseUrl.dropLast() + path
                    : baseUrl + path
                var components = URLComponents(string: String(url)) ?? URLComponents()
                if components.scheme == nil { components.scheme = "https" }

                let operationId = operation["operationId"] as? String
                let summary = operation["summary"] as? String
                let name = operationId ?? summary ?? "\(method.uppercased()) \(path)"

                var headers: [Header] = []
                var queryParams: [Parameter] = []
                var body: RequestBody = .none

                if let parameters = operation["parameters"] as? [[String: Any]] {
                    for param in parameters {
                        guard let paramName = param["name"] as? String,
                              let paramIn = param["in"] as? String else { continue }
                        let required = param["required"] as? Bool ?? false

                        switch paramIn {
                        case "header":
                            headers.append(Header(key: paramName, value: "", isEnabled: required))
                        case "query":
                            queryParams.append(Parameter(key: paramName, value: "", isEnabled: required))
                        case "body":
                            let consumes = operation["consumes"] as? [String] ?? json["consumes"] as? [String] ?? ["application/json"]
                            if consumes.contains("application/json") {
                                body = .raw(text: "{\n  \n}", mimeType: "application/json")
                            } else if consumes.contains("application/x-www-form-urlencoded") {
                                body = .urlEncoded([])
                            }
                        default:
                            break
                        }
                    }
                }

                let apiRequest = APIRequest(
                    collectionId: collection.id,
                    name: name,
                    method: HTTPMethod(rawValue: method.uppercased()) ?? .get,
                    url: components,
                    headers: headers,
                    queryParams: queryParams,
                    body: body,
                    auth: .none
                )
                requests.append(apiRequest)
            }
        }

        return (collection, requests, workspaceId)
    }

    private func isHTTPMethod(_ string: String) -> Bool {
        ["get", "post", "put", "patch", "delete", "head", "options", "trace"].contains(string.lowercased())
    }
}
