use crate::db::DbState;
use crate::models::Workspace;
use rusqlite::params;
use tauri::State;
use chrono::Utc;

#[tauri::command]
pub fn get_workspaces(state: State<DbState>) -> Result<Vec<Workspace>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare("SELECT id, name, created_at, updated_at FROM workspaces ORDER BY created_at ASC")
        .map_err(|e| e.to_string())?;

    let workspaces = stmt
        .query_map([], |row| {
            Ok(Workspace {
                id: row.get(0)?,
                name: row.get(1)?,
                created_at: row.get(2)?,
                updated_at: row.get(3)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(workspaces)
}

#[tauri::command]
pub fn create_workspace(state: State<DbState>, name: String) -> Result<Workspace, String> {
    let ws = Workspace::new(&name);
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO workspaces (id, name, created_at, updated_at) VALUES (?1, ?2, ?3, ?4)",
        params![ws.id, ws.name, ws.created_at, ws.updated_at],
    )
    .map_err(|e| e.to_string())?;
    Ok(ws)
}

#[tauri::command]
pub fn update_workspace(state: State<DbState>, id: String, name: String) -> Result<Workspace, String> {
    let now = Utc::now().to_rfc3339();
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE workspaces SET name = ?1, updated_at = ?2 WHERE id = ?3",
        params![name, now, id],
    )
    .map_err(|e| e.to_string())?;

    let ws = conn
        .query_row(
            "SELECT id, name, created_at, updated_at FROM workspaces WHERE id = ?1",
            params![id],
            |row| Ok(Workspace {
                id: row.get(0)?,
                name: row.get(1)?,
                created_at: row.get(2)?,
                updated_at: row.get(3)?,
            }),
        )
        .map_err(|e| e.to_string())?;

    Ok(ws)
}

#[tauri::command]
pub fn delete_workspace(state: State<DbState>, id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM workspaces WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}
