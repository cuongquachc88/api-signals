import XCTest
import Foundation
import Network
import APISignalsCore
@testable import APISignalsNetwork

// MARK: - RequestBuilder GraphQL unit tests

final class GraphQLRequestBuilderTests: XCTestCase {
    func testBuilderSendsGraphQLObjectVariables() async throws {
        let builder = RequestBuilder()
        let request = APIRequest(
            name: "GQL",
            method: .post,
            url: URLComponents(string: "https://api.example.com/graphql")!,
            body: .graphql(
                query: "query User($id: ID!) { user(id: $id) { id } }",
                variables: #"{"id":"u_1"}"#
            )
        )

        let result = await builder.buildURLRequest(from: request, environment: nil)
        let urlRequest = try unwrapSuccess(result)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(urlRequest.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["query"] as? String, "query User($id: ID!) { user(id: $id) { id } }")
        let vars = try XCTUnwrap(json["variables"] as? [String: Any])
        XCTAssertEqual(vars["id"] as? String, "u_1")
        XCTAssertFalse(json["variables"] is String)
    }

    func testBuilderResolvesVariablesInGraphQL() async throws {
        let builder = RequestBuilder()
        let env = Environment(
            workspaceId: UUID(),
            name: "Test",
            variables: [Variable(key: "userId", value: "42")]
        )
        let request = APIRequest(
            name: "GQL",
            method: .post,
            url: URLComponents(string: "https://api.example.com/graphql")!,
            body: .graphql(
                query: "query { user(id: \"{{userId}}\") { name } }",
                variables: #"{"id":"{{userId}}"}"#
            )
        )

        let result = await builder.buildURLRequest(from: request, environment: env)
        let urlRequest = try unwrapSuccess(result)
        let body = try XCTUnwrap(urlRequest.httpBody)
        let text = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("42"))
        XCTAssertFalse(text.contains("{{userId}}"))
    }

    func testBuilderRejectsEmptyGraphQLQuery() async {
        let builder = RequestBuilder()
        let request = APIRequest(
            name: "GQL",
            method: .post,
            url: URLComponents(string: "https://api.example.com/graphql")!,
            body: .graphql(query: "   ", variables: "{}")
        )
        let result = await builder.buildURLRequest(from: request, environment: nil)
        if case .failure(let error) = result {
            XCTAssertEqual(error, .invalidBody)
        } else {
            XCTFail("Expected invalidBody")
        }
    }

    func testBuilderRejectsInvalidGraphQLVariables() async {
        let builder = RequestBuilder()
        let request = APIRequest(
            name: "GQL",
            method: .post,
            url: URLComponents(string: "https://api.example.com/graphql")!,
            body: .graphql(query: "{ __typename }", variables: "[1,2,3]")
        )
        let result = await builder.buildURLRequest(from: request, environment: nil)
        if case .failure(let error) = result {
            XCTAssertEqual(error, .invalidBody)
        } else {
            XCTFail("Expected invalidBody")
        }
    }

    func testCurlGenerateIncludesVariablesObject() throws {
        let converter = CurlConverter()
        let request = APIRequest(
            name: "GQL",
            method: .post,
            url: URLComponents(string: "https://api.example.com/graphql")!,
            body: .graphql(query: "{ hello }", variables: #"{"x":1}"#)
        )
        let curl = converter.generate(from: request)
        XCTAssertTrue(curl.contains("application/json"))
        XCTAssertTrue(curl.contains("\"query\""))
        XCTAssertTrue(curl.contains("\"variables\""))
        // variables value should appear as object syntax, not a quoted JSON string blob only
        XCTAssertTrue(curl.contains("\"x\""))
    }

    private func unwrapSuccess(_ result: Result<URLRequest, RequestError>) throws -> URLRequest {
        switch result {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
}

// MARK: - E2E: real local HTTP GraphQL endpoint

final class GraphQLE2ETests: XCTestCase {
    func testGraphQLRequestRoundTripAgainstLocalServer() async throws {
        let server = try await LocalGraphQLHTTPServer.start()
        defer { server.stop() }

        let engine = URLSessionNetworkEngine()
        let request = APIRequest(
            name: "GQL E2E",
            method: .post,
            url: URLComponents(url: server.url, resolvingAgainstBaseURL: false)!,
            headers: [Header(key: "Accept", value: "application/json")],
            body: .graphql(
                query: "query Hero($episode: Episode!) { hero(episode: $episode) { name } }",
                variables: #"{"episode":"JEDI"}"#
            )
        )

        let result = await engine.execute(request, environment: nil)
        guard case .success(let response) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertEqual(response.statusCode, 200)
        let body = try XCTUnwrap(response.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try XCTUnwrap(json["data"] as? [String: Any])
        let hero = try XCTUnwrap(data["hero"] as? [String: Any])
        XCTAssertEqual(hero["name"] as? String, "Luke Skywalker")

        // Server saw a proper GraphQL envelope
        let received = try XCTUnwrap(server.lastPayload)
        XCTAssertEqual(
            received["query"] as? String,
            "query Hero($episode: Episode!) { hero(episode: $episode) { name } }"
        )
        let vars = try XCTUnwrap(received["variables"] as? [String: Any])
        XCTAssertEqual(vars["episode"] as? String, "JEDI")
        XCTAssertFalse(received["variables"] is String)
    }

    func testGraphQLInvalidVariablesNeverHitNetwork() async throws {
        let server = try await LocalGraphQLHTTPServer.start()
        defer { server.stop() }

        let engine = URLSessionNetworkEngine()
        let request = APIRequest(
            name: "GQL bad",
            method: .post,
            url: URLComponents(url: server.url, resolvingAgainstBaseURL: false)!,
            body: .graphql(query: "{ x }", variables: "not-json")
        )

        let result = await engine.execute(request, environment: nil)
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure before network")
        }
        XCTAssertEqual(error, .invalidBody)
        XCTAssertNil(server.lastPayload)
    }
}

// MARK: - Minimal HTTP/1.1 GraphQL stub server (Network.framework)

final class LocalGraphQLHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "api-signals.graphql-e2e")
    private(set) var url: URL
    private(set) var lastPayload: [String: Any]?
    private var connections: [NWConnection] = []

    private init(listener: NWListener, url: URL) {
        self.listener = listener
        self.url = url
    }

    static func start() async throws -> LocalGraphQLHTTPServer {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: .any)

        let server = LocalGraphQLHTTPServer(
            listener: listener,
            url: URL(string: "http://127.0.0.1:0/graphql")!
        )

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeOnce()
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
            listener.newConnectionHandler = { connection in
                server.accept(connection)
            }
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
            if let error {
                connection.cancel()
                _ = error
                return
            }
            var buf = buffer
            if let data { buf.append(data) }

            if let range = buf.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buf.subdata(in: buf.startIndex..<range.lowerBound)
                let headerText = String(data: headerData, encoding: .utf8) ?? ""
                let contentLength = Self.contentLength(from: headerText) ?? 0
                let bodyStart = range.upperBound
                let available = buf.count - bodyStart
                if available >= contentLength {
                    let body = buf.subdata(in: bodyStart..<(bodyStart + contentLength))
                    self.handle(body: body, on: connection)
                    return
                }
            }

            if isComplete {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buf)
        }
    }

    private func handle(body: Data, on connection: NWConnection) {
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            lastPayload = json
        }

        let responseJSON = #"{"data":{"hero":{"name":"Luke Skywalker"}}}"#
        let responseBody = Data(responseJSON.utf8)
        var response = "HTTP/1.1 200 OK\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(responseBody.count)\r\n"
        response += "Connection: close\r\n\r\n"
        var packet = Data(response.utf8)
        packet.append(responseBody)

        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func contentLength(from headers: String) -> Int? {
        for line in headers.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                return Int(parts[1])
            }
        }
        return nil
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func resume(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
