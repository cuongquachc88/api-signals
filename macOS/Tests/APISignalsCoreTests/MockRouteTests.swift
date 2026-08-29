import XCTest
@testable import APISignalsCore

final class MockRouteTests: XCTestCase {

    func testDefaultValues() {
        let route = MockRoute()
        XCTAssertEqual(route.method, .get)
        XCTAssertEqual(route.path, "/")
        XCTAssertEqual(route.statusCode, 200)
        XCTAssertTrue(route.isEnabled)
        XCTAssertEqual(route.responseContentType, "application/json")
    }

    func testCustomInit() {
        let route = MockRoute(method: .post, path: "/api/users", statusCode: 201, responseBody: "{\"id\":1}")
        XCTAssertEqual(route.method, .post)
        XCTAssertEqual(route.path, "/api/users")
        XCTAssertEqual(route.statusCode, 201)
        XCTAssertEqual(route.responseBody, "{\"id\":1}")
    }

    func testCodable() throws {
        let route = MockRoute(method: .delete, path: "/item/42", statusCode: 204)
        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(MockRoute.self, from: data)
        XCTAssertEqual(decoded.id, route.id)
        XCTAssertEqual(decoded.method, .delete)
        XCTAssertEqual(decoded.path, "/item/42")
        XCTAssertEqual(decoded.statusCode, 204)
    }

    func testEquatable() {
        let id = UUID()
        let r1 = MockRoute(id: id, method: .get, path: "/ping")
        let r2 = MockRoute(id: id, method: .get, path: "/ping")
        XCTAssertEqual(r1, r2)
    }

    func testDisabledRoute() {
        let route = MockRoute(isEnabled: false)
        XCTAssertFalse(route.isEnabled)
    }
}
