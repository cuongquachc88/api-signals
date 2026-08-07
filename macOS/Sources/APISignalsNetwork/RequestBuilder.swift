import Foundation
import APISignalsCore

public actor RequestBuilder {
    private let resolver: any VariableResolver
    private let authHandler: AuthHandler

    public init(resolver: any VariableResolver = DefaultVariableResolver(),
                authHandler: AuthHandler = AuthHandler()) {
        self.resolver = resolver
        self.authHandler = authHandler
    }

    public func buildURLRequest(
        from request: APIRequest,
        environment: Environment?,
        collection: Collection? = nil
    ) async -> Result<URLRequest, RequestError> {
        let context = VariableResolutionContext(
            requestVariables: [],
            collectionVariables: collection?.variables ?? [],
            environmentVariables: environment?.variables ?? [],
            globalVariables: []
        )

        // Build URL string from components
        let rawUrlString = request.url.url?.absoluteString ?? ""
        let normalizedUrlString = normalizeURLString(rawUrlString)
        let resolvedUrlString = resolver.resolve(normalizedUrlString, context: context)

        guard var components = URLComponents(string: resolvedUrlString) else {
            return .failure(.invalidURL)
        }

        // Ensure scheme
        if components.scheme?.isEmpty ?? true {
            components.scheme = "https"
        }

        // Query params table is the source of truth (address bar syncs into it).
        let queryItems: [URLQueryItem] = request.queryParams
            .filter(\.isEnabled)
            .map { param in
                URLQueryItem(
                    name: resolver.resolve(param.key, context: context),
                    value: resolver.resolve(param.value, context: context)
                )
            }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            return .failure(.invalidURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.settings.timeout
        urlRequest.httpShouldHandleCookies = request.settings.sendCookies
        if request.settings.acceptCompression {
            urlRequest.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        }

        // Headers
        for header in request.headers where header.isEnabled {
            let key = resolver.resolve(header.key, context: context)
            let value = resolver.resolve(header.value, context: context)
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Body
        switch buildBody(request.body, context: context) {
        case .success(let bodyResult):
            urlRequest.httpBody = bodyResult.data
            if let contentType = bodyResult.contentType {
                urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        case .failure(let error):
            return .failure(error)
        }

        // Auth
        authHandler.apply(auth: request.auth, to: &urlRequest)

        return .success(urlRequest)
    }

    private func urlString(from components: URLComponents) -> String {
        var components = components

        // If no scheme and no host, assume https with the full string as host/path
        if (components.scheme?.isEmpty ?? true) && (components.host?.isEmpty ?? true) {
            components.scheme = "https"
            if components.path.isEmpty && components.url?.absoluteString.hasPrefix("https://") == false {
                // Try to reconstruct from original string if available
                return "https://\(components.url?.absoluteString ?? "")"
            }
        }

        return components.url?.absoluteString ?? ""
    }

    private struct BodyResult {
        let data: Data?
        let contentType: String?
    }

    private func buildBody(_ body: RequestBody, context: VariableResolutionContext) -> Result<BodyResult, RequestError> {
        switch body {
        case .none:
            return .success(BodyResult(data: nil, contentType: nil))
        case .raw(let text, let mimeType):
            let resolved = resolver.resolve(text, context: context)
            return .success(BodyResult(data: resolved.data(using: .utf8), contentType: mimeType))
        case .json(let text):
            let resolved = resolver.resolve(text, context: context)
            return .success(BodyResult(data: resolved.data(using: .utf8), contentType: "application/json"))
        case .urlEncoded(let params):
            var components = URLComponents()
            components.queryItems = params.filter(\.isEnabled).map { param in
                URLQueryItem(
                    name: resolver.resolve(param.key, context: context),
                    value: resolver.resolve(param.value, context: context)
                )
            }
            let data = components.query?.data(using: .utf8)
            return .success(BodyResult(data: data, contentType: "application/x-www-form-urlencoded"))
        case .formData(let fields):
            let boundary = "Boundary-\(UUID().uuidString)"
            var bodyData = Data()
            for field in fields where field.isEnabled {
                let key = resolver.resolve(field.key, context: context)
                let value = resolver.resolve(field.value, context: context)
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(key)\"".data(using: .utf8)!)
                if field.type == .file {
                    let fileName = (value as NSString).lastPathComponent
                    let mimeType = field.mimeType ?? "application/octet-stream"
                    bodyData.append("; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
                    bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                    if let fileData = FileManager.default.contents(atPath: value) {
                        bodyData.append(fileData)
                    }
                } else {
                    bodyData.append("\r\n\r\n".data(using: .utf8)!)
                    bodyData.append(value.data(using: .utf8)!)
                }
                bodyData.append("\r\n".data(using: .utf8)!)
            }
            bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
            return .success(BodyResult(data: bodyData, contentType: "multipart/form-data; boundary=\(boundary)"))
        case .binary(let data):
            return .success(BodyResult(data: data, contentType: "application/octet-stream"))
        case .graphql(let query, let variables):
            let resolvedQuery = resolver.resolve(query, context: context)
            let resolvedVariables = resolver.resolve(variables, context: context)
            let payload: [String: Any] = [
                "query": resolvedQuery,
                "variables": resolvedVariables
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
                return .success(BodyResult(data: data, contentType: "application/json"))
            } catch {
                return .failure(.invalidBody)
            }
        }
    }

    private func normalizeURLString(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Check if it already has a scheme
        if trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil {
            return trimmed
        }

        return "https://" + trimmed
    }
}
