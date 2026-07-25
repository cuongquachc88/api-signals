import Foundation

// MARK: - Workspace
public struct Workspace: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - HTTP Method
public enum HTTPMethod: String, Sendable, Equatable, Codable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
}

// MARK: - Header
public struct Header: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }

    public init(key: String, value: String, isEnabled: Bool) {
        self.init(id: UUID(), key: key, value: value, isEnabled: isEnabled)
    }
}

// MARK: - Parameter
public struct Parameter: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool
    public var description: String?

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        isEnabled: Bool = true,
        description: String? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
        self.description = description
    }

    public init(key: String, value: String, isEnabled: Bool) {
        self.init(id: UUID(), key: key, value: value, isEnabled: isEnabled)
    }
}

// MARK: - Request Body
public enum RequestBody: Sendable, Equatable, Codable {
    case none
    case raw(text: String, mimeType: String)
    case json(String)
    case formData([FormField])
    case urlEncoded([Parameter])
    case binary(Data)
    case graphql(query: String, variables: String)
}

public struct FormField: Identifiable, Sendable, Equatable, Codable {
    public enum FieldType: String, Sendable, Equatable, Codable {
        case text
        case file
    }

    public let id: UUID
    public var key: String
    public var value: String
    public var type: FieldType
    public var mimeType: String?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        type: FieldType = .text,
        mimeType: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.type = type
        self.mimeType = mimeType
        self.isEnabled = isEnabled
    }
}

// MARK: - Auth
public enum Auth: Sendable, Equatable, Codable {
    case none
    case bearer(token: String)
    case basic(username: String, password: String)
    case apiKey(key: String, value: String, location: APIKeyLocation)
    case oauth1(OAuth1Config)
    case oauth2(OAuth2Config)
    case digest(username: String, password: String)
    case ntlm(username: String, password: String, domain: String?)
    case awsSignature(AWSSignatureConfig)
}

public enum APIKeyLocation: String, Sendable, Equatable, Codable {
    case header
    case query
}

public struct OAuth2Config: Sendable, Equatable, Codable {
    public var grantType: String
    public var accessTokenUrl: String?
    public var authUrl: String?
    public var clientId: String?
    public var clientSecret: String?
    public var scope: String?
    public var redirectUri: String?
    public var token: String?
    public var username: String?
    public var password: String?

    public init(
        grantType: String = "authorization_code",
        accessTokenUrl: String? = nil,
        authUrl: String? = nil,
        clientId: String? = nil,
        clientSecret: String? = nil,
        scope: String? = nil,
        redirectUri: String? = nil,
        token: String? = nil,
        username: String? = nil,
        password: String? = nil
    ) {
        self.grantType = grantType
        self.accessTokenUrl = accessTokenUrl
        self.authUrl = authUrl
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scope
        self.redirectUri = redirectUri
        self.token = token
        self.username = username
        self.password = password
    }
}

public struct OAuth1Config: Sendable, Equatable, Codable {
    public var consumerKey: String
    public var consumerSecret: String
    public var token: String
    public var tokenSecret: String
    public var signatureMethod: String
    public var version: String

    public init(
        consumerKey: String = "",
        consumerSecret: String = "",
        token: String = "",
        tokenSecret: String = "",
        signatureMethod: String = "HMAC-SHA1",
        version: String = "1.0"
    ) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.token = token
        self.tokenSecret = tokenSecret
        self.signatureMethod = signatureMethod
        self.version = version
    }
}

public struct AWSSignatureConfig: Sendable, Equatable, Codable {
    public var accessKey: String
    public var secretKey: String
    public var region: String
    public var service: String

    public init(
        accessKey: String,
        secretKey: String,
        region: String,
        service: String
    ) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.service = service
    }
}

// MARK: - API Request
public struct APIRequest: Identifiable, Sendable, Equatable, Codable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    public let id: UUID
    public var collectionId: UUID
    public var name: String
    public var method: HTTPMethod
    public var url: URLComponents
    public var headers: [Header]
    public var queryParams: [Parameter]
    public var body: RequestBody
    public var auth: Auth
    public var preRequestScript: String?
    public var postResponseScript: String?
    public var settings: RequestSettings

    public init(
        id: UUID = UUID(),
        collectionId: UUID = UUID(),
        name: String,
        method: HTTPMethod = .get,
        url: URLComponents = URLComponents(),
        headers: [Header] = [],
        queryParams: [Parameter] = [],
        body: RequestBody = .none,
        auth: Auth = .none,
        preRequestScript: String? = nil,
        postResponseScript: String? = nil,
        settings: RequestSettings = RequestSettings()
    ) {
        self.id = id
        self.collectionId = collectionId
        self.name = name
        self.method = method
        self.url = url
        self.headers = headers
        self.queryParams = queryParams
        self.body = body
        self.auth = auth
        self.preRequestScript = preRequestScript
        self.postResponseScript = postResponseScript
        self.settings = settings
    }
}

// MARK: - Proxy Config
public struct ProxyConfig: Sendable, Equatable, Codable {
    public var host: String
    public var port: Int
    public var username: String?
    public var password: String?
    public var isEnabled: Bool

    public init(
        host: String = "",
        port: Int = 8080,
        username: String? = nil,
        password: String? = nil,
        isEnabled: Bool = false
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.isEnabled = isEnabled
    }
}

// MARK: - Request Settings
public struct RequestSettings: Sendable, Equatable, Codable {
    public var followRedirects: Bool
    public var timeout: TimeInterval
    public var verifySSL: Bool
    public var encoding: String
    public var proxy: ProxyConfig?
    public var sendCookies: Bool
    public var storeCookies: Bool
    public var acceptCompression: Bool

    public init(
        followRedirects: Bool = true,
        timeout: TimeInterval = 30,
        verifySSL: Bool = true,
        encoding: String = "utf-8",
        proxy: ProxyConfig? = nil,
        sendCookies: Bool = true,
        storeCookies: Bool = true,
        acceptCompression: Bool = true
    ) {
        self.followRedirects = followRedirects
        self.timeout = timeout
        self.verifySSL = verifySSL
        self.encoding = encoding
        self.proxy = proxy
        self.sendCookies = sendCookies
        self.storeCookies = storeCookies
        self.acceptCompression = acceptCompression
    }
}

// MARK: - Response
public struct APIResponse: Sendable, Equatable, Codable {
    public var statusCode: Int
    public var statusText: String
    public var headers: [Header]
    public var body: Data?
    public var mimeType: String?
    public var timing: RequestTiming
    public var size: ResponseSize
    public var cookies: [Cookie]
    public var certificate: CertificateInfo?

    public init(
        statusCode: Int,
        statusText: String,
        headers: [Header] = [],
        body: Data? = nil,
        mimeType: String? = nil,
        timing: RequestTiming = RequestTiming(),
        size: ResponseSize = ResponseSize(),
        cookies: [Cookie] = [],
        certificate: CertificateInfo? = nil
    ) {
        self.statusCode = statusCode
        self.statusText = statusText
        self.headers = headers
        self.body = body
        self.mimeType = mimeType
        self.timing = timing
        self.size = size
        self.cookies = cookies
        self.certificate = certificate
    }
}

public struct RequestTiming: Sendable, Equatable, Codable {
    public var dns: TimeInterval?
    public var connect: TimeInterval?
    public var tls: TimeInterval?
    public var ttfb: TimeInterval
    public var download: TimeInterval
    public var total: TimeInterval

    public init(
        dns: TimeInterval? = nil,
        connect: TimeInterval? = nil,
        tls: TimeInterval? = nil,
        ttfb: TimeInterval = 0,
        download: TimeInterval = 0,
        total: TimeInterval = 0
    ) {
        self.dns = dns
        self.connect = connect
        self.tls = tls
        self.ttfb = ttfb
        self.download = download
        self.total = total
    }
}

public struct ResponseSize: Sendable, Equatable, Codable {
    public var headers: Int
    public var body: Int
    public var total: Int

    public init(
        headers: Int = 0,
        body: Int = 0,
        total: Int = 0
    ) {
        self.headers = headers
        self.body = body
        self.total = total
    }
}

public struct Cookie: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var value: String
    public var domain: String?
    public var path: String?
    public var expires: Date?
    public var isSecure: Bool
    public var isHttpOnly: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        value: String,
        domain: String? = nil,
        path: String? = nil,
        expires: Date? = nil,
        isSecure: Bool = false,
        isHttpOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expires = expires
        self.isSecure = isSecure
        self.isHttpOnly = isHttpOnly
    }
}

public struct CertificateInfo: Sendable, Equatable, Codable {
    public var subject: String
    public var issuer: String
    public var validFrom: Date
    public var validUntil: Date
    public var fingerprint: String

    public init(
        subject: String,
        issuer: String,
        validFrom: Date,
        validUntil: Date,
        fingerprint: String
    ) {
        self.subject = subject
        self.issuer = issuer
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.fingerprint = fingerprint
    }
}

// MARK: - Collection
public struct Collection: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var workspaceId: UUID
    public var name: String
    public var description: String?
    public var parentId: UUID?
    public var sortOrder: Int
    public var variables: [Variable]
    public var auth: Auth
    public var preRequestScript: String?
    public var postResponseScript: String?

    public init(
        id: UUID = UUID(),
        workspaceId: UUID,
        name: String,
        description: String? = nil,
        parentId: UUID? = nil,
        sortOrder: Int = 0,
        variables: [Variable] = [],
        auth: Auth = .none,
        preRequestScript: String? = nil,
        postResponseScript: String? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.description = description
        self.parentId = parentId
        self.sortOrder = sortOrder
        self.variables = variables
        self.auth = auth
        self.preRequestScript = preRequestScript
        self.postResponseScript = postResponseScript
    }
}

// MARK: - Environment
public struct Environment: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var workspaceId: UUID
    public var name: String
    public var variables: [Variable]
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        workspaceId: UUID,
        name: String,
        variables: [Variable] = [],
        isActive: Bool = false
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.variables = variables
        self.isActive = isActive
    }
}

public struct Variable: Identifiable, Sendable, Equatable, Codable {
    public enum VariableType: String, Sendable, Equatable, Codable {
        case `default`
        case secret
    }

    public let id: UUID
    public var key: String
    public var value: String
    public var type: VariableType
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        type: VariableType = .default,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.type = type
        self.isEnabled = isEnabled
    }
}

// MARK: - History
public struct HistoryEntry: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var workspaceId: UUID
    public var request: APIRequest
    public var response: APIResponse?
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        workspaceId: UUID,
        request: APIRequest,
        response: APIResponse? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.request = request
        self.response = response
        self.timestamp = timestamp
    }
}

// MARK: - Request Result
public enum RequestResult: Sendable, Equatable {
    case success(APIResponse)
    case failure(RequestError)
}

public enum RequestError: Sendable, Equatable, Error {
    case invalidURL
    case invalidBody
    case network(String)
    case timeout
    case ssl(String)
    case cancelled
    case unknown(String)

    public var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidBody:
            return "Invalid request body"
        case .network(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Request timed out"
        case .ssl(let message):
            return "SSL error: \(message)"
        case .cancelled:
            return "Request cancelled"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Repository Protocols
public protocol WorkspaceRepository: Sendable {
    func all() async throws -> [Workspace]
    func create(_ workspace: Workspace) async throws -> Workspace
    func update(_ workspace: Workspace) async throws -> Workspace
    func delete(id: UUID) async throws
}

public protocol CollectionRepository: Sendable {
    func all(in workspaceId: UUID) async throws -> [Collection]
    func create(_ collection: Collection) async throws -> Collection
    func update(_ collection: Collection) async throws -> Collection
    func delete(id: UUID) async throws
}

public protocol RequestRepository: Sendable {
    func all(in collectionId: UUID) async throws -> [APIRequest]
    func create(_ request: APIRequest) async throws -> APIRequest
    func update(_ request: APIRequest) async throws -> APIRequest
    func delete(id: UUID) async throws
}

public protocol EnvironmentRepository: Sendable {
    func all(in workspaceId: UUID) async throws -> [Environment]
    func create(_ environment: Environment) async throws -> Environment
    func update(_ environment: Environment) async throws -> Environment
    func delete(id: UUID) async throws
    func setActive(id: UUID, workspaceId: UUID) async throws
}

public protocol HistoryRepository: Sendable {
    func all(in workspaceId: UUID, limit: Int?) async throws -> [HistoryEntry]
    func add(_ entry: HistoryEntry) async throws
    func delete(id: UUID) async throws
    func clear(workspaceId: UUID) async throws
}

public protocol NetworkEngine: Sendable {
    func execute(_ request: APIRequest, environment: Environment?) async -> RequestResult
}

public protocol VariableResolver: Sendable {
    func resolve(_ string: String, context: VariableResolutionContext) -> String
}

public struct VariableResolutionContext: Sendable {
    public var requestVariables: [Variable]
    public var collectionVariables: [Variable]
    public var environmentVariables: [Variable]
    public var globalVariables: [Variable]

    public init(
        requestVariables: [Variable] = [],
        collectionVariables: [Variable] = [],
        environmentVariables: [Variable] = [],
        globalVariables: [Variable] = []
    ) {
        self.requestVariables = requestVariables
        self.collectionVariables = collectionVariables
        self.environmentVariables = environmentVariables
        self.globalVariables = globalVariables
    }
}
