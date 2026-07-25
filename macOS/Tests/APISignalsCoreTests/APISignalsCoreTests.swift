import XCTest
import APISignalsCore

final class APISignalsCoreTests: XCTestCase {
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
}
