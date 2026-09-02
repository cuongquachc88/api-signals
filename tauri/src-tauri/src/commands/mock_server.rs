use crate::db::DbState;
use crate::models::{MockRoute, KeyValue};
use rusqlite::params;
use tauri::State;
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use once_cell::sync::Lazy;
use tokio::sync::oneshot;

// Global mock server state
static MOCK_SERVER_HANDLE: Lazy<Arc<Mutex<Option<oneshot::Sender<()>>>>> =
    Lazy::new(|| Arc::new(Mutex::new(None)));

static MOCK_ROUTES_CACHE: Lazy<Arc<Mutex<Vec<MockRoute>>>> =
    Lazy::new(|| Arc::new(Mutex::new(Vec::new())));

#[tauri::command]
pub fn get_mock_routes(state: State<DbState>) -> Result<Vec<MockRoute>, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT id, method, path, status_code, response_body, response_headers, delay_ms, enabled
             FROM mock_routes ORDER BY path ASC",
        )
        .map_err(|e| e.to_string())?;

    let routes = stmt
        .query_map([], |row| {
            let headers_str: String = row.get(5)?;
            let headers: Vec<KeyValue> = serde_json::from_str(&headers_str).unwrap_or_default();
            let status_code: i64 = row.get(3)?;
            let delay_ms: i64 = row.get(6)?;
            let enabled_int: i64 = row.get(7)?;
            Ok(MockRoute {
                id: row.get(0)?,
                method: row.get(1)?,
                path: row.get(2)?,
                status_code: status_code as u16,
                response_body: row.get(4)?,
                response_headers: headers,
                delay_ms: delay_ms as u64,
                enabled: enabled_int != 0,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())?;

    Ok(routes)
}

#[tauri::command]
pub fn add_mock_route(state: State<DbState>, method: String, path: String) -> Result<MockRoute, String> {
    let route = MockRoute::new(&method, &path);
    let headers_json = serde_json::to_string(&route.response_headers).map_err(|e| e.to_string())?;
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO mock_routes (id, method, path, status_code, response_body, response_headers, delay_ms, enabled)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            route.id, route.method, route.path, route.status_code as i64,
            route.response_body, headers_json, route.delay_ms as i64, 1i64
        ],
    )
    .map_err(|e| e.to_string())?;

    Ok(route)
}

#[tauri::command]
pub fn update_mock_route(state: State<DbState>, route: MockRoute) -> Result<MockRoute, String> {
    let headers_json = serde_json::to_string(&route.response_headers).map_err(|e| e.to_string())?;
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE mock_routes SET method=?1, path=?2, status_code=?3, response_body=?4,
                  response_headers=?5, delay_ms=?6, enabled=?7
         WHERE id=?8",
        params![
            route.method, route.path, route.status_code as i64, route.response_body,
            headers_json, route.delay_ms as i64, if route.enabled { 1i64 } else { 0i64 },
            route.id
        ],
    )
    .map_err(|e| e.to_string())?;

    Ok(route)
}

#[tauri::command]
pub fn delete_mock_route(state: State<DbState>, id: String) -> Result<(), String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM mock_routes WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn get_mock_server_status() -> Result<bool, String> {
    let handle = MOCK_SERVER_HANDLE.lock().map_err(|e| e.to_string())?;
    Ok(handle.is_some())
}

#[tauri::command]
pub async fn start_mock_server(state: State<'_, DbState>, port: u16) -> Result<String, String> {
    {
        let handle = MOCK_SERVER_HANDLE.lock().map_err(|e| e.to_string())?;
        if handle.is_some() {
            return Err("Mock server is already running".to_string());
        }
    }

    // Load routes into cache
    let routes = get_mock_routes(state)?;
    {
        let mut cache = MOCK_ROUTES_CACHE.lock().map_err(|e| e.to_string())?;
        *cache = routes;
    }

    let routes_cache = MOCK_ROUTES_CACHE.clone();
    let (tx, rx) = oneshot::channel::<()>();

    {
        let mut handle = MOCK_SERVER_HANDLE.lock().map_err(|e| e.to_string())?;
        *handle = Some(tx);
    }

    tokio::spawn(async move {
        use axum::{routing::any, Router, response::Response, body::Body, http::{Request, StatusCode}};

        let app = Router::new().route("/*path", any(move |req: Request<Body>| {
            let cache = routes_cache.clone();
            async move {
                let method = req.method().as_str().to_uppercase();
                let path = req.uri().path().to_string();

                // Extract route info without holding the lock across await
                let matched = {
                    let routes = cache.lock().unwrap();
                    routes.iter().find(|route| {
                        if !route.enabled { return false; }
                        let route_method = route.method.to_uppercase();
                        (route_method == method || route_method == "ANY") && path == route.path
                    }).cloned()
                };

                if let Some(route) = matched {
                    if route.delay_ms > 0 {
                        tokio::time::sleep(std::time::Duration::from_millis(route.delay_ms)).await;
                    }
                    let mut resp = Response::builder().status(route.status_code);
                    for h in &route.response_headers {
                        if h.enabled {
                            resp = resp.header(h.key.as_str(), h.value.as_str());
                        }
                    }
                    resp.body(Body::from(route.response_body.clone()))
                        .unwrap_or_else(|_| Response::new(Body::empty()))
                } else {
                    Response::builder()
                        .status(StatusCode::NOT_FOUND)
                        .body(Body::from(r#"{"error":"No matching route"}"#))
                        .unwrap()
                }
            }
        }));

        let addr = format!("127.0.0.1:{}", port);
        let listener = match tokio::net::TcpListener::bind(&addr).await {
            Ok(l) => l,
            Err(_) => return,
        };

        axum::serve(listener, app)
            .with_graceful_shutdown(async { let _ = rx.await; })
            .await
            .ok();

        let mut handle = MOCK_SERVER_HANDLE.lock().unwrap();
        *handle = None;
    });

    Ok(format!("Mock server started on port {}", port))
}

#[tauri::command]
pub fn stop_mock_server() -> Result<(), String> {
    let mut handle = MOCK_SERVER_HANDLE.lock().map_err(|e| e.to_string())?;
    if let Some(tx) = handle.take() {
        let _ = tx.send(());
        Ok(())
    } else {
        Err("Mock server is not running".to_string())
    }
}
