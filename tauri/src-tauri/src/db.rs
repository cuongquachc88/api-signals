use rusqlite::{Connection, Result, params};
use std::sync::Mutex;

pub struct DbState(pub Mutex<Connection>);

pub fn init_db(db_path: &str) -> Result<Connection> {
    let conn = Connection::open(db_path)?;
    conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;")?;
    run_migrations(&conn)?;
    Ok(conn)
}

fn run_migrations(conn: &Connection) -> Result<()> {
    conn.execute_batch("
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER NOT NULL
        );
    ")?;

    let version: i64 = conn
        .query_row(
            "SELECT COALESCE(MAX(version), 0) FROM schema_version",
            [],
            |r| r.get(0),
        )
        .unwrap_or(0);

    if version < 1 {
        conn.execute_batch("
            CREATE TABLE IF NOT EXISTS workspaces (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS collections (
                id TEXT PRIMARY KEY NOT NULL,
                workspace_id TEXT NOT NULL,
                parent_id TEXT,
                name TEXT NOT NULL,
                description TEXT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS requests (
                id TEXT PRIMARY KEY NOT NULL,
                collection_id TEXT NOT NULL,
                workspace_id TEXT NOT NULL,
                name TEXT NOT NULL,
                method TEXT NOT NULL DEFAULT 'GET',
                url TEXT NOT NULL DEFAULT '',
                headers TEXT NOT NULL DEFAULT '[]',
                params TEXT NOT NULL DEFAULT '[]',
                body TEXT NOT NULL DEFAULT '{\"type\":\"None\"}',
                auth TEXT NOT NULL DEFAULT '{\"type\":\"None\"}',
                pre_request_script TEXT NOT NULL DEFAULT '',
                post_response_script TEXT NOT NULL DEFAULT '',
                description TEXT NOT NULL DEFAULT '',
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS environments (
                id TEXT PRIMARY KEY NOT NULL,
                workspace_id TEXT NOT NULL,
                name TEXT NOT NULL,
                variables TEXT NOT NULL DEFAULT '[]',
                is_active INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS history (
                id TEXT PRIMARY KEY NOT NULL,
                workspace_id TEXT NOT NULL,
                request_name TEXT NOT NULL,
                method TEXT NOT NULL,
                url TEXT NOT NULL,
                status INTEGER NOT NULL DEFAULT 0,
                duration_ms REAL NOT NULL DEFAULT 0,
                response_size INTEGER NOT NULL DEFAULT 0,
                timestamp TEXT NOT NULL,
                request_snapshot TEXT NOT NULL DEFAULT '{}',
                response_snapshot TEXT NOT NULL DEFAULT '{}'
            );

            CREATE TABLE IF NOT EXISTS mock_routes (
                id TEXT PRIMARY KEY NOT NULL,
                method TEXT NOT NULL,
                path TEXT NOT NULL,
                status_code INTEGER NOT NULL DEFAULT 200,
                response_body TEXT NOT NULL DEFAULT '',
                response_headers TEXT NOT NULL DEFAULT '[]',
                delay_ms INTEGER NOT NULL DEFAULT 0,
                enabled INTEGER NOT NULL DEFAULT 1
            );

            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );

            INSERT OR IGNORE INTO settings (key, value) VALUES
                ('theme', '\"dark\"'),
                ('timeout_ms', '30000'),
                ('ssl_verify', 'true'),
                ('proxy_url', 'null'),
                ('follow_redirects', 'true'),
                ('max_redirects', '10');

            INSERT INTO schema_version (version) VALUES (1);
        ")?;

        // Create a default workspace
        let now = chrono::Utc::now().to_rfc3339();
        let workspace_id = uuid::Uuid::new_v4().to_string();
        conn.execute(
            "INSERT OR IGNORE INTO workspaces (id, name, created_at, updated_at) VALUES (?1, ?2, ?3, ?4)",
            params![workspace_id, "My Workspace", now, now],
        )?;
    }

    Ok(())
}
