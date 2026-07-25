import XCTest
import APISignalsCore
@testable import APISignalsScripting

final class APISignalsScriptingTests: XCTestCase {
    @MainActor
    func testRunnerExists() {
        let runner = JavaScriptCoreRunner()
        XCTAssertNotNil(runner)
    }

    @MainActor
    func testPreRequestScriptSetsEnvironmentVariable() async {
        let runner = JavaScriptCoreRunner()
        let request = APIRequest(name: "Test")
        let result = await runner.runPreRequest(
            script: #"pm.environment.set("token", "abc123");"#,
            request: request,
            environment: nil
        )
        XCTAssertEqual(result.environmentVariables["token"], "abc123")
        XCTAssertTrue(result.errors.isEmpty)
    }

    @MainActor
    func testScriptCanReadEnvironmentVariable() async {
        let runner = JavaScriptCoreRunner()
        let request = APIRequest(name: "Test")
        let environment = Environment(workspaceId: UUID(), name: "Test", variables: [
            Variable(key: "baseUrl", value: "https://api.example.com")
        ])
        let result = await runner.runPreRequest(
            script: """
            var url = pm.environment.get("baseUrl");
            pm.environment.set("resolvedUrl", url + "/users");
            """,
            request: request,
            environment: environment
        )
        XCTAssertEqual(result.environmentVariables["resolvedUrl"], "https://api.example.com/users")
    }

    @MainActor
    func testScriptErrorsAreCaptured() async {
        let runner = JavaScriptCoreRunner()
        let request = APIRequest(name: "Test")
        let result = await runner.runPreRequest(
            script: "this is not valid javascript $$$$;",
            request: request,
            environment: nil
        )
        XCTAssertFalse(result.errors.isEmpty)
    }

    @MainActor
    func testEmptyScriptReturnsEmptyResult() async {
        let runner = JavaScriptCoreRunner()
        let request = APIRequest(name: "Test")
        let result = await runner.runPreRequest(
            script: "   ",
            request: request,
            environment: nil
        )
        XCTAssertTrue(result.environmentVariables.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.tests.isEmpty)
    }

    @MainActor
    func testScriptPmGlobalsAndCollectionVariables() async {
        let runner = JavaScriptCoreRunner()
        let request = APIRequest(name: "Test")
        let result = await runner.runPreRequest(
            script: """
            pm.globals.set("globalKey", "globalValue");
            pm.collectionVariables.set("collKey", "collValue");
            """,
            request: request,
            environment: nil
        )
        XCTAssertEqual(result.globalVariables["globalKey"], "globalValue")
        XCTAssertEqual(result.collectionVariables["collKey"], "collValue")
    }

    @MainActor
    func testPostResponseScriptRunsTests() async {
        let runner = JavaScriptCoreRunner()
        let request = APIRequest(name: "Test")
        let response = APIResponse(
            statusCode: 200,
            statusText: "OK",
            body: #"{"ok":true}"#.data(using: .utf8)
        )
        let result = await runner.runPostResponse(
            script: """
            pm.test("Status code is 200", function() {
                return pm.response.code === 200;
            });
            pm.test("Body has ok", function() {
                var json = pm.response.json();
                return json !== null;
            });
            """,
            request: request,
            response: response,
            environment: nil
        )
        XCTAssertEqual(result.tests.count, 2)
        XCTAssertTrue(result.tests[0].passed)
        XCTAssertTrue(result.tests[1].passed)
    }
}
