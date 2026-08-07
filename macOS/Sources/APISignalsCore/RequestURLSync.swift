import Foundation

/// Keeps the address-bar full URL in sync with `url` + `queryParams` (Postman-style).
public enum RequestURLSync {
    /// Composed URL string shown in the address bar (base URL + enabled query params).
    public static func displayString(url: URLComponents, queryParams: [Parameter]) -> String {
        var components = url
        let enabled = queryParams.filter(\.isEnabled)
        if enabled.isEmpty {
            components.queryItems = nil
            components.percentEncodedQuery = nil
        } else {
            components.queryItems = enabled.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        if let string = components.string, !string.isEmpty {
            return string
        }
        if let absolute = components.url?.absoluteString, !absolute.isEmpty {
            return absolute
        }
        // Fallback for partial / templated URLs that URLComponents can't stringify.
        return fallbackString(base: url, params: enabled)
    }

    /// Parses a full URL from the address bar into base `url` + `queryParams`.
    /// Disabled params that are not present in the new URL are preserved.
    public static func apply(fullURL: String, to request: inout APIRequest) {
        let trimmed = fullURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            request.url = URLComponents()
            // Keep disabled rows; clear enabled ones tied to the empty URL.
            request.queryParams = request.queryParams.filter { !$0.isEnabled }
            return
        }

        guard var components = URLComponents(string: trimmed) else {
            // Unparseable — store as opaque path-like URL without inventing params.
            var opaque = URLComponents()
            opaque.path = trimmed
            request.url = opaque
            return
        }

        let items = components.queryItems ?? []
        let fromURL = items.map { Parameter(key: $0.name, value: $0.value ?? "", isEnabled: true) }

        let disabled = request.queryParams.filter { !$0.isEnabled }
        let enabledKeys = Set(fromURL.map(\.key))
        let keptDisabled = disabled.filter { !enabledKeys.contains($0.key) }

        // Preserve ids/descriptions for params that still exist with same key+value when possible.
        request.queryParams = mergePreservingIdentity(
            previous: request.queryParams,
            nextEnabled: fromURL
        ) + keptDisabled

        components.queryItems = nil
        components.percentEncodedQuery = nil
        request.url = components
    }

    /// Moves any query items still stored on `url` into `queryParams` (legacy data).
    @discardableResult
    public static func migrateQueryOutOfURL(request: inout APIRequest) -> Bool {
        guard let items = request.url.queryItems, !items.isEmpty else { return false }
        let migrated = items.map { Parameter(key: $0.name, value: $0.value ?? "", isEnabled: true) }
        if request.queryParams.isEmpty {
            request.queryParams = migrated
        } else {
            // Append only keys not already represented.
            let existingKeys = Set(request.queryParams.map(\.key))
            request.queryParams.append(contentsOf: migrated.filter { !existingKeys.contains($0.key) })
        }
        request.url.queryItems = nil
        request.url.percentEncodedQuery = nil
        return true
    }

    private static func mergePreservingIdentity(
        previous: [Parameter],
        nextEnabled: [Parameter]
    ) -> [Parameter] {
        var unused = previous.filter(\.isEnabled)
        return nextEnabled.map { incoming in
            if let idx = unused.firstIndex(where: { $0.key == incoming.key && $0.value == incoming.value }) {
                let old = unused.remove(at: idx)
                return Parameter(
                    id: old.id,
                    key: incoming.key,
                    value: incoming.value,
                    isEnabled: true,
                    description: old.description
                )
            }
            if let idx = unused.firstIndex(where: { $0.key == incoming.key }) {
                let old = unused.remove(at: idx)
                return Parameter(
                    id: old.id,
                    key: incoming.key,
                    value: incoming.value,
                    isEnabled: true,
                    description: old.description
                )
            }
            return incoming
        }
    }

    private static func fallbackString(base: URLComponents, params: [Parameter]) -> String {
        var parts: [String] = []
        if let scheme = base.scheme, !scheme.isEmpty {
            parts.append(scheme)
            parts.append("://")
        }
        if let host = base.host {
            parts.append(host)
        }
        if let port = base.port {
            parts.append(":\(port)")
        }
        let path = base.path
        if !path.isEmpty {
            if path.hasPrefix("/") || parts.isEmpty {
                parts.append(path)
            } else {
                parts.append("/" + path)
            }
        }
        var result = parts.joined()
        if result.isEmpty, let raw = base.string {
            result = raw
        }
        guard !params.isEmpty else { return result }
        let query = params
            .map { param in
                let key = param.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param.key
                let value = param.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param.value
                return "\(key)=\(value)"
            }
            .joined(separator: "&")
        if result.contains("?") {
            return result + "&" + query
        }
        return result + "?" + query
    }
}
