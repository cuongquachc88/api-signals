import XCTest
import APISignalsCore
@testable import APISignalsNetwork

final class APISignalsNetworkTests: XCTestCase {
    func testNetworkEngineExists() {
        let engine = URLSessionNetworkEngine()
        XCTAssertNotNil(engine)
    }

    func testRequestBuilderExists() {
        let builder = RequestBuilder()
        XCTAssertNotNil(builder)
    }

    func testVariableResolverBasic() {
        let resolver = DefaultVariableResolver()
        let context = VariableResolutionContext(
            environmentVariables: [Variable(key: "baseUrl", value: "https://api.example.com")]
        )
        let result = resolver.resolve("{{baseUrl}}/users", context: context)
        XCTAssertEqual(result, "https://api.example.com/users")
    }

    func testVariableResolverDefaultValue() {
        let resolver = DefaultVariableResolver()
        let context = VariableResolutionContext()
        let result = resolver.resolve("{{baseUrl:https://default.example.com}}/users", context: context)
        XCTAssertEqual(result, "https://default.example.com/users")
    }

    func testVariableResolverPrecedenceRequestOverEnvironment() {
        let resolver = DefaultVariableResolver()
        let context = VariableResolutionContext(
            requestVariables: [Variable(key: "token", value: "request-token")],
            environmentVariables: [Variable(key: "token", value: "env-token")]
        )
        let result = resolver.resolve("{{token}}", context: context)
        XCTAssertEqual(result, "request-token")
    }

    func testVariableResolverDisabledVariableSkipped() {
        let resolver = DefaultVariableResolver()
        let context = VariableResolutionContext(
            environmentVariables: [Variable(key: "key", value: "value", isEnabled: false)]
        )
        let result = resolver.resolve("{{key:fallback}}", context: context)
        XCTAssertEqual(result, "fallback")
    }

    func testAuthHandlerBearer() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let handler = AuthHandler()
        handler.apply(auth: .bearer(token: "abc123"), to: &request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
    }

    func testAuthHandlerBasic() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let handler = AuthHandler()
        handler.apply(auth: .basic(username: "user", password: "pass"), to: &request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic dXNlcjpwYXNz")
    }

    func testAuthHandlerAPIKeyHeader() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let handler = AuthHandler()
        handler.apply(auth: .apiKey(key: "X-Api-Key", value: "secret", location: .header), to: &request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "secret")
    }

    func testRequestBuilderNormalizesURLWithoutScheme() async {
        let builder = RequestBuilder()
        var components = URLComponents()
        components.host = "api.example.com"
        components.path = "/users"
        let request = APIRequest(name: "Test", url: components)
        let result = await builder.buildURLRequest(from: request, environment: nil)
        if case .success(let urlRequest) = result {
            XCTAssertEqual(urlRequest.url?.scheme, "https")
        } else {
            XCTFail("Expected success")
        }
    }

    func testRequestBuilderAppendsQueryParams() async {
        let builder = RequestBuilder()
        var components = URLComponents(string: "https://api.example.com/users")!
        let request = APIRequest(
            name: "Test",
            url: components,
            queryParams: [Parameter(key: "page", value: "1"), Parameter(key: "limit", value: "20")]
        )
        let result = await builder.buildURLRequest(from: request, environment: nil)
        if case .success(let urlRequest) = result {
            let urlString = urlRequest.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("page=1"))
            XCTAssertTrue(urlString.contains("limit=20"))
        } else {
            XCTFail("Expected success")
        }
    }

    func testCurlConverterParsesSimpleGet() throws {
        let converter = CurlConverter()
        let request = try converter.parse("curl https://api.example.com/users")
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.url.url?.absoluteString, "https://api.example.com/users")
    }

    func testCurlConverterParsesPostWithBody() throws {
        let converter = CurlConverter()
        let request = try converter.parse(#"curl -X POST https://api.example.com/users -H "Content-Type: application/json" -d '{"name":"test"}'"#)
        XCTAssertEqual(request.method, .post)
        if case .json(let text) = request.body {
            XCTAssertEqual(text, #"{"name":"test"}"#)
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testCurlConverterParsesBasicAuth() throws {
        let converter = CurlConverter()
        let request = try converter.parse("curl -u user:pass https://api.example.com")
        if case .basic(let username, let password) = request.auth {
            XCTAssertEqual(username, "user")
            XCTAssertEqual(password, "pass")
        } else {
            XCTFail("Expected basic auth")
        }
    }

    func testCurlGeneratorRoundTrip() throws {
        let converter = CurlConverter()
        var components = URLComponents(string: "https://api.example.com/users")!
        let request = APIRequest(
            name: "Test",
            method: .post,
            url: components,
            headers: [Header(key: "Content-Type", value: "application/json")],
            body: .json(#"{"name":"test"}"#)
        )
        let curl = converter.generate(from: request)
        XCTAssertTrue(curl.contains("-X POST"))
        XCTAssertTrue(curl.contains("api.example.com/users"))
        XCTAssertTrue(curl.contains("application/json"))
    }
}
