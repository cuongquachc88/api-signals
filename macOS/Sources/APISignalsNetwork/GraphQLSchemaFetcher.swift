import Foundation
import APISignalsCore

public actor GraphQLSchemaFetcher {
    public static let shared = GraphQLSchemaFetcher()

    private var cache: [String: GraphQLSchema] = [:]

    public func fetch(endpoint: String, headers: [String: String] = [:]) async throws -> GraphQLSchema {
        if let cached = cache[endpoint] { return cached }

        guard let url = URL(string: endpoint) else { throw GraphQLSchemaError.invalidURL }

        let body = try JSONSerialization.data(withJSONObject: ["query": GraphQLIntrospection.query])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw GraphQLSchemaError.fetchFailed("HTTP \(http.statusCode)")
        }

        let schema = try GraphQLIntrospection.parse(data)
        cache[endpoint] = schema
        return schema
    }

    public func invalidate(endpoint: String) {
        cache.removeValue(forKey: endpoint)
    }

    public func clearCache() {
        cache.removeAll()
    }
}
