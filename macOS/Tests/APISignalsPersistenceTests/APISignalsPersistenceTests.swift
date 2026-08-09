import XCTest
import GRDB
import APISignalsCore
@testable import APISignalsPersistence

final class APISignalsPersistenceTests: XCTestCase {
    private var dbPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        dbPath = tempDir.appendingPathComponent("\(UUID().uuidString).sqlite").path
    }

    override func tearDown() {
        if let dbPath = dbPath {
            try? FileManager.default.removeItem(atPath: dbPath)
        }
        super.tearDown()
    }

    func testPersistenceInitialization() throws {
        let persistence = try GRDBPersistence(path: dbPath)
        XCTAssertNotNil(persistence)
    }

    func testWorkspaceRepository() async throws {
        let persistence = try GRDBPersistence(path: dbPath)
        let repository = GRDBWorkspaceRepository(dbPool: persistence.dbPool)

        let workspace = Workspace(name: "Test Workspace")
        let created = try await repository.create(workspace)
        XCTAssertEqual(created.name, workspace.name)

        let all = try await repository.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Test Workspace")

        var updated = created
        updated.name = "Updated Workspace"
        _ = try await repository.update(updated)

        let allUpdated = try await repository.all()
        XCTAssertEqual(allUpdated.first?.name, "Updated Workspace")
    }

    func testCollectionRepository() async throws {
        let persistence = try GRDBPersistence(path: dbPath)
        let workspaceRepo = GRDBWorkspaceRepository(dbPool: persistence.dbPool)
        let collectionRepo = GRDBCollectionRepository(dbPool: persistence.dbPool)

        let workspace = try await workspaceRepo.create(Workspace(name: "Test"))
        let collection = Collection(workspaceId: workspace.id, name: "My Collection")
        let created = try await collectionRepo.create(collection)
        XCTAssertEqual(created.name, "My Collection")

        let all = try await collectionRepo.all(in: workspace.id)
        XCTAssertEqual(all.count, 1)
    }

    func testRequestRepository() async throws {
        let persistence = try GRDBPersistence(path: dbPath)
        let workspaceRepo = GRDBWorkspaceRepository(dbPool: persistence.dbPool)
        let collectionRepo = GRDBCollectionRepository(dbPool: persistence.dbPool)
        let requestRepo = GRDBRequestRepository(dbPool: persistence.dbPool)

        let workspace = try await workspaceRepo.create(Workspace(name: "Test"))
        let collection = try await collectionRepo.create(Collection(workspaceId: workspace.id, name: "My Collection"))

        let request = APIRequest(collectionId: collection.id, name: "Get Users", method: .get)
        let created = try await requestRepo.create(request)
        XCTAssertEqual(created.name, "Get Users")
        XCTAssertEqual(created.collectionId, collection.id)

        let all = try await requestRepo.all(in: collection.id)
        XCTAssertEqual(all.count, 1)
    }

    func testEnvironmentRepository() async throws {
        let persistence = try GRDBPersistence(path: dbPath)
        let workspaceRepo = GRDBWorkspaceRepository(dbPool: persistence.dbPool)
        let envRepo = GRDBEnvironmentRepository(dbPool: persistence.dbPool)

        let workspace = try await workspaceRepo.create(Workspace(name: "Test"))
        let environment = Environment(workspaceId: workspace.id, name: "Production")
        let created = try await envRepo.create(environment)
        XCTAssertEqual(created.name, "Production")

        try await envRepo.setActive(id: created.id, workspaceId: workspace.id)
        let all = try await envRepo.all(in: workspace.id)
        XCTAssertTrue(all.first?.isActive == true)
    }

    func testWorkspaceExporter() async throws {
        let persistence = try GRDBPersistence(path: dbPath)
        let workspaceRepo = GRDBWorkspaceRepository(dbPool: persistence.dbPool)
        let collectionRepo = GRDBCollectionRepository(dbPool: persistence.dbPool)
        let requestRepo = GRDBRequestRepository(dbPool: persistence.dbPool)
        let envRepo = GRDBEnvironmentRepository(dbPool: persistence.dbPool)

        let exporter = WorkspaceExporter(
            workspaceRepository: workspaceRepo,
            collectionRepository: collectionRepo,
            requestRepository: requestRepo,
            environmentRepository: envRepo
        )

        let workspace = try await workspaceRepo.create(Workspace(name: "Export Test"))
        let collection = try await collectionRepo.create(Collection(workspaceId: workspace.id, name: "My Collection"))
        _ = try await requestRepo.create(APIRequest(collectionId: collection.id, name: "Test Request"))
        _ = try await envRepo.create(Environment(workspaceId: workspace.id, name: "Production"))

        let snapshot = try await exporter.export(workspaceId: workspace.id)
        XCTAssertEqual(snapshot.workspace.name, "Export Test")
        XCTAssertEqual(snapshot.collections.count, 1)
        XCTAssertEqual(snapshot.requests.count, 1)
        XCTAssertEqual(snapshot.environments.count, 1)
    }

    // MARK: - Postman GraphQL import / export

    func testPostmanGraphQLVariablesAsString() throws {
        let json = """
        {
          "info": { "_postman_id": "1", "name": "GQL Coll", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
          "item": [{
            "name": "Hero",
            "request": {
              "method": "POST",
              "header": [],
              "body": {
                "mode": "graphql",
                "graphql": {
                  "query": "query Hero($ep: Episode!) { hero(episode: $ep) { name } }",
                  "variables": "{\\"ep\\":\\"JEDI\\"}"
                }
              },
              "url": { "raw": "https://api.example.com/graphql", "host": ["api","example","com"], "path": ["graphql"] }
            }
          }]
        }
        """
        let collection = try JSONDecoder().decode(PostmanCollection.self, from: Data(json.utf8))
        let converter = PostmanCollectionConverter()
        let (_, requests) = converter.convert(postmanCollection: collection, workspaceId: UUID())
        XCTAssertEqual(requests.count, 1)
        guard case .graphql(let query, let variables) = requests[0].body else {
            return XCTFail("Expected graphql body")
        }
        XCTAssertTrue(query.contains("hero(episode: $ep)"))
        XCTAssertTrue(variables.contains("JEDI"))
    }

    func testPostmanGraphQLVariablesAsObject() throws {
        let json = """
        {
          "info": { "_postman_id": "2", "name": "GQL Obj", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
          "item": [{
            "name": "User",
            "request": {
              "method": "POST",
              "header": [],
              "body": {
                "mode": "graphql",
                "graphql": {
                  "query": "query($id: ID!) { user(id: $id) { name } }",
                  "variables": { "id": "42", "active": true }
                }
              },
              "url": { "raw": "https://api.example.com/graphql", "protocol": "https", "host": ["api","example","com"], "path": ["graphql"] }
            }
          }]
        }
        """
        let collection = try JSONDecoder().decode(PostmanCollection.self, from: Data(json.utf8))
        let gql = try XCTUnwrap(collection.item.first?.request?.body?.graphql)
        XCTAssertEqual(gql.query, "query($id: ID!) { user(id: $id) { name } }")
        let vars = try JSONSerialization.jsonObject(with: Data(gql.variables.utf8)) as? [String: Any]
        XCTAssertEqual(vars?["id"] as? String, "42")
        XCTAssertEqual(vars?["active"] as? Bool, true)

        let converter = PostmanCollectionConverter()
        let (_, requests) = converter.convert(postmanCollection: collection, workspaceId: UUID())
        guard case .graphql(_, let variables) = requests[0].body else {
            return XCTFail("Expected graphql body")
        }
        XCTAssertTrue(variables.contains("42"))
    }

    func testPostmanGraphQLExportRoundTrip() throws {
        let request = APIRequest(
            name: "GQL",
            method: .post,
            url: URLComponents(string: "https://api.example.com/graphql")!,
            body: .graphql(
                query: "query Q { ping }",
                variables: #"{"n":1}"#
            )
        )
        let converter = PostmanCollectionConverter()
        let postman = converter.convert(
            collection: Collection(workspaceId: UUID(), name: "Out"),
            requests: [request]
        )
        let data = try JSONEncoder().encode(postman)
        let decoded = try JSONDecoder().decode(PostmanCollection.self, from: data)
        let gql = try XCTUnwrap(decoded.item.first?.request?.body?.graphql)
        XCTAssertEqual(gql.query, "query Q { ping }")
        XCTAssertEqual(gql.variables, #"{"n":1}"#)
    }
}
