import XCTest
import APISignalsCore

final class GraphQLPayloadTests: XCTestCase {
    func testEncodeQueryOnly() throws {
        let data = try GraphQLPayload.encode(query: "query { viewer { id } }", variablesJSON: "")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["query"] as? String, "query { viewer { id } }")
        XCTAssertNil(json["variables"])
        XCTAssertNil(json["operationName"])
    }

    func testEncodeVariablesAsObjectNotString() throws {
        let data = try GraphQLPayload.encode(
            query: "query Q($id: ID!) { user(id: $id) { name } }",
            variablesJSON: #"{"id":"42","active":true}"#,
            operationName: "Q"
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["operationName"] as? String, "Q")
        let vars = try XCTUnwrap(json["variables"] as? [String: Any])
        XCTAssertEqual(vars["id"] as? String, "42")
        XCTAssertEqual(vars["active"] as? Bool, true)
        // Must NOT be a string
        XCTAssertFalse(json["variables"] is String)
    }

    func testEncodeEmptyObjectVariables() throws {
        let data = try GraphQLPayload.encode(query: "{ __typename }", variablesJSON: "{\n  \n}")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let vars = try XCTUnwrap(json["variables"] as? [String: Any])
        XCTAssertTrue(vars.isEmpty)
    }

    func testEncodeRejectsEmptyQuery() {
        XCTAssertThrowsError(try GraphQLPayload.encode(query: "  \n  ", variablesJSON: "{}")) { error in
            XCTAssertEqual(error as? GraphQLPayloadError, .emptyQuery)
        }
    }

    func testEncodeRejectsArrayVariables() {
        XCTAssertThrowsError(try GraphQLPayload.encode(query: "{ x }", variablesJSON: "[1,2]")) { error in
            guard case GraphQLPayloadError.invalidVariables = error else {
                return XCTFail("Expected invalidVariables, got \(error)")
            }
        }
    }

    func testEncodeRejectsInvalidVariablesJSON() {
        XCTAssertThrowsError(try GraphQLPayload.encode(query: "{ x }", variablesJSON: "{")) { error in
            guard case GraphQLPayloadError.invalidVariables = error else {
                return XCTFail("Expected invalidVariables")
            }
        }
    }

    func testDecodeRoundTrip() throws {
        let original = try GraphQLPayload.encode(
            query: "mutation M($n: String!) { create(name: $n) { id } }",
            variablesJSON: #"{"n":"Ada"}"#,
            operationName: "M"
        )
        let decoded = try GraphQLPayload.decode(original)
        XCTAssertEqual(decoded.query, "mutation M($n: String!) { create(name: $n) { id } }")
        XCTAssertEqual(decoded.operationName, "M")
        let vars = try JSONSerialization.jsonObject(with: Data(decoded.variablesJSON.utf8)) as? [String: Any]
        XCTAssertEqual(vars?["n"] as? String, "Ada")
    }

    func testIsValidVariablesJSON() {
        XCTAssertTrue(GraphQLPayload.isValidVariablesJSON(""))
        XCTAssertTrue(GraphQLPayload.isValidVariablesJSON("{}"))
        XCTAssertTrue(GraphQLPayload.isValidVariablesJSON("{\"a\":1}"))
        XCTAssertFalse(GraphQLPayload.isValidVariablesJSON("[1]"))
        XCTAssertFalse(GraphQLPayload.isValidVariablesJSON("{"))
        XCTAssertFalse(GraphQLPayload.isValidVariablesJSON("\"x\""))
    }
}
