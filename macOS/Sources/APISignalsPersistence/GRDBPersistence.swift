import Foundation
import GRDB
import APISignalsCore

public final class GRDBPersistence {
    public let dbPool: DatabasePool

    public init(path: String) throws {
        dbPool = try DatabasePool(path: path)
        try migrate()
    }

    public convenience init(workspaceId: UUID, baseDirectory: URL) throws {
        let directory = baseDirectory.appendingPathComponent(workspaceId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbPath = directory.appendingPathComponent("workspace.sqlite").path
        try self.init(path: dbPath)
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "workspaces") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "collections") { t in
                t.column("id", .text).primaryKey()
                t.column("workspace_id", .text).notNull().indexed()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("parent_id", .text)
                t.column("sort_order", .integer).notNull()
                t.column("variables_json", .text)
                t.column("auth_json", .text)
                t.column("pre_request_script", .text)
                t.column("post_response_script", .text)
            }

            try db.create(table: "requests") { t in
                t.column("id", .text).primaryKey()
                t.column("collection_id", .text).notNull().indexed()
                t.column("name", .text).notNull()
                t.column("method", .text).notNull()
                t.column("url", .text).notNull()
                t.column("headers_json", .text)
                t.column("query_params_json", .text)
                t.column("body_json", .text)
                t.column("auth_json", .text)
                t.column("scripts_json", .text)
                t.column("settings_json", .text)
                t.column("sort_order", .integer).notNull()
            }

            try db.create(table: "environments") { t in
                t.column("id", .text).primaryKey()
                t.column("workspace_id", .text).notNull().indexed()
                t.column("name", .text).notNull()
                t.column("is_active", .boolean).notNull()
                t.column("variables_json", .text)
            }

            try db.create(table: "history") { t in
                t.column("id", .text).primaryKey()
                t.column("workspace_id", .text).notNull().indexed()
                t.column("request_json", .text).notNull()
                t.column("response_json", .text)
                t.column("timestamp", .datetime).notNull()
            }
        }

        try migrator.migrate(dbPool)
    }
}
