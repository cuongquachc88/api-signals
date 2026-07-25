import Foundation
import GRDB
import APISignalsCore

public actor GRDBWorkspaceRepository: WorkspaceRepository {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func all() async throws -> [Workspace] {
        try await dbPool.read { db in
            try WorkspaceRecord.fetchAll(db).map { $0.toWorkspace() }
        }
    }

    public func create(_ workspace: Workspace) async throws -> Workspace {
        let record = WorkspaceRecord(from: workspace)
        try await dbPool.write { [record] db in
            var record = record
            try record.insert(db)
        }
        return record.toWorkspace()
    }

    public func update(_ workspace: Workspace) async throws -> Workspace {
        var record = WorkspaceRecord(from: workspace)
        record.updatedAt = Date()
        try await dbPool.write { [record] db in
            var record = record
            try record.update(db)
        }
        return record.toWorkspace()
    }

    public func delete(id: UUID) async throws {
        try await dbPool.write { db in
            _ = try WorkspaceRecord.deleteOne(db, key: id.uuidString)
        }
    }
}

public actor GRDBCollectionRepository: CollectionRepository {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func all(in workspaceId: UUID) async throws -> [Collection] {
        try await dbPool.read { db in
            try CollectionRecord
                .filter(Column("workspace_id") == workspaceId.uuidString)
                .order(Column("sort_order"))
                .fetchAll(db)
                .map { $0.toCollection() }
        }
    }

    public func create(_ collection: Collection) async throws -> Collection {
        let record = CollectionRecord(from: collection)
        try await dbPool.write { [record] db in
            var record = record
            try record.insert(db)
        }
        return record.toCollection()
    }

    public func update(_ collection: Collection) async throws -> Collection {
        let record = CollectionRecord(from: collection)
        try await dbPool.write { [record] db in
            var record = record
            try record.update(db)
        }
        return record.toCollection()
    }

    public func delete(id: UUID) async throws {
        try await dbPool.write { db in
            _ = try CollectionRecord.deleteOne(db, key: id.uuidString)
        }
    }
}

public actor GRDBRequestRepository: RequestRepository {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func all(in collectionId: UUID) async throws -> [APIRequest] {
        try await dbPool.read { db in
            try RequestRecord
                .filter(Column("collection_id") == collectionId.uuidString)
                .order(Column("sort_order"))
                .fetchAll(db)
                .map { $0.toRequest() }
        }
    }

    public func create(_ request: APIRequest) async throws -> APIRequest {
        let record = RequestRecord(from: request)
        try await dbPool.write { [record] db in
            var record = record
            try record.insert(db)
        }
        return record.toRequest()
    }

    public func update(_ request: APIRequest) async throws -> APIRequest {
        let record = RequestRecord(from: request)
        try await dbPool.write { [record] db in
            var record = record
            try record.update(db)
        }
        return record.toRequest()
    }

    public func delete(id: UUID) async throws {
        try await dbPool.write { db in
            _ = try RequestRecord.deleteOne(db, key: id.uuidString)
        }
    }
}

public actor GRDBEnvironmentRepository: EnvironmentRepository {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func all(in workspaceId: UUID) async throws -> [Environment] {
        try await dbPool.read { db in
            try EnvironmentRecord
                .filter(Column("workspace_id") == workspaceId.uuidString)
                .order(Column("name"))
                .fetchAll(db)
                .map { $0.toEnvironment() }
        }
    }

    public func create(_ environment: Environment) async throws -> Environment {
        let record = EnvironmentRecord(from: environment)
        try await dbPool.write { [record] db in
            var record = record
            try record.insert(db)
        }
        return record.toEnvironment()
    }

    public func update(_ environment: Environment) async throws -> Environment {
        let record = EnvironmentRecord(from: environment)
        try await dbPool.write { [record] db in
            var record = record
            try record.update(db)
        }
        return record.toEnvironment()
    }

    public func delete(id: UUID) async throws {
        try await dbPool.write { db in
            _ = try EnvironmentRecord.deleteOne(db, key: id.uuidString)
        }
    }

    public func setActive(id: UUID, workspaceId: UUID) async throws {
        try await dbPool.write { db in
            try EnvironmentRecord
                .filter(Column("workspace_id") == workspaceId.uuidString)
                .updateAll(db, Column("is_active").set(to: false))

            if var record = try EnvironmentRecord.fetchOne(db, key: id.uuidString) {
                record.isActive = true
                try record.update(db)
            }
        }
    }
}

public actor GRDBHistoryRepository: HistoryRepository {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func all(in workspaceId: UUID, limit: Int?) async throws -> [HistoryEntry] {
        try await dbPool.read { db in
            var request = HistoryRecord
                .filter(Column("workspace_id") == workspaceId.uuidString)
                .order(Column("timestamp").desc)
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db).compactMap { $0.toHistoryEntry() }
        }
    }

    public func add(_ entry: HistoryEntry) async throws {
        let record = HistoryRecord(from: entry)
        try await dbPool.write { [record] db in
            var record = record
            try record.insert(db)
        }
    }

    public func delete(id: UUID) async throws {
        try await dbPool.write { db in
            _ = try HistoryRecord.deleteOne(db, key: id.uuidString)
        }
    }

    public func clear(workspaceId: UUID) async throws {
        try await dbPool.write { db in
            _ = try HistoryRecord
                .filter(Column("workspace_id") == workspaceId.uuidString)
                .deleteAll(db)
        }
    }
}
