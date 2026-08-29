import XCTest
import Network
@testable import APISignalsNetwork
@testable import APISignalsCore

@MainActor
final class MockServerTests: XCTestCase {

    private var server: MockServer!

    override func setUp() async throws {
        server = MockServer()
    }

    override func tearDown() async throws {
        server.stop()
        server = nil
    }

    // MARK: - Start / stop

    func testStartSetsRunningFlag() async throws {
        server.start(port: 18500)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        XCTAssertTrue(server.isRunning)
        server.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(server.isRunning)
    }

    // MARK: - Route matching: exact path

    func testMatchedRouteReturnsConfiguredStatus() async throws {
        server.routes = [
            MockRoute(method: .get, path: "/ping", statusCode: 200, responseBody: "{\"ok\":true}")
        ]
        server.start(port: 18501)
        try await Task.sleep(nanoseconds: 200_000_000)

        let (_, response) = try await URLSession.shared.data(from: URL(string: "http://localhost:18501/ping")!)
        let http = response as! HTTPURLResponse
        XCTAssertEqual(http.statusCode, 200)
    }

    // MARK: - Unmatched route returns 404

    func testUnmatchedRouteReturns404() async throws {
        server.routes = []
        server.start(port: 18502)
        try await Task.sleep(nanoseconds: 200_000_000)

        let (_, response) = try await URLSession.shared.data(from: URL(string: "http://localhost:18502/missing")!)
        let http = response as! HTTPURLResponse
        XCTAssertEqual(http.statusCode, 404)
    }

    // MARK: - Disabled route is skipped

    func testDisabledRouteIsSkipped() async throws {
        server.routes = [
            MockRoute(method: .get, path: "/secret", statusCode: 200, responseBody: "ok", isEnabled: false)
        ]
        server.start(port: 18503)
        try await Task.sleep(nanoseconds: 200_000_000)

        let (_, response) = try await URLSession.shared.data(from: URL(string: "http://localhost:18503/secret")!)
        let http = response as! HTTPURLResponse
        XCTAssertEqual(http.statusCode, 404)
    }

    // MARK: - Response body is returned

    func testResponseBodyContent() async throws {
        let body = #"{"message":"hello"}"#
        server.routes = [
            MockRoute(method: .get, path: "/greet", statusCode: 200, responseBody: body)
        ]
        server.start(port: 18504)
        try await Task.sleep(nanoseconds: 200_000_000)

        let (data, _) = try await URLSession.shared.data(from: URL(string: "http://localhost:18504/greet")!)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("hello"))
    }

    // MARK: - Multiple routes: correct one matched

    func testMultipleRoutesMatchedByMethodAndPath() async throws {
        server.routes = [
            MockRoute(method: .get, path: "/a", statusCode: 200, responseBody: "A"),
            MockRoute(method: .get, path: "/b", statusCode: 201, responseBody: "B")
        ]
        server.start(port: 18505)
        try await Task.sleep(nanoseconds: 200_000_000)

        let (dataA, responseA) = try await URLSession.shared.data(from: URL(string: "http://localhost:18505/a")!)
        let (dataB, responseB) = try await URLSession.shared.data(from: URL(string: "http://localhost:18505/b")!)

        XCTAssertEqual((responseA as! HTTPURLResponse).statusCode, 200)
        XCTAssertEqual((responseB as! HTTPURLResponse).statusCode, 201)
        XCTAssertEqual(String(data: dataA, encoding: .utf8), "A")
        XCTAssertEqual(String(data: dataB, encoding: .utf8), "B")
    }
}
