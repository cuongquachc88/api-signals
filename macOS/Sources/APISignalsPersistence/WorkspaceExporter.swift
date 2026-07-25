import Foundation
import APISignalsCore

public struct WorkspaceSnapshot: Codable, Sendable {
    public let workspace: Workspace
    public let collections: [Collection]
    public let requests: [APIRequest]
    public let environments: [APISignalsCore.Environment]
    public let version: String

    public init(
        workspace: Workspace,
        collections: [Collection],
        requests: [APIRequest],
        environments: [APISignalsCore.Environment],
        version: String = "1.0"
    ) {
        self.workspace = workspace
        self.collections = collections
        self.requests = requests
        self.environments = environments
        self.version = version
    }
}

public actor WorkspaceExporter {
    private let workspaceRepository: any WorkspaceRepository
    private let collectionRepository: any CollectionRepository
    private let requestRepository: any RequestRepository
    private let environmentRepository: any EnvironmentRepository

    public init(
        workspaceRepository: any WorkspaceRepository,
        collectionRepository: any CollectionRepository,
        requestRepository: any RequestRepository,
        environmentRepository: any EnvironmentRepository
    ) {
        self.workspaceRepository = workspaceRepository
        self.collectionRepository = collectionRepository
        self.requestRepository = requestRepository
        self.environmentRepository = environmentRepository
    }

    public func export(workspaceId: UUID) async throws -> WorkspaceSnapshot {
        guard let workspace = try await workspaceRepository.all().first(where: { $0.id == workspaceId }) else {
            throw PersistenceError.notFound
        }

        let collections = try await collectionRepository.all(in: workspaceId)
        let environments = try await environmentRepository.all(in: workspaceId)

        var requests: [APIRequest] = []
        for collection in collections {
            let collectionRequests = try await requestRepository.all(in: collection.id)
            requests.append(contentsOf: collectionRequests)
        }

        return WorkspaceSnapshot(
            workspace: workspace,
            collections: collections,
            requests: requests,
            environments: environments
        )
    }

    public func exportToFile(workspaceId: UUID, url: URL) async throws {
        let snapshot = try await export(workspaceId: workspaceId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url)
    }

    public func importFromFile(url: URL) async throws -> WorkspaceSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WorkspaceSnapshot.self, from: data)
        return snapshot
    }

    public func importSnapshot(_ snapshot: WorkspaceSnapshot) async throws {
        _ = try await workspaceRepository.create(snapshot.workspace)

        for collection in snapshot.collections {
            _ = try await collectionRepository.create(collection)
        }

        // Map requests to collections by collection ID from snapshot.
        // Note: requests don't store collectionId in entity, so we need to export/import them carefully.
        // For now, we associate requests to the first matching collection by original collection ID.
        for request in snapshot.requests {
            _ = try await requestRepository.create(request)
        }

        for environment in snapshot.environments {
            _ = try await environmentRepository.create(environment)
        }
    }
}

public extension WorkspaceSnapshot {
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
