import Foundation

public enum GraphQLPayloadError: Error, Equatable, Sendable {
    case emptyQuery
    case invalidVariables(String)

    public var message: String {
        switch self {
        case .emptyQuery:
            return "GraphQL query is empty"
        case .invalidVariables(let detail):
            return "GraphQL variables must be a JSON object: \(detail)"
        }
    }
}

/// Builds and inspects GraphQL-over-HTTP JSON bodies (query / variables / operationName).
/// Spec: https://graphql.org/learn/serving-over-http/
public enum GraphQLPayload {
    public struct Decoded: Equatable, Sendable {
        public var query: String
        public var variablesJSON: String
        public var operationName: String?

        public init(query: String, variablesJSON: String = "{}", operationName: String? = nil) {
            self.query = query
            self.variablesJSON = variablesJSON
            self.operationName = operationName
        }
    }

    /// Encode a GraphQL request body. `variablesJSON` must be empty or a JSON object.
    public static func encode(
        query: String,
        variablesJSON: String,
        operationName: String? = nil
    ) throws -> Data {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw GraphQLPayloadError.emptyQuery }

        var root: [String: Any] = ["query": trimmedQuery]

        let trimmedVars = variablesJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVars.isEmpty {
            root["variables"] = try parseVariablesObject(trimmedVars)
        }

        if let operationName {
            let name = operationName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                root["operationName"] = name
            }
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    /// Convenience for `RequestBody.graphql`.
    public static func encode(bodyQuery query: String, variables: String) throws -> Data {
        try encode(query: query, variablesJSON: variables, operationName: nil)
    }

    public static func decode(_ data: Data) throws -> Decoded {
        let any = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let root = any as? [String: Any] else {
            throw GraphQLPayloadError.invalidVariables("Root payload must be a JSON object")
        }
        guard let query = root["query"] as? String else {
            throw GraphQLPayloadError.emptyQuery
        }

        let variablesJSON: String
        if let vars = root["variables"] {
            if vars is NSNull {
                variablesJSON = "{}"
            } else if let dict = vars as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
                variablesJSON = String(data: data, encoding: .utf8) ?? "{}"
            } else if let text = vars as? String {
                // Tolerate double-encoded variables from buggy clients.
                _ = try parseVariablesObject(text)
                variablesJSON = text
            } else {
                throw GraphQLPayloadError.invalidVariables("variables must be an object")
            }
        } else {
            variablesJSON = "{}"
        }

        let operationName = root["operationName"] as? String
        return Decoded(query: query, variablesJSON: variablesJSON, operationName: operationName)
    }

    public static func isValidVariablesJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return (try? parseVariablesObject(trimmed)) != nil
    }

    // MARK: - Private

    private static func parseVariablesObject(_ text: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8) else {
            throw GraphQLPayloadError.invalidVariables("Invalid UTF-8")
        }
        let any: Any
        do {
            any = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw GraphQLPayloadError.invalidVariables((error as NSError).localizedDescription)
        }
        if any is NSNull {
            return [:]
        }
        guard let dict = any as? [String: Any] else {
            throw GraphQLPayloadError.invalidVariables("Expected a JSON object, e.g. {\"id\": 1}")
        }
        return dict
    }
}
