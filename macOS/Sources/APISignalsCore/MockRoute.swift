import Foundation

public struct MockRoute: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var method: HTTPMethod
    public var path: String
    public var statusCode: Int
    public var responseBody: String
    public var responseContentType: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        method: HTTPMethod = .get,
        path: String = "/",
        statusCode: Int = 200,
        responseBody: String = "",
        responseContentType: String = "application/json",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.responseContentType = responseContentType
        self.isEnabled = isEnabled
    }
}
