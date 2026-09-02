use crate::db::DbState;
use crate::models::{APIRequest, Auth, RequestBody, KeyValue};
use rusqlite::params;
use tauri::State;
use chrono::Utc;

fn row_to_request(row: &rusqlite::Row<'_>) -> rusqlite::Result<APIRequest> {
    let headers_str: String = row.get(6)?;
    let params_str: String = row.get(7)?;
    let body_str: String = row.get(8)?;
    let auth_str: String = row.get(9)?;

    let headers: Vec<KeyValue> = serde_json::from_str(&headers_str).unwrap_or_default();
    let params: Vec<KeyValue> = serde_json::from_str(&params_str).unwrap_or_default();
    let body: RequestBody = serde_json::from_str(&body_str).unwrap_or(RequestBody::None);
    let auth: Auth = serde_json::from_str(&auth_str).unwrap_or(Auth::None);

    Ok(APIRequest {
        id: row.get(0)?,
        collection_id: row.get(1)?,
        workspace_id: row.get(2)?,
        name: row.get(3)?,
        method: row.get(4)?,
        url: row.get(5)?,
        headers,
        params,
        body,
        auth,
        pre_request_script: row.get(10)?,
        post_response_script: row.get(11)?,
        description: row.get(12)?,
        sort_order: row.get(13)?,
        created_at: row.get(14)?,
        updated_at: row.get(15)?,
    })
}

#[tauri::command]
pub fn get_requests(state: State<DbState>, collection_id: String) -> Result<Vec<APIRequest>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT id, collection_id, workspace_id, name, method, url, headers, params, body, auth,
                    pre_request_script, post_response_script, description, sort_order, created_at, updated_at
             FROM requests WHERE collection_id = ?1 ORDER BY sort_order ASC, name ASC",
        )
        .map_err(|e| e.to_string())?;

    let requests = stmt
        .query_map(params![collection_id], row_to_request)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(requests)
}

#[tauri::command]
pub fn get_all_requests(state: State<DbState>, workspace_id: String) -> Result<Vec<APIRequest>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT id, collection_id, workspace_id, name, method, url, headers, params, body, auth,
                    pre_request_script, post_response_script, description, sort_order, created_at, updated_at
             FROM requests WHERE workspace_id = ?1 ORDER BY collection_id, sort_order ASC",
        )
        .map_err(|e| e.to_string())?;

    let requests = stmt
        .query_map(params![workspace_id], row_to_request)
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(requests)
}

#[tauri::command]
pub fn create_request(
    state: State<DbState>,
    collection_id: String,
    workspace_id: String,
    name: String,
) -> Result<APIRequest, String> {
    let req = APIRequest::new(&collection_id, &workspace_id, &name);
    let headers_json = serde_json::to_string(&req.headers).map_err(|e| e.to_string())?;
    let params_json = serde_json::to_string(&req.params).map_err(|e| e.to_string())?;
    let body_json = serde_json::to_string(&req.body).map_err(|e| e.to_string())?;
    let auth_json = serde_json::to_string(&req.auth).map_err(|e| e.to_string())?;

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO requests (id, collection_id, workspace_id, name, method, url, headers, params, body, auth,
                               pre_request_script, post_response_script, description, sort_order, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16)",
        params![
            req.id, req.collection_id, req.workspace_id, req.name, req.method, req.url,
            headers_json, params_json, body_json, auth_json,
            req.pre_request_script, req.post_response_script, req.description,
            req.sort_order, req.created_at, req.updated_at
        ],
    )
    .map_err(|e| e.to_string())?;

    Ok(req)
}

#[tauri::command]
pub fn update_request(state: State<DbState>, request: APIRequest) -> Result<APIRequest, String> {
    let now = Utc::now().to_rfc3339();
    let headers_json = serde_json::to_string(&request.headers).map_err(|e| e.to_string())?;
    let params_json = serde_json::to_string(&request.params).map_err(|e| e.to_string())?;
    let body_json = serde_json::to_string(&request.body).map_err(|e| e.to_string())?;
    let auth_json = serde_json::to_string(&request.auth).map_err(|e| e.to_string())?;

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE requests SET name=?1, method=?2, url=?3, headers=?4, params=?5, body=?6, auth=?7,
                  pre_request_script=?8, post_response_script=?9, description=?10, sort_order=?11,
                  updated_at=?12
         WHERE id = ?13",
        params![
            request.name, request.method, request.url,
            headers_json, params_json, body_json, auth_json,
            request.pre_request_script, request.post_response_script,
            request.description, request.sort_order, now, request.id
        ],
    )
    .map_err(|e| e.to_string())?;

    let mut updated = request;
    updated.updated_at = now;
    Ok(updated)
}

#[tauri::command]
pub fn delete_request(state: State<DbState>, id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM requests WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn duplicate_request(state: State<DbState>, id: String) -> Result<APIRequest, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let original = conn
        .query_row(
            "SELECT id, collection_id, workspace_id, name, method, url, headers, params, body, auth,
                    pre_request_script, post_response_script, description, sort_order, created_at, updated_at
             FROM requests WHERE id = ?1",
            params![id],
            row_to_request,
        )
        .map_err(|e| e.to_string())?;

    let now = Utc::now().to_rfc3339();
    let new_id = uuid::Uuid::new_v4().to_string();
    let new_name = format!("{} (Copy)", original.name);
    let headers_json = serde_json::to_string(&original.headers).map_err(|e| e.to_string())?;
    let params_json = serde_json::to_string(&original.params).map_err(|e| e.to_string())?;
    let body_json = serde_json::to_string(&original.body).map_err(|e| e.to_string())?;
    let auth_json = serde_json::to_string(&original.auth).map_err(|e| e.to_string())?;

    conn.execute(
        "INSERT INTO requests (id, collection_id, workspace_id, name, method, url, headers, params, body, auth,
                               pre_request_script, post_response_script, description, sort_order, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16)",
        params![
            new_id, original.collection_id, original.workspace_id, new_name,
            original.method, original.url, headers_json, params_json, body_json, auth_json,
            original.pre_request_script, original.post_response_script, original.description,
            original.sort_order + 1, now.clone(), now.clone()
        ],
    )
    .map_err(|e| e.to_string())?;

    let mut new_req = original;
    new_req.id = new_id;
    new_req.name = new_name;
    new_req.created_at = now.clone();
    new_req.updated_at = now;
    Ok(new_req)
}
