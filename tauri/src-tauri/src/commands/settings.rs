use crate::db::DbState;
use crate::models::AppSettings;
use rusqlite::params;
use tauri::State;

#[tauri::command]
pub fn get_settings(state: State<DbState>) -> Result<AppSettings, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;
    let mut stmt = conn.prepare("SELECT key, value FROM settings").map_err(|e| e.to_string())?;
    let map: std::collections::HashMap<String, String> = stmt
        .query_map([], |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)))
        .map_err(|e| e.to_string())?
        .filter_map(|r| r.ok())
        .collect();

    Ok(AppSettings {
        theme: serde_json::from_str(map.get("theme").map(|s| s.as_str()).unwrap_or("\"dark\""))
            .unwrap_or_else(|_| "dark".to_string()),
        timeout_ms: map.get("timeout_ms")
            .and_then(|v| v.parse().ok())
            .unwrap_or(30000),
        ssl_verify: map.get("ssl_verify")
            .map(|v| v == "true")
            .unwrap_or(true),
        proxy_url: map.get("proxy_url")
            .and_then(|v| serde_json::from_str(v).ok()),
        follow_redirects: map.get("follow_redirects")
            .map(|v| v == "true")
            .unwrap_or(true),
        max_redirects: map.get("max_redirects")
            .and_then(|v| v.parse().ok())
            .unwrap_or(10),
    })
}

#[tauri::command]
pub fn update_settings(state: State<DbState>, settings: AppSettings) -> Result<AppSettings, String> {
    let conn = state.0.lock().map_err(|e| e.to_string())?;

    let pairs: Vec<(&str, String)> = vec![
        ("theme", serde_json::to_string(&settings.theme).unwrap_or_else(|_| "\"dark\"".to_string())),
        ("timeout_ms", settings.timeout_ms.to_string()),
        ("ssl_verify", settings.ssl_verify.to_string()),
        ("proxy_url", serde_json::to_string(&settings.proxy_url).unwrap_or_else(|_| "null".to_string())),
        ("follow_redirects", settings.follow_redirects.to_string()),
        ("max_redirects", settings.max_redirects.to_string()),
    ];

    for (key, value) in pairs {
        conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            params![key, value],
        )
        .map_err(|e| e.to_string())?;
    }

    Ok(settings)
}
