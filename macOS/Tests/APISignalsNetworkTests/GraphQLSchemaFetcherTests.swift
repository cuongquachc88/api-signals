import XCTest
import Network
import APISignalsCore
@testable import APISignalsNetwork

final class GraphQLSchemaFetcherTests: XCTestCase {

    // MARK: - Cache

    func testFetcherCachesResult() async throws {
        let server = try await IntrospectionStubServer.start()
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        let schema1 = try await fetcher.fetch(endpoint: server.url.absoluteString)
        let schema2 = try await fetcher.fetch(endpoint: server.url.absoluteString)

        XCTAssertEqual(schema1.queryTypeName, schema2.queryTypeName)
        // Server should have received exactly one request (second hit was cached)
        XCTAssertEqual(server.requestCount, 1)
    }

    func testFetcherInvalidateClearsCache() async throws {
        let server = try await IntrospectionStubServer.start()
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        _ = try await fetcher.fetch(endpoint: server.url.absoluteString)
        await fetcher.invalidate(endpoint: server.url.absoluteString)
        _ = try await fetcher.fetch(endpoint: server.url.absoluteString)

        XCTAssertEqual(server.requestCount, 2)
    }

    func testFetcherClearCacheRemovesAll() async throws {
        let server = try await IntrospectionStubServer.start()
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        _ = try await fetcher.fetch(endpoint: server.url.absoluteString)
        await fetcher.clearCache()
        _ = try await fetcher.fetch(endpoint: server.url.absoluteString)

        XCTAssertEqual(server.requestCount, 2)
    }

    // MARK: - Invalid URL

    func testFetcherRejectsInvalidURL() async {
        let fetcher = GraphQLSchemaFetcher()
        do {
            _ = try await fetcher.fetch(endpoint: "not a url ://!")
            XCTFail("Expected invalidURL error")
        } catch GraphQLSchemaError.invalidURL {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Schema content

    func testFetcherReturnsExpectedSchema() async throws {
        let server = try await IntrospectionStubServer.start()
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        let schema = try await fetcher.fetch(endpoint: server.url.absoluteString)

        XCTAssertEqual(schema.queryTypeName, "Query")
        XCTAssertNotNil(schema.rootQueryType)
        XCTAssertFalse(schema.userTypes.isEmpty)
    }

    func testFetcherSendsPostWithIntrospectionQuery() async throws {
        let server = try await IntrospectionStubServer.start()
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        _ = try await fetcher.fetch(endpoint: server.url.absoluteString)

        let body = try XCTUnwrap(server.lastRequestBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let query = try XCTUnwrap(json["query"] as? String)
        XCTAssertTrue(query.contains("__schema"))
        XCTAssertTrue(query.contains("queryType"))
    }

    func testFetcherForwardsCustomHeaders() async throws {
        let server = try await IntrospectionStubServer.start()
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        _ = try await fetcher.fetch(
            endpoint: server.url.absoluteString,
            headers: ["Authorization": "Bearer test-token"]
        )

        let headers = try XCTUnwrap(server.lastRequestHeaders)
        XCTAssertEqual(headers["authorization"], "Bearer test-token")
    }

    // MARK: - Error response

    func testFetcherThrowsOnErrorResponse() async throws {
        let server = try await IntrospectionStubServer.start(respondWithError: true)
        defer { server.stop() }

        let fetcher = GraphQLSchemaFetcher()
        do {
            _ = try await fetcher.fetch(endpoint: server.url.absoluteString)
            XCTFail("Expected error")
        } catch GraphQLSchemaError.fetchFailed(let msg) {
            XCTAssertFalse(msg.isEmpty)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - Stub introspection server

final class IntrospectionStubServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "api-signals.introspection-stub")
    private(set) var url: URL
    private(set) var requestCount: Int = 0
    private(set) var lastRequestBody: Data?
    private(set) var lastRequestHeaders: [String: String]?
    private var connections: [NWConnection] = []
    private let respondWithError: Bool

    private static let schemaResponse = """
    {
      "data": {
        "__schema": {
          "queryType": { "name": "Query" },
          "mutationType": null,
          "subscriptionType": null,
          "types": [
            {
              "kind": "OBJECT",
              "name": "Query",
              "description": null,
              "fields": [
                {
                  "name": "hero",
                  "description": "The hero of the story",
                  "args": [
                    {
                      "name": "episode",
                      "description": null,
                      "type": { "kind": "ENUM", "name": "Episode", "ofType": null }
                    }
                  ],
                  "type": { "kind": "OBJECT", "name": "Character", "ofType": null }
                }
              ],
              "inputFields": [],
              "enumValues": []
            },
            {
              "kind": "OBJECT",
              "name": "Character",
              "description": null,
              "fields": [
                {
                  "name": "name",
                  "description": null,
                  "args": [],
                  "type": { "kind": "SCALAR", "name": "String", "ofType": null }
                }
              ],
              "inputFields": [],
              "enumValues": []
            },
            {
              "kind": "ENUM",
              "name": "Episode",
              "description": null,
              "fields": [],
              "inputFields": [],
              "enumValues": [
                { "name": "NEWHOPE" },
                { "name": "EMPIRE" },
                { "name": "JEDI" }
              ]
            }
          ]
        }
      }
    }
    """

    private static let errorResponse = """
    { "errors": [{ "message": "Introspection is disabled" }] }
    """

    private init(listener: NWListener, url: URL, respondWithError: Bool) {
        self.listener = listener
        self.url = url
        self.respondWithError = respondWithError
    }

    static func start(respondWithError: Bool = false) async throws -> IntrospectionStubServer {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: .any)

        let server = IntrospectionStubServer(
            listener: listener,
            url: URL(string: "http://127.0.0.1:0/graphql")!,
            respondWithError: respondWithError
        )

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeOnce2()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let port = listener.port {
                        server.url = URL(string: "http://127.0.0.1:\(port.rawValue)/graphql")!
                        gate.resume { cont.resume() }
                    }
                case .failed(let error):
                    gate.resume { cont.resume(throwing: error) }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { server.accept($0) }
            listener.start(queue: server.queue)
        }

        return server
    }

    func stop() {
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil { connection.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }

            if let headerEnd = buf.range(of: Data("\r\n\r\n".utf8)) {
                let headerText = String(data: buf.subdata(in: buf.startIndex..<headerEnd.lowerBound), encoding: .utf8) ?? ""
                let contentLength = Self.parseContentLength(from: headerText) ?? 0
                let bodyStart = headerEnd.upperBound
                if buf.count - bodyStart >= contentLength {
                    let body = buf.subdata(in: bodyStart..<(bodyStart + contentLength))
                    self.handle(headers: headerText, body: body, on: connection)
                    return
                }
            }

            if isComplete { connection.cancel(); return }
            self.receive(on: connection, buffer: buf)
        }
    }

    private func handle(headers: String, body: Data, on connection: NWConnection) {
        requestCount += 1
        lastRequestBody = body
        lastRequestHeaders = Self.parseHeaders(from: headers)

        let responseBody: String
        let statusCode: Int
        if respondWithError {
            responseBody = Self.errorResponse
            statusCode = 200  // GraphQL errors still return 200
        } else {
            responseBody = Self.schemaResponse
            statusCode = 200
        }

        let bodyData = Data(responseBody.utf8)
        var response = "HTTP/1.1 \(statusCode) OK\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "Connection: close\r\n\r\n"
        var packet = Data(response.utf8)
        packet.append(bodyData)

        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func parseContentLength(from headers: String) -> Int? {
        for line in headers.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count == 2, parts[0].lowercased() == "content-length" { return Int(parts[1]) }
        }
        return nil
    }

    private static func parseHeaders(from text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count == 2 { result[parts[0].lowercased()] = parts[1] }
        }
        return result
    }
}

private final class ResumeOnce2: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func resume(_ body: () -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
