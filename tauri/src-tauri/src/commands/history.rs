use crate::db::DbState;
use crate::models::HistoryEntry;
use rusqlite::params;
use tauri::State;

#[tauri::command]
pub fn get_history(state: State<DbState>, workspace_id: String, limit: Option<i64>) -> Result<Vec<HistoryEntry>, String> {
    let limit = limit.unwrap_or(100);
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT id, workspace_id, request_name, method, url, status, duration_ms, response_size,
                    timestamp, request_snapshot, response_snapshot
             FROM history WHERE workspace_id = ?1 ORDER BY timestamp DESC LIMIT ?2",
        )
        .map_err(|e| e.to_string())?;

    let entries = stmt
        .query_map(params![workspace_id, limit], |row| {
            let status: i64 = row.get(5)?;
            let response_size: i64 = row.get(7)?;
            Ok(HistoryEntry {
                id: row.get(0)?,
                workspace_id: row.get(1)?,
                request_name: row.get(2)?,
                method: row.get(3)?,
                url: row.get(4)?,
                status: status as u16,
                duration_ms: row.get(6)?,
                response_size: response_size as u64,
                timestamp: row.get(8)?,
                request_snapshot: row.get(9)?,
                response_snapshot: row.get(10)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(entries)
}

#[tauri::command]
pub fn add_history_entry(state: State<DbState>, entry: HistoryEntry) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO history (id, workspace_id, request_name, method, url, status, duration_ms,
                              response_size, timestamp, request_snapshot, response_snapshot)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
        params![
            entry.id, entry.workspace_id, entry.request_name, entry.method, entry.url,
            entry.status as i64, entry.duration_ms, entry.response_size as i64,
            entry.timestamp, entry.request_snapshot, entry.response_snapshot
        ],
    )
    .map_err(|e| e.to_string())?;

    // Keep only last 500 entries per workspace
    conn.execute(
        "DELETE FROM history WHERE workspace_id = ?1 AND id NOT IN (
            SELECT id FROM history WHERE workspace_id = ?1 ORDER BY timestamp DESC LIMIT 500
         )",
        params![entry.workspace_id],
    )
    .map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub fn clear_history(state: State<DbState>, workspace_id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM history WHERE workspace_id = ?1", params![workspace_id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn delete_history_entry(state: State<DbState>, id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM history WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}
