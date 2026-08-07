import XCTest
import APISignalsCore

final class APISignalsCoreTests: XCTestCase {
    // MARK: - Entities

    func testWorkspaceEntityCreated() {
        let workspace = Workspace(name: "Test Workspace")
        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertLessThanOrEqual(workspace.createdAt, Date())
    }

    func testRequestEntityDefaults() {
        let request = APIRequest(name: "Get Users")
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.body, .none)
        XCTAssertEqual(request.auth, .none)
    }

    func testRequestHasCollectionId() {
        let collectionId = UUID()
        let request = APIRequest(collectionId: collectionId, name: "Test")
        XCTAssertEqual(request.collectionId, collectionId)
    }

    func testVariableResolutionContextEmpty() {
        let context = VariableResolutionContext()
        XCTAssertTrue(context.requestVariables.isEmpty)
        XCTAssertTrue(context.environmentVariables.isEmpty)
    }

    func testHeaderKeyValueInit() {
        let header = Header(key: "Content-Type", value: "application/json", isEnabled: true)
        XCTAssertEqual(header.key, "Content-Type")
        XCTAssertEqual(header.value, "application/json")
    }

    // MARK: - JSONFormatter

    func testJSONFormatterBeautifyAndMinify() throws {
        let ugly = #"{"b":2,"a":1}"#
        let pretty = try JSONFormatter.beautify(ugly)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("\"a\""))
        let mini = try JSONFormatter.minify(pretty)
        XCTAssertFalse(mini.contains("\n"))
        XCTAssertTrue(JSONFormatter.isValid(mini))
    }

    func testJSONFormatterBeautifySortsKeysForSmallPayloads() throws {
        let pretty = try JSONFormatter.beautify(#"{"z":1,"a":2}"#, sortedKeys: true)
        let aIndex = pretty.firstIndex(of: "a")
        let zIndex = pretty.firstIndex(of: "z")
        XCTAssertNotNil(aIndex)
        XCTAssertNotNil(zIndex)
        XCTAssertLessThan(aIndex!, zIndex!)
    }

    func testJSONFormatterBeautifyCanSkipSorting() throws {
        let pretty = try JSONFormatter.beautify(#"{"z":1,"a":2}"#, sortedKeys: false)
        XCTAssertTrue(pretty.contains("\"z\""))
        XCTAssertTrue(pretty.contains("\"a\""))
    }

    func testJSONFormatterAcceptsFragments() throws {
        XCTAssertTrue(JSONFormatter.isValid("42"))
        XCTAssertTrue(JSONFormatter.isValid("true"))
        XCTAssertTrue(JSONFormatter.isValid(#""hello""#))
        XCTAssertTrue(JSONFormatter.isValid("null"))
    }

    func testJSONFormatterRejectsInvalid() {
        let error = JSONFormatter.validate("{bad")
        XCTAssertNotNil(error)
        XCTAssertEqual(JSONFormatter.validate(""), .empty)
    }

    func testJSONValidationReportsLocation() {
        let invalid = "{\n  \"a\": true,\n  \"b\":\n}"
        let result = JSONFormatter.validateDetailed(invalid)
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.message)
        if let line = result.line {
            XCTAssertGreaterThanOrEqual(line, 1)
            XCTAssertNotNil(result.utf16Offset)
        }
        XCTAssertTrue(JSONFormatter.validateDetailed(#"{"ok":1}"#).isValid)
    }

    func testJSONValidationMessageIncludesLineWhenPresent() {
        let result = JSONFormatter.validateDetailed("{")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.message)
        if let line = result.line, let message = result.message {
            XCTAssertTrue(message.contains("Line \(line)") || message.lowercased().contains("line"))
        }
    }

    func testJSONValidationUtf16Offset() {
        let text = "ab\ncd"
        XCTAssertEqual(JSONFormatter.utf16Offset(in: text, line: 2, column: 2), 4)
        XCTAssertEqual(JSONFormatter.utf16Offset(in: text, line: 1, column: 1), 0)
        XCTAssertNil(JSONFormatter.utf16Offset(in: text, line: nil, column: 1))
    }

    func testJSONValidationEmptyDetailed() {
        let result = JSONFormatter.validateDetailed("   ")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, .empty)
    }

    // MARK: - JSONValue

    func testJSONValueParseObjectAndArray() throws {
        let value = try JSONValue.parse(from: #"{"name":"Ada","tags":[1,true,null]}"#)
        guard case .object(let entries) = value else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(value.childCount, 2)
        XCTAssertTrue(value.isContainer)

        let tags = entries.first { $0.key == "tags" }?.value
        guard case .array(let items) = tags else {
            return XCTFail("Expected tags array")
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[1], .bool(true))
        XCTAssertEqual(items[2], .null)
    }

    func testJSONValueParseEmptyReturnsObject() throws {
        let value = try JSONValue.parse(from: "")
        XCTAssertEqual(value, .object([]))
    }

    func testJSONValueSerializeRoundTrip() throws {
        let original = #"{"count":2,"ok":true}"#
        let value = try JSONValue.parse(from: original)
        let pretty = try value.serialize(pretty: true)
        let mini = try value.serialize(pretty: false)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertFalse(mini.contains("\n"))
        let again = try JSONValue.parse(from: mini)
        XCTAssertEqual(again, value)
    }

    func testJSONValueRejectsInvalid() {
        XCTAssertThrowsError(try JSONValue.parse(from: "{not-json"))
    }

    // MARK: - RequestURLSync

    func testRequestURLSyncRoundTrip() {
        var request = APIRequest(
            name: "Test",
            url: URLComponents(string: "https://api.example.com/v1/users")!,
            queryParams: [
                Parameter(key: "page", value: "1"),
                Parameter(key: "q", value: "hello", isEnabled: false)
            ]
        )
        let display = RequestURLSync.displayString(url: request.url, queryParams: request.queryParams)
        XCTAssertEqual(display, "https://api.example.com/v1/users?page=1")

        RequestURLSync.apply(fullURL: "https://api.example.com/v1/users?page=2&sort=name", to: &request)
        XCTAssertNil(request.url.queryItems)
        XCTAssertEqual(request.queryParams.filter(\.isEnabled).map(\.key), ["page", "sort"])
        XCTAssertEqual(request.queryParams.first { $0.key == "page" }?.value, "2")
        XCTAssertTrue(request.queryParams.contains { $0.key == "q" && !$0.isEnabled })
    }

    func testRequestURLSyncMigratesLegacyQueryOnURL() {
        let components = URLComponents(string: "https://example.com/search?q=test")!
        var request = APIRequest(name: "Legacy", url: components, queryParams: [])
        XCTAssertTrue(RequestURLSync.migrateQueryOutOfURL(request: &request))
        XCTAssertNil(request.url.queryItems)
        XCTAssertEqual(request.queryParams.first?.key, "q")
        XCTAssertEqual(request.queryParams.first?.value, "test")
    }

    func testRequestURLSyncDisplayOmitsDisabledParams() {
        let url = URLComponents(string: "https://example.com/x")!
        let display = RequestURLSync.displayString(
            url: url,
            queryParams: [
                Parameter(key: "a", value: "1", isEnabled: true),
                Parameter(key: "b", value: "2", isEnabled: false)
            ]
        )
        XCTAssertEqual(display, "https://example.com/x?a=1")
        XCTAssertFalse(display.contains("b=2"))
    }

    func testRequestURLSyncApplyEmptyClearsEnabledParams() {
        var request = APIRequest(
            name: "Test",
            url: URLComponents(string: "https://example.com")!,
            queryParams: [
                Parameter(key: "keep", value: "1", isEnabled: false),
                Parameter(key: "drop", value: "2", isEnabled: true)
            ]
        )
        RequestURLSync.apply(fullURL: "", to: &request)
        XCTAssertTrue(request.queryParams.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(request.queryParams.map(\.key), ["keep"])
    }

    func testRequestURLSyncPreservesParamIdentityOnEdit() {
        let id = UUID()
        var request = APIRequest(
            name: "Test",
            url: URLComponents(string: "https://example.com")!,
            queryParams: [Parameter(id: id, key: "page", value: "1")]
        )
        RequestURLSync.apply(fullURL: "https://example.com?page=2", to: &request)
        XCTAssertEqual(request.queryParams.first?.id, id)
        XCTAssertEqual(request.queryParams.first?.value, "2")
    }

    func testRequestURLSyncMigrateNoopWhenNoQuery() {
        var request = APIRequest(
            name: "Test",
            url: URLComponents(string: "https://example.com/path")!,
            queryParams: []
        )
        XCTAssertFalse(RequestURLSync.migrateQueryOutOfURL(request: &request))
    }
}
