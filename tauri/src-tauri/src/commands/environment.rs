use crate::db::DbState;
use crate::models::{Environment, Variable};
use rusqlite::params;
use tauri::State;
use chrono::Utc;

fn row_to_env(row: &rusqlite::Row<'_>) -> rusqlite::Result<Environment> {
    let vars_str: String = row.get(3)?;
    let variables: Vec<Variable> = serde_json::from_str(&vars_str).unwrap_or_default();
    let is_active_int: i64 = row.get(4)?;
    Ok(Environment {
        id: row.get(0)?,
        workspace_id: row.get(1)?,
        name: row.get(2)?,
        variables,
        is_active: is_active_int != 0,
        created_at: row.get(5)?,
        updated_at: row.get(6)?,
    })
}

#[tauri::command]
pub fn get_environments(state: State<DbState>, workspace_id: String) -> Result<Vec<Environment>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT id, workspace_id, name, variables, is_active, created_at, updated_at
             FROM environments WHERE workspace_id = ?1 ORDER BY name ASC",
        )
        .map_err(|e| e.to_string())?;

    let envs = stmt
        .query_map(params![workspace_id], row_to_env)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(envs)
}

#[tauri::command]
pub fn create_environment(
    state: State<DbState>,
    workspace_id: String,
    name: String,
) -> Result<Environment, String> {
    let env = Environment::new(&workspace_id, &name);
    let vars_json = serde_json::to_string(&env.variables).map_err(|e| e.to_string())?;

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO environments (id, workspace_id, name, variables, is_active, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![env.id, env.workspace_id, env.name, vars_json, 0i64, env.created_at, env.updated_at],
    )
    .map_err(|e| e.to_string())?;

    Ok(env)
}

#[tauri::command]
pub fn update_environment(state: State<DbState>, environment: Environment) -> Result<Environment, String> {
    let now = Utc::now().to_rfc3339();
    let vars_json = serde_json::to_string(&environment.variables).map_err(|e| e.to_string())?;
    let is_active = if environment.is_active { 1i64 } else { 0i64 };

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE environments SET name=?1, variables=?2, is_active=?3, updated_at=?4 WHERE id=?5",
        params![environment.name, vars_json, is_active, now, environment.id],
    )
    .map_err(|e| e.to_string())?;

    let mut updated = environment;
    updated.updated_at = now;
    Ok(updated)
}

#[tauri::command]
pub fn delete_environment(state: State<DbState>, id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM environments WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn set_active_environment(
    state: State<DbState>,
    workspace_id: String,
    environment_id: Option<String>,
) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    // Deactivate all in workspace
    conn.execute(
        "UPDATE environments SET is_active = 0 WHERE workspace_id = ?1",
        params![workspace_id],
    )
    .map_err(|e| e.to_string())?;

    // Activate selected one
    if let Some(env_id) = environment_id {
        conn.execute(
            "UPDATE environments SET is_active = 1 WHERE id = ?1",
            params![env_id],
        )
        .map_err(|e| e.to_string())?;
    }

    Ok(())
}
