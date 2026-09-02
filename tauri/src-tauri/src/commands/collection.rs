use crate::db::DbState;
use crate::models::Collection;
use rusqlite::params;
use tauri::State;
use chrono::Utc;

#[tauri::command]
pub fn get_collections(state: State<DbState>, workspace_id: String) -> Result<Vec<Collection>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT id, workspace_id, parent_id, name, description, sort_order, created_at, updated_at
             FROM collections WHERE workspace_id = ?1 ORDER BY sort_order ASC, name ASC",
        )
        .map_err(|e| e.to_string())?;

    let collections = stmt
        .query_map(params![workspace_id], |row| {
            Ok(Collection {
                id: row.get(0)?,
                workspace_id: row.get(1)?,
                parent_id: row.get(2)?,
                name: row.get(3)?,
                description: row.get(4)?,
                sort_order: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(collections)
}

#[tauri::command]
pub fn create_collection(
    state: State<DbState>,
    workspace_id: String,
    name: String,
    parent_id: Option<String>,
) -> Result<Collection, String> {
    let col = Collection::new(&workspace_id, &name, parent_id.as_deref());
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO collections (id, workspace_id, parent_id, name, description, sort_order, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            col.id, col.workspace_id, col.parent_id, col.name,
            col.description, col.sort_order, col.created_at, col.updated_at
        ],
    )
    .map_err(|e| e.to_string())?;
    Ok(col)
}

#[tauri::command]
pub fn update_collection(
    state: State<DbState>,
    id: String,
    name: String,
    description: Option<String>,
    parent_id: Option<String>,
) -> Result<Collection, String> {
    let now = Utc::now().to_rfc3339();
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE collections SET name = ?1, description = ?2, parent_id = ?3, updated_at = ?4 WHERE id = ?5",
        params![name, description, parent_id, now, id],
    )
    .map_err(|e| e.to_string())?;

    let col = conn
        .query_row(
            "SELECT id, workspace_id, parent_id, name, description, sort_order, created_at, updated_at
             FROM collections WHERE id = ?1",
            params![id],
            |row| Ok(Collection {
                id: row.get(0)?,
                workspace_id: row.get(1)?,
                parent_id: row.get(2)?,
                name: row.get(3)?,
                description: row.get(4)?,
                sort_order: row.get(5)?,
                created_at: row.get(6)?,
                updated_at: row.get(7)?,
            }),
        )
        .map_err(|e| e.to_string())?;

    Ok(col)
}

#[tauri::command]
pub fn delete_collection(state: State<DbState>, id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM collections WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn reorder_collection(state: State<DbState>, id: String, sort_order: i64) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE collections SET sort_order = ?1 WHERE id = ?2",
        params![sort_order, id],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}
