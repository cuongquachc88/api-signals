import XCTest
import APISignalsCore

final class CurlConverterTests: XCTestCase {

    // MARK: - generate (cURL output)

    func testGenerateSimpleGet() {
        let request = APIRequest(
            name: "Test",
            method: .get,
            url: URLComponents(string: "https://api.example.com/users")!
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("curl"))
        XCTAssertTrue(curl.contains("https://api.example.com/users"))
        // GET is implicit — generator omits -X GET
        XCTAssertFalse(curl.contains("-X POST"))
    }

    func testGenerateIncludesEnabledHeadersOnly() {
        let request = APIRequest(
            name: "Test",
            method: .get,
            url: URLComponents(string: "https://example.com")!,
            headers: [
                Header(key: "Authorization", value: "Bearer token123", isEnabled: true),
                Header(key: "X-Disabled", value: "skip", isEnabled: false)
            ]
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("Authorization: Bearer token123"))
        XCTAssertFalse(curl.contains("X-Disabled"))
    }

    func testGenerateJSONBodyIsCompact() {
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: URLComponents(string: "https://example.com/api")!,
            body: .json("{\n  \"name\": \"Alice\",\n  \"age\": 30\n}")
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("-H \"Content-Type: application/json\""))
        // Body must not contain literal newlines inside -d value
        XCTAssertFalse(curl.contains("\n"), "cURL output should be a single line")
        // Compact form: no space after colon
        XCTAssertTrue(curl.contains("\"name\":\"Alice\"") || curl.contains("\"age\":30"))
    }

    func testGenerateJSONBodyAlreadyCompactPassesThrough() {
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: URLComponents(string: "https://example.com")!,
            body: .json("{\"key\":\"value\"}")
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("\"key\":\"value\""))
        XCTAssertTrue(curl.contains("-d '"))
    }

    func testGenerateJSONBodyFallsBackOnInvalidJSON() {
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: URLComponents(string: "https://example.com")!,
            body: .json("not valid json { } }")
        )
        let curl = CurlConverter().generate(from: request)
        // Should still produce a -d flag without crashing
        XCTAssertTrue(curl.contains("-d '"))
    }

    func testGenerateURLEncodedBody() {
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: URLComponents(string: "https://example.com/login")!,
            body: .urlEncoded([
                Parameter(key: "username", value: "alice", isEnabled: true),
                Parameter(key: "password", value: "secret", isEnabled: true),
                Parameter(key: "disabled", value: "no", isEnabled: false)
            ])
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("application/x-www-form-urlencoded"))
        XCTAssertTrue(curl.contains("username=alice"))
        XCTAssertTrue(curl.contains("password=secret"))
        XCTAssertFalse(curl.contains("disabled=no"))
    }

    func testGenerateRawBody() {
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: URLComponents(string: "https://example.com")!,
            body: .raw(text: "hello world", mimeType: "text/plain")
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("text/plain"))
        XCTAssertTrue(curl.contains("hello world"))
    }

    func testGenerateFormDataBody() {
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: URLComponents(string: "https://example.com/upload")!,
            body: .formData([
                FormField(key: "field1", value: "value1", type: .text, isEnabled: true),
                FormField(key: "file", value: "/path/to/file.txt", type: .file, isEnabled: true),
                FormField(key: "skip", value: "x", type: .text, isEnabled: false)
            ])
        )
        let curl = CurlConverter().generate(from: request)
        XCTAssertTrue(curl.contains("-F 'field1=value1'"))
        XCTAssertTrue(curl.contains("-F 'file=@/path/to/file.txt'"))
        XCTAssertFalse(curl.contains("skip="))
    }

    // MARK: - parse (cURL import)

    func testParseSimpleGet() throws {
        let curl = "curl https://api.example.com/users"
        let request = try CurlConverter().parse(curl)
        XCTAssertEqual(request.url.host, "api.example.com")
        XCTAssertEqual(request.method, .get)
    }

    func testParsePostWithJSONBody() throws {
        let curl = #"curl -X POST https://api.example.com/users -H "Content-Type: application/json" -d '{"name":"Bob"}'"#
        let request = try CurlConverter().parse(curl)
        XCTAssertEqual(request.method, .post)
        if case .json(let text) = request.body {
            XCTAssertTrue(text.contains("Bob"))
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testParseHeaders() throws {
        let curl = #"curl https://example.com -H "Authorization: Bearer abc" -H "X-Custom: val""#
        let request = try CurlConverter().parse(curl)
        XCTAssertTrue(request.headers.contains { $0.key == "Authorization" && $0.value == "Bearer abc" })
        XCTAssertTrue(request.headers.contains { $0.key == "X-Custom" && $0.value == "val" })
    }

    func testLooksLikeCurlDetection() {
        XCTAssertTrue(CurlConverter.looksLikeCurl("curl https://example.com"))
        XCTAssertTrue(CurlConverter.looksLikeCurl("  curl -X POST https://example.com"))
        XCTAssertFalse(CurlConverter.looksLikeCurl("https://example.com"))
        XCTAssertFalse(CurlConverter.looksLikeCurl("GET /users HTTP/1.1"))
    }
}
