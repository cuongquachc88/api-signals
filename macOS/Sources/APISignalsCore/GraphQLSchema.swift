import Foundation

// MARK: - Schema model

public struct GraphQLSchema: Sendable {
    public struct Field: Sendable {
        public let name: String
        public let description: String?
        public let typeName: String
        public let args: [Argument]

        public init(name: String, description: String?, typeName: String, args: [Argument]) {
            self.name = name
            self.description = description
            self.typeName = typeName
            self.args = args
        }
    }

    public struct Argument: Sendable {
        public let name: String
        public let typeName: String
        public let description: String?

        public init(name: String, typeName: String, description: String?) {
            self.name = name
            self.typeName = typeName
            self.description = description
        }
    }

    public struct TypeDef: Sendable {
        public let name: String
        public let kind: String
        public let description: String?
        public let fields: [Field]
        public let enumValues: [String]
        public let inputFields: [Field]

        public init(name: String, kind: String, description: String?, fields: [Field], enumValues: [String], inputFields: [Field]) {
            self.name = name
            self.kind = kind
            self.description = description
            self.fields = fields
            self.enumValues = enumValues
            self.inputFields = inputFields
        }

        public var isBuiltin: Bool { name.hasPrefix("__") }
    }

    public let queryTypeName: String?
    public let mutationTypeName: String?
    public let subscriptionTypeName: String?
    public let types: [TypeDef]

    public init(queryTypeName: String?, mutationTypeName: String?, subscriptionTypeName: String?, types: [TypeDef]) {
        self.queryTypeName = queryTypeName
        self.mutationTypeName = mutationTypeName
        self.subscriptionTypeName = subscriptionTypeName
        self.types = types
    }

    public var userTypes: [TypeDef] { types.filter { !$0.isBuiltin } }

    public func type(named name: String) -> TypeDef? {
        types.first { $0.name == name }
    }

    public var rootQueryType: TypeDef? {
        queryTypeName.flatMap { type(named: $0) }
    }

    public var rootMutationType: TypeDef? {
        mutationTypeName.flatMap { type(named: $0) }
    }

    public var rootSubscriptionType: TypeDef? {
        subscriptionTypeName.flatMap { type(named: $0) }
    }
}

// MARK: - Introspection query

public enum GraphQLIntrospection {
    public static let query = """
    query IntrospectionQuery {
      __schema {
        queryType { name }
        mutationType { name }
        subscriptionType { name }
        types {
          ...FullType
        }
      }
    }
    fragment FullType on __Type {
      kind
      name
      description
      fields(includeDeprecated: true) {
        name
        description
        args { ...InputValue }
        type { ...TypeRef }
      }
      inputFields { ...InputValue }
      enumValues(includeDeprecated: true) { name }
    }
    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
    }
    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType { kind name }
        }
      }
    }
    """

    // MARK: Parsing

    public static func parse(_ data: Data) throws -> GraphQLSchema {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataObj = root["data"] as? [String: Any],
            let schemaObj = dataObj["__schema"] as? [String: Any]
        else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["errors"] as? [[String: Any]] }
                .flatMap { $0.first?["message"] as? String }
                ?? "Unexpected response format"
            throw GraphQLSchemaError.fetchFailed(msg)
        }

        let queryTypeName = (schemaObj["queryType"] as? [String: Any])?["name"] as? String
        let mutationTypeName = (schemaObj["mutationType"] as? [String: Any])?["name"] as? String
        let subscriptionTypeName = (schemaObj["subscriptionType"] as? [String: Any])?["name"] as? String

        let rawTypes = schemaObj["types"] as? [[String: Any]] ?? []
        let types = rawTypes.compactMap { parseType($0) }

        return GraphQLSchema(
            queryTypeName: queryTypeName,
            mutationTypeName: mutationTypeName,
            subscriptionTypeName: subscriptionTypeName,
            types: types
        )
    }

    private static func parseType(_ raw: [String: Any]) -> GraphQLSchema.TypeDef? {
        guard let name = raw["name"] as? String, let kind = raw["kind"] as? String else { return nil }
        let description = raw["description"] as? String

        let fields = (raw["fields"] as? [[String: Any]] ?? []).compactMap { parseField($0) }
        let inputFields = (raw["inputFields"] as? [[String: Any]] ?? []).compactMap { parseField($0) }
        let enumValues = (raw["enumValues"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }

        return GraphQLSchema.TypeDef(name: name, kind: kind, description: description, fields: fields, enumValues: enumValues, inputFields: inputFields)
    }

    private static func parseField(_ raw: [String: Any]) -> GraphQLSchema.Field? {
        guard let name = raw["name"] as? String else { return nil }
        let description = raw["description"] as? String
        let typeName = flatTypeName(raw["type"] as? [String: Any])
        let args = (raw["args"] as? [[String: Any]] ?? []).compactMap { parseArg($0) }
        return GraphQLSchema.Field(name: name, description: description, typeName: typeName, args: args)
    }

    private static func parseArg(_ raw: [String: Any]) -> GraphQLSchema.Argument? {
        guard let name = raw["name"] as? String else { return nil }
        let typeName = flatTypeName(raw["type"] as? [String: Any])
        let description = raw["description"] as? String
        return GraphQLSchema.Argument(name: name, typeName: typeName, description: description)
    }

    private static func flatTypeName(_ typeRef: [String: Any]?) -> String {
        guard let typeRef else { return "Unknown" }
        if let name = typeRef["name"] as? String, !name.isEmpty { return name }
        return flatTypeName(typeRef["ofType"] as? [String: Any])
    }
}

public enum GraphQLSchemaError: Error, LocalizedError {
    case fetchFailed(String)
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let msg): return msg
        case .invalidURL: return "Invalid endpoint URL"
        }
    }
}
