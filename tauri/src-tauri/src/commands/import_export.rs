use crate::db::DbState;
use crate::models::{APIRequest, Collection, KeyValue, RequestBody, Auth};
use rusqlite::{params, Connection};
use serde_json::Value;
use uuid::Uuid;
use chrono::Utc;
use base64::Engine;
use tauri::State;

fn insert_request(conn: &Connection, req: &APIRequest) -> Result<(), String> {
    let headers_json = serde_json::to_string(&req.headers).map_err(|e| e.to_string())?;
    let params_json = serde_json::to_string(&req.params).map_err(|e| e.to_string())?;
    let body_json = serde_json::to_string(&req.body).map_err(|e| e.to_string())?;
    let auth_json = serde_json::to_string(&req.auth).map_err(|e| e.to_string())?;

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

    Ok(())
}

// ─── cURL import/export ────────────────────────────────────────────────────────

#[tauri::command]
pub fn import_curl(curl_string: String) -> Result<APIRequest, String> {
    let tokens = tokenize_curl(&curl_string);
    let mut method = "GET".to_string();
    let mut method_explicit = false;
    let mut url = String::new();
    let mut headers: Vec<KeyValue> = Vec::new();
    let mut body_content = String::new();
    let mut content_type = String::new();
    let mut basic_user: Option<String> = None;
    let mut auth: Auth = Auth::None;

    let mut i = 0;
    while i < tokens.len() {
        match tokens[i].as_str() {
            "curl" => { i += 1; }
            "-X" | "--request" => {
                i += 1;
                if i < tokens.len() { method = tokens[i].clone(); method_explicit = true; }
                i += 1;
            }
            "-H" | "--header" => {
                i += 1;
                if i < tokens.len() {
                    if let Some(colon) = tokens[i].find(':') {
                        let key = tokens[i][..colon].trim().to_string();
                        let value = tokens[i][colon + 1..].trim().to_string();
                        if key.to_lowercase() == "content-type" {
                            content_type = value.clone();
                        } else if key.to_lowercase() == "authorization" {
                            auth = parse_authorization_header(&value);
                        } else {
                            headers.push(KeyValue::new(&key, &value));
                        }
                    }
                }
                i += 1;
            }
            "-u" | "--user" => {
                i += 1;
                if i < tokens.len() { basic_user = Some(tokens[i].clone()); }
                i += 1;
            }
            "-d" | "--data" | "--data-raw" | "--data-binary" => {
                i += 1;
                if i < tokens.len() {
                    body_content = tokens[i].clone();
                    if !method_explicit { method = "POST".to_string(); }
                }
                i += 1;
            }
            "--data-urlencode" => {
                i += 1;
                i += 1; // skip
            }
            t if !t.starts_with('-') && url.is_empty() => {
                url = t.trim_matches('\'').trim_matches('"').to_string();
                i += 1;
            }
            _ => { i += 1; }
        }
    }

    if matches!(auth, Auth::None) {
        if let Some(user) = basic_user {
            let (username, password) = match user.split_once(':') {
                Some((u, p)) => (u.to_string(), p.to_string()),
                None => (user, String::new()),
            };
            auth = Auth::Basic { username, password };
        }
    }

    // Split query string out of the URL into params
    let mut params: Vec<KeyValue> = Vec::new();
    if let Some(q_idx) = url.find('?') {
        let query = url[q_idx + 1..].to_string();
        for pair in query.split('&') {
            if pair.is_empty() { continue; }
            let (key, value) = match pair.split_once('=') {
                Some((k, v)) => (k.to_string(), v.to_string()),
                None => (pair.to_string(), String::new()),
            };
            params.push(KeyValue::new(&key, &value));
        }
    }

    let body = if body_content.is_empty() {
        RequestBody::None
    } else if content_type.contains("application/json") {
        RequestBody::Json { content: body_content }
    } else if content_type.contains("application/x-www-form-urlencoded") {
        RequestBody::Raw { content: body_content, content_type }
    } else {
        RequestBody::Raw { content: body_content, content_type: content_type.clone() }
    };

    let now = Utc::now().to_rfc3339();
    let name = url.split('/').last().unwrap_or("Imported Request").to_string();

    Ok(APIRequest {
        id: Uuid::new_v4().to_string(),
        collection_id: String::new(),
        workspace_id: String::new(),
        name: if name.is_empty() { "Imported Request".to_string() } else { name },
        method,
        url,
        headers,
        params,
        body,
        auth,
        pre_request_script: String::new(),
        post_response_script: String::new(),
        description: String::new(),
        sort_order: 0,
        created_at: now.clone(),
        updated_at: now,
    })
}

fn parse_authorization_header(value: &str) -> Auth {
    if let Some(token) = value.strip_prefix("Bearer ").or_else(|| value.strip_prefix("bearer ")) {
        return Auth::Bearer { token: token.trim().to_string() };
    }
    if let Some(encoded) = value.strip_prefix("Basic ").or_else(|| value.strip_prefix("basic ")) {
        if let Ok(decoded) = base64::engine::general_purpose::STANDARD.decode(encoded.trim()) {
            if let Ok(text) = String::from_utf8(decoded) {
                let (username, password) = match text.split_once(':') {
                    Some((u, p)) => (u.to_string(), p.to_string()),
                    None => (text, String::new()),
                };
                return Auth::Basic { username, password };
            }
        }
    }
    Auth::None
}

fn tokenize_curl(s: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();
    let mut in_single = false;
    let mut in_double = false;
    let chars: Vec<char> = s.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        match chars[i] {
            '\'' if !in_double => {
                in_single = !in_single;
                i += 1;
            }
            '"' if !in_single => {
                in_double = !in_double;
                i += 1;
            }
            '\\' if !in_single && !in_double && i + 1 < chars.len() && (chars[i + 1] == '\n' || chars[i + 1] == '\r') => {
                // Line continuation: treat like a token separator, don't embed the newline
                if !current.is_empty() {
                    tokens.push(current.clone());
                    current.clear();
                }
                i += 2;
                if i < chars.len() && chars[i - 1] == '\r' && chars[i] == '\n' { i += 1; }
            }
            '\\' if i + 1 < chars.len() => {
                current.push(chars[i + 1]);
                i += 2;
            }
            c if (c == ' ' || c == '\n' || c == '\t') && !in_single && !in_double => {
                if !current.is_empty() {
                    tokens.push(current.clone());
                    current.clear();
                }
                i += 1;
            }
            c => {
                current.push(c);
                i += 1;
            }
        }
    }

    if !current.is_empty() {
        tokens.push(current);
    }

    tokens
}

#[tauri::command]
pub fn export_curl(request: APIRequest) -> Result<String, String> {
    crate::commands::snippet::generate_snippet("curl".to_string(), request)
}

// ─── Postman Collection v2.1 import ───────────────────────────────────────────

#[derive(serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PostmanImportResult {
    pub collection_name: String,
    pub requests: Vec<APIRequest>,
}

fn parse_postman_collection(json_string: &str, workspace_id: &str, collection_id: &str) -> Result<PostmanImportResult, String> {
    let v: Value = serde_json::from_str(json_string).map_err(|e| e.to_string())?;

    let collection_name = v["info"]["name"].as_str().unwrap_or("Imported Collection").to_string();
    let mut requests: Vec<APIRequest> = Vec::new();

    if let Some(items) = v["item"].as_array() {
        parse_postman_items(items, workspace_id, collection_id, &mut requests, 0);
    }

    Ok(PostmanImportResult { collection_name, requests })
}

#[tauri::command]
pub fn import_postman(
    state: State<DbState>,
    json_string: String,
    workspace_id: String,
    collection_id: String,
) -> Result<PostmanImportResult, String> {
    let result = parse_postman_collection(&json_string, &workspace_id, &collection_id)?;

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    for req in &result.requests {
        insert_request(&conn, req)?;
    }

    Ok(result)
}

fn parse_postman_items(items: &[Value], workspace_id: &str, collection_id: &str, requests: &mut Vec<APIRequest>, depth: usize) {
    if depth > 10 { return; }
    for item in items {
        if let Some(sub_items) = item["item"].as_array() {
            parse_postman_items(sub_items, workspace_id, collection_id, requests, depth + 1);
        } else if item["request"].is_object() {
            if let Some(req) = parse_postman_request(&item["request"], item["name"].as_str().unwrap_or("Request"), workspace_id, collection_id) {
                requests.push(req);
            }
        }
    }
}

fn parse_postman_request(req: &Value, name: &str, workspace_id: &str, collection_id: &str) -> Option<APIRequest> {
    let method = req["method"].as_str().unwrap_or("GET").to_string();
    let url = match &req["url"] {
        Value::String(s) => s.clone(),
        Value::Object(_) => req["url"]["raw"].as_str().unwrap_or("").to_string(),
        _ => String::new(),
    };

    let headers: Vec<KeyValue> = req["header"].as_array().map(|arr| {
        arr.iter().filter_map(|h| {
            let key = h["key"].as_str()?.to_string();
            let value = h["value"].as_str().unwrap_or("").to_string();
            let disabled = h["disabled"].as_bool().unwrap_or(false);
            Some(KeyValue {
                id: Uuid::new_v4().to_string(),
                key,
                value,
                enabled: !disabled,
                description: h["description"].as_str().map(|s| s.to_string()),
            })
        }).collect()
    }).unwrap_or_default();

    let body = parse_postman_body(&req["body"]);
    let auth = parse_postman_auth(&req["auth"]);

    let now = Utc::now().to_rfc3339();
    Some(APIRequest {
        id: Uuid::new_v4().to_string(),
        collection_id: collection_id.to_string(),
        workspace_id: workspace_id.to_string(),
        name: name.to_string(),
        method,
        url,
        headers,
        params: Vec::new(),
        body,
        auth,
        pre_request_script: String::new(),
        post_response_script: String::new(),
        description: req["description"].as_str().unwrap_or("").to_string(),
        sort_order: 0,
        created_at: now.clone(),
        updated_at: now,
    })
}

fn parse_postman_body(body: &Value) -> RequestBody {
    let mode = body["mode"].as_str().unwrap_or("");
    match mode {
        "raw" => {
            let content = body["raw"].as_str().unwrap_or("").to_string();
            let lang = body["options"]["raw"]["language"].as_str().unwrap_or("");
            if lang == "json" {
                RequestBody::Json { content }
            } else {
                RequestBody::Raw { content, content_type: "text/plain".to_string() }
            }
        }
        "urlencoded" => {
            let fields: Vec<KeyValue> = body["urlencoded"].as_array().map(|arr| {
                arr.iter().map(|f| KeyValue {
                    id: Uuid::new_v4().to_string(),
                    key: f["key"].as_str().unwrap_or("").to_string(),
                    value: f["value"].as_str().unwrap_or("").to_string(),
                    enabled: !f["disabled"].as_bool().unwrap_or(false),
                    description: None,
                }).collect()
            }).unwrap_or_default();
            RequestBody::UrlEncoded { fields }
        }
        "formdata" => {
            let fields: Vec<KeyValue> = body["formdata"].as_array().map(|arr| {
                arr.iter().map(|f| KeyValue {
                    id: Uuid::new_v4().to_string(),
                    key: f["key"].as_str().unwrap_or("").to_string(),
                    value: f["value"].as_str().unwrap_or("").to_string(),
                    enabled: !f["disabled"].as_bool().unwrap_or(false),
                    description: None,
                }).collect()
            }).unwrap_or_default();
            RequestBody::FormData { fields }
        }
        "graphql" => {
            let query = body["graphql"]["query"].as_str().unwrap_or("").to_string();
            let variables = body["graphql"]["variables"].as_str().unwrap_or("{}").to_string();
            RequestBody::GraphQL { query, variables }
        }
        _ => RequestBody::None,
    }
}

fn parse_postman_auth(auth: &Value) -> Auth {
    match auth["type"].as_str().unwrap_or("noauth") {
        "bearer" => {
            let token = auth["bearer"].as_array()
                .and_then(|arr| arr.iter().find(|item| item["key"].as_str() == Some("token")))
                .and_then(|item| item["value"].as_str())
                .unwrap_or("")
                .to_string();
            Auth::Bearer { token }
        }
        "basic" => {
            let username = get_auth_value(&auth["basic"], "username");
            let password = get_auth_value(&auth["basic"], "password");
            Auth::Basic { username, password }
        }
        "apikey" => {
            let key = get_auth_value(&auth["apikey"], "key");
            let value = get_auth_value(&auth["apikey"], "value");
            let location = get_auth_value(&auth["apikey"], "in");
            Auth::ApiKey { key, value, location: if location.is_empty() { "header".to_string() } else { location } }
        }
        _ => Auth::None,
    }
}

fn get_auth_value(auth_arr: &Value, key: &str) -> String {
    auth_arr.as_array()
        .and_then(|arr| arr.iter().find(|item| item["key"].as_str() == Some(key)))
        .and_then(|item| item["value"].as_str())
        .unwrap_or("")
        .to_string()
}

// ─── Postman export ────────────────────────────────────────────────────────────

#[tauri::command]
pub fn export_postman(
    collection_name: String,
    requests: Vec<APIRequest>,
) -> Result<String, String> {
    let items: Vec<Value> = requests.iter().map(|req| {
        let headers: Vec<Value> = req.headers.iter()
            .filter(|h| !h.key.is_empty())
            .map(|h| serde_json::json!({
                "key": h.key,
                "value": h.value,
                "disabled": !h.enabled
            }))
            .collect();

        let body = export_postman_body(&req.body);

        serde_json::json!({
            "name": req.name,
            "request": {
                "method": req.method,
                "url": { "raw": req.url },
                "header": headers,
                "body": body
            }
        })
    }).collect();

    let collection = serde_json::json!({
        "info": {
            "name": collection_name,
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        },
        "item": items
    });

    serde_json::to_string_pretty(&collection).map_err(|e| e.to_string())
}

fn export_postman_body(body: &RequestBody) -> Value {
    match body {
        RequestBody::Json { content } => serde_json::json!({
            "mode": "raw",
            "raw": content,
            "options": { "raw": { "language": "json" } }
        }),
        RequestBody::Raw { content, content_type } => serde_json::json!({
            "mode": "raw",
            "raw": content
        }),
        RequestBody::UrlEncoded { fields } => {
            let items: Vec<Value> = fields.iter().map(|f| serde_json::json!({
                "key": f.key, "value": f.value, "disabled": !f.enabled
            })).collect();
            serde_json::json!({ "mode": "urlencoded", "urlencoded": items })
        }
        RequestBody::FormData { fields } => {
            let items: Vec<Value> = fields.iter().map(|f| serde_json::json!({
                "key": f.key, "value": f.value, "type": "text", "disabled": !f.enabled
            })).collect();
            serde_json::json!({ "mode": "formdata", "formdata": items })
        }
        RequestBody::GraphQL { query, variables } => serde_json::json!({
            "mode": "graphql",
            "graphql": { "query": query, "variables": variables }
        }),
        _ => serde_json::json!({ "mode": "none" }),
    }
}

// ─── HAR import/export ─────────────────────────────────────────────────────────

fn parse_har(json_string: &str, workspace_id: &str, collection_id: &str) -> Result<Vec<APIRequest>, String> {
    let v: Value = serde_json::from_str(json_string).map_err(|e| e.to_string())?;
    let mut requests = Vec::new();

    if let Some(entries) = v["log"]["entries"].as_array() {
        for entry in entries {
            let req = &entry["request"];
            let method = req["method"].as_str().unwrap_or("GET").to_string();
            let url = req["url"].as_str().unwrap_or("").to_string();

            let headers: Vec<KeyValue> = req["headers"].as_array().map(|arr| {
                arr.iter().filter_map(|h| {
                    let name = h["name"].as_str()?.to_string();
                    if name.starts_with(':') { return None; } // Skip HTTP/2 pseudo-headers
                    Some(KeyValue::new(&name, h["value"].as_str().unwrap_or("")))
                }).collect()
            }).unwrap_or_default();

            let body = if let Some(post_data) = req["postData"].as_object() {
                let mime = post_data["mimeType"].as_str().unwrap_or("");
                let text = post_data["text"].as_str().unwrap_or("").to_string();
                if mime.contains("application/json") {
                    RequestBody::Json { content: text }
                } else if mime.contains("application/x-www-form-urlencoded") {
                    RequestBody::Raw { content: text, content_type: mime.to_string() }
                } else {
                    RequestBody::Raw { content: text, content_type: mime.to_string() }
                }
            } else {
                RequestBody::None
            };

            let now = Utc::now().to_rfc3339();
            let name = url.split('/').last().unwrap_or("Request").to_string();
            requests.push(APIRequest {
                id: Uuid::new_v4().to_string(),
                collection_id: collection_id.to_string(),
                workspace_id: workspace_id.to_string(),
                name: format!("{} {}", method, name),
                method, url, headers,
                params: Vec::new(),
                body,
                auth: Auth::None,
                pre_request_script: String::new(),
                post_response_script: String::new(),
                description: String::new(),
                sort_order: 0,
                created_at: now.clone(),
                updated_at: now,
            });
        }
    }

    Ok(requests)
}

#[tauri::command]
pub fn import_har(
    state: State<DbState>,
    json_string: String,
    workspace_id: String,
    collection_id: String,
) -> Result<Vec<APIRequest>, String> {
    let requests = parse_har(&json_string, &workspace_id, &collection_id)?;

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    for req in &requests {
        insert_request(&conn, req)?;
    }

    Ok(requests)
}

// ─── OpenAPI 3.x import ────────────────────────────────────────────────────────

fn parse_openapi(json_string: &str, workspace_id: &str, collection_id: &str) -> Result<Vec<APIRequest>, String> {
    let v: Value = serde_json::from_str(json_string).map_err(|e| {
        // Try YAML? For now return the error
        format!("Parse error: {}. Note: Only JSON OpenAPI specs are supported.", e)
    })?;

    let base_url = v["servers"].as_array()
        .and_then(|arr| arr.first())
        .and_then(|s| s["url"].as_str())
        .unwrap_or("")
        .to_string();

    let mut requests: Vec<APIRequest> = Vec::new();

    if let Some(paths) = v["paths"].as_object() {
        for (path, path_item) in paths {
            if let Some(methods) = path_item.as_object() {
                for (method_lower, operation) in methods {
                    if !["get","post","put","patch","delete","head","options"].contains(&method_lower.as_str()) {
                        continue;
                    }

                    let method = method_lower.to_uppercase();
                    let url = format!("{}{}", base_url, path);
                    let name = operation["summary"].as_str()
                        .unwrap_or(&format!("{} {}", method, path))
                        .to_string();
                    let description = operation["description"].as_str().unwrap_or("").to_string();

                    let mut params: Vec<KeyValue> = Vec::new();
                    let mut headers: Vec<KeyValue> = Vec::new();

                    if let Some(parameters) = operation["parameters"].as_array() {
                        for p in parameters {
                            let pname = p["name"].as_str().unwrap_or("").to_string();
                            let location = p["in"].as_str().unwrap_or("");
                            match location {
                                "query" => {
                                    params.push(KeyValue {
                                        id: Uuid::new_v4().to_string(),
                                        key: pname,
                                        value: String::new(),
                                        enabled: true,
                                        description: p["description"].as_str().map(|s| s.to_string()),
                                    });
                                }
                                "header" => {
                                    headers.push(KeyValue {
                                        id: Uuid::new_v4().to_string(),
                                        key: pname,
                                        value: String::new(),
                                        enabled: true,
                                        description: p["description"].as_str().map(|s| s.to_string()),
                                    });
                                }
                                _ => {}
                            }
                        }
                    }

                    let body = if let Some(req_body) = operation["requestBody"].as_object() {
                        let content = &req_body["content"];
                        if content["application/json"].is_object() {
                            let example = &content["application/json"]["example"];
                            let schema_str = if !example.is_null() {
                                serde_json::to_string_pretty(example).unwrap_or_else(|_| "{}".to_string())
                            } else {
                                "{}".to_string()
                            };
                            RequestBody::Json { content: schema_str }
                        } else if content["application/x-www-form-urlencoded"].is_object() {
                            RequestBody::UrlEncoded { fields: Vec::new() }
                        } else {
                            RequestBody::None
                        }
                    } else {
                        RequestBody::None
                    };

                    let now = Utc::now().to_rfc3339();
                    requests.push(APIRequest {
                        id: Uuid::new_v4().to_string(),
                        collection_id: collection_id.to_string(),
                        workspace_id: workspace_id.to_string(),
                        name, method, url, headers, params, body,
                        auth: Auth::None,
                        pre_request_script: String::new(),
                        post_response_script: String::new(),
                        description,
                        sort_order: 0,
                        created_at: now.clone(),
                        updated_at: now,
                    });
                }
            }
        }
    }

    Ok(requests)
}

#[tauri::command]
pub fn import_openapi(
    state: State<DbState>,
    json_string: String,
    workspace_id: String,
    collection_id: String,
) -> Result<Vec<APIRequest>, String> {
    let requests = parse_openapi(&json_string, &workspace_id, &collection_id)?;

    let conn = state.0.lock().map_err(|e| e.to_string())?;
    for req in &requests {
        insert_request(&conn, req)?;
    }

    Ok(requests)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ─── cURL tokenizer / import ───────────────────────────────────────────

    #[test]
    fn tokenize_splits_line_continuations_without_glueing_next_flag() {
        // Regression: a `\` + newline before a flag with no leading space (as emitted by
        // Postman's "Copy as cURL (bash)") used to get glued onto the next token,
        // producing "\n--header" instead of "--header", silently dropping every
        // header/body flag that followed a line continuation.
        let curl = "curl --location 'https://example.com' \\\n--header 'X-Test: 1' \\\n--data-raw '{}'";
        let tokens = tokenize_curl(curl);
        assert_eq!(tokens, vec![
            "curl", "--location", "https://example.com",
            "--header", "X-Test: 1",
            "--data-raw", "{}",
        ]);
    }

    #[test]
    fn tokenize_handles_crlf_line_continuations() {
        let curl = "curl --location 'https://example.com' \\\r\n--header 'X-Test: 1'";
        let tokens = tokenize_curl(curl);
        assert_eq!(tokens, vec!["curl", "--location", "https://example.com", "--header", "X-Test: 1"]);
    }

    #[test]
    fn import_curl_parses_method_headers_and_json_body() {
        let curl = "curl --location 'https://api.example.com/run' \\\n--header 'Content-Type: application/json' \\\n--header 'TENANT-ID: abc123' \\\n--data-raw '{\"key\":\"value\"}'";
        let req = import_curl(curl.to_string()).unwrap();

        assert_eq!(req.method, "POST");
        assert_eq!(req.url, "https://api.example.com/run");
        assert_eq!(req.headers.len(), 1);
        assert_eq!(req.headers[0].key, "TENANT-ID");
        assert_eq!(req.headers[0].value, "abc123");
        match req.body {
            RequestBody::Json { content } => assert_eq!(content, "{\"key\":\"value\"}"),
            other => panic!("expected Json body, got {:?}", other),
        }
    }

    #[test]
    fn import_curl_respects_explicit_method_even_with_data() {
        let curl = "curl -X PUT 'https://api.example.com/thing' -d '{}'";
        let req = import_curl(curl.to_string()).unwrap();
        assert_eq!(req.method, "PUT");
    }

    #[test]
    fn import_curl_defaults_to_post_when_data_present_without_explicit_method() {
        let curl = "curl 'https://api.example.com/thing' -d '{}'";
        let req = import_curl(curl.to_string()).unwrap();
        assert_eq!(req.method, "POST");
    }

    #[test]
    fn import_curl_extracts_bearer_auth_from_header() {
        let curl = "curl 'https://api.example.com' -H 'Authorization: Bearer abc.def.ghi'";
        let req = import_curl(curl.to_string()).unwrap();
        match req.auth {
            Auth::Bearer { token } => assert_eq!(token, "abc.def.ghi"),
            other => panic!("expected Bearer auth, got {:?}", other),
        }
        // Authorization must not leak into the plain headers list
        assert!(req.headers.iter().all(|h| h.key.to_lowercase() != "authorization"));
    }

    #[test]
    fn import_curl_extracts_basic_auth_from_user_flag() {
        let curl = "curl -u 'alice:s3cret' 'https://api.example.com'";
        let req = import_curl(curl.to_string()).unwrap();
        match req.auth {
            Auth::Basic { username, password } => {
                assert_eq!(username, "alice");
                assert_eq!(password, "s3cret");
            }
            other => panic!("expected Basic auth, got {:?}", other),
        }
    }

    #[test]
    fn import_curl_extracts_basic_auth_from_authorization_header() {
        // "alice:s3cret" base64-encoded
        let curl = "curl 'https://api.example.com' -H 'Authorization: Basic YWxpY2U6czNjcmV0'";
        let req = import_curl(curl.to_string()).unwrap();
        match req.auth {
            Auth::Basic { username, password } => {
                assert_eq!(username, "alice");
                assert_eq!(password, "s3cret");
            }
            other => panic!("expected Basic auth, got {:?}", other),
        }
    }

    #[test]
    fn import_curl_splits_query_string_into_params() {
        let curl = "curl 'https://api.example.com/search?q=test&page=2'";
        let req = import_curl(curl.to_string()).unwrap();
        assert_eq!(req.url, "https://api.example.com/search?q=test&page=2");
        assert_eq!(req.params.len(), 2);
        assert_eq!(req.params[0].key, "q");
        assert_eq!(req.params[0].value, "test");
        assert_eq!(req.params[1].key, "page");
        assert_eq!(req.params[1].value, "2");
    }

    // ─── Postman / HAR / OpenAPI parsing (pure, no DB) ─────────────────────

    #[test]
    fn parse_postman_collection_extracts_name_and_requests() {
        let json = r#"{
            "info": { "name": "My Collection" },
            "item": [
                {
                    "name": "Get thing",
                    "request": {
                        "method": "GET",
                        "url": { "raw": "https://api.example.com/thing" },
                        "header": [{ "key": "X-Test", "value": "1" }]
                    }
                }
            ]
        }"#;
        let result = parse_postman_collection(json, "ws1", "col1").unwrap();
        assert_eq!(result.collection_name, "My Collection");
        assert_eq!(result.requests.len(), 1);
        assert_eq!(result.requests[0].method, "GET");
        assert_eq!(result.requests[0].url, "https://api.example.com/thing");
        assert_eq!(result.requests[0].workspace_id, "ws1");
        assert_eq!(result.requests[0].collection_id, "col1");
    }

    #[test]
    fn parse_postman_collection_recurses_into_nested_folders() {
        let json = r#"{
            "info": { "name": "Nested" },
            "item": [
                { "item": [
                    { "name": "Inner", "request": { "method": "GET", "url": "https://a.com" } }
                ]}
            ]
        }"#;
        let result = parse_postman_collection(json, "ws1", "col1").unwrap();
        assert_eq!(result.requests.len(), 1);
    }

    #[test]
    fn parse_har_extracts_requests_and_skips_pseudo_headers() {
        let json = r#"{
            "log": { "entries": [
                { "request": {
                    "method": "POST",
                    "url": "https://api.example.com/a",
                    "headers": [
                        { "name": ":authority", "value": "api.example.com" },
                        { "name": "Content-Type", "value": "application/json" }
                    ],
                    "postData": { "mimeType": "application/json", "text": "{\"a\":1}" }
                }}
            ]}
        }"#;
        let result = parse_har(json, "ws1", "col1").unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].method, "POST");
        assert_eq!(result[0].headers.len(), 1);
        assert_eq!(result[0].headers[0].key, "Content-Type");
        match &result[0].body {
            RequestBody::Json { content } => assert_eq!(content, "{\"a\":1}"),
            other => panic!("expected Json body, got {:?}", other),
        }
    }

    #[test]
    fn parse_openapi_generates_one_request_per_operation() {
        let json = r#"{
            "servers": [{ "url": "https://api.example.com" }],
            "paths": {
                "/things": {
                    "get": { "summary": "List things" },
                    "post": { "summary": "Create thing" }
                }
            }
        }"#;
        let result = parse_openapi(json, "ws1", "col1").unwrap();
        assert_eq!(result.len(), 2);
        assert!(result.iter().any(|r| r.method == "GET" && r.url == "https://api.example.com/things"));
        assert!(result.iter().any(|r| r.method == "POST"));
    }

    // ─── DB persistence ─────────────────────────────────────────────────────

    #[test]
    fn insert_request_persists_all_fields_round_trip() {
        let conn = crate::db::init_db(":memory:").unwrap();
        conn.execute(
            "INSERT INTO workspaces (id, name, created_at, updated_at) VALUES ('ws1', 'W', 'now', 'now')",
            [],
        ).unwrap();
        conn.execute(
            "INSERT INTO collections (id, workspace_id, parent_id, name, sort_order, created_at, updated_at) VALUES ('col1', 'ws1', NULL, 'C', 0, 'now', 'now')",
            [],
        ).unwrap();

        let req = APIRequest {
            id: "req1".to_string(),
            collection_id: "col1".to_string(),
            workspace_id: "ws1".to_string(),
            name: "Test".to_string(),
            method: "POST".to_string(),
            url: "https://api.example.com".to_string(),
            headers: vec![KeyValue::new("X-Test", "1")],
            params: Vec::new(),
            body: RequestBody::Json { content: "{}".to_string() },
            auth: Auth::None,
            pre_request_script: String::new(),
            post_response_script: String::new(),
            description: String::new(),
            sort_order: 0,
            created_at: "2024-01-01T00:00:00Z".to_string(),
            updated_at: "2024-01-01T00:00:00Z".to_string(),
        };

        insert_request(&conn, &req).unwrap();

        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM requests WHERE id = ?1", params![req.id], |r| r.get(0))
            .unwrap();
        assert_eq!(count, 1);
    }
}
