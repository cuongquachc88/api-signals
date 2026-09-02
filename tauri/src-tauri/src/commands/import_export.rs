use crate::models::{APIRequest, Collection, KeyValue, RequestBody, Auth};
use serde_json::Value;
use uuid::Uuid;
use chrono::Utc;

// ─── cURL import/export ────────────────────────────────────────────────────────

#[tauri::command]
pub fn import_curl(curl_string: String) -> Result<APIRequest, String> {
    let tokens = tokenize_curl(&curl_string);
    let mut method = "GET".to_string();
    let mut url = String::new();
    let mut headers: Vec<KeyValue> = Vec::new();
    let mut body_content = String::new();
    let mut content_type = String::new();

    let mut i = 0;
    while i < tokens.len() {
        match tokens[i].as_str() {
            "curl" => { i += 1; }
            "-X" | "--request" => {
                i += 1;
                if i < tokens.len() { method = tokens[i].clone(); }
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
                        }
                        headers.push(KeyValue::new(&key, &value));
                    }
                }
                i += 1;
            }
            "-d" | "--data" | "--data-raw" => {
                i += 1;
                if i < tokens.len() {
                    body_content = tokens[i].clone();
                    if method == "GET" { method = "POST".to_string(); }
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

    // Remove content-type from headers (will be handled by body type)
    headers.retain(|h| h.key.to_lowercase() != "content-type");

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
        params: Vec::new(),
        body,
        auth: Auth::None,
        pre_request_script: String::new(),
        post_response_script: String::new(),
        description: String::new(),
        sort_order: 0,
        created_at: now.clone(),
        updated_at: now,
    })
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
            '\\' if i + 1 < chars.len() => {
                current.push(chars[i + 1]);
                i += 2;
            }
            c if (c == ' ' || c == '\n' || c == '\t' || c == '\\') && !in_single && !in_double => {
                // Skip line continuation backslash at end
                if c == '\\' && i + 1 < chars.len() && (chars[i+1] == '\n' || chars[i+1] == '\r') {
                    i += 2;
                    continue;
                }
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
pub struct PostmanImportResult {
    pub collection_name: String,
    pub requests: Vec<APIRequest>,
}

#[tauri::command]
pub fn import_postman(
    json_string: String,
    workspace_id: String,
    collection_id: String,
) -> Result<PostmanImportResult, String> {
    let v: Value = serde_json::from_str(&json_string).map_err(|e| e.to_string())?;

    let collection_name = v["info"]["name"].as_str().unwrap_or("Imported Collection").to_string();
    let mut requests: Vec<APIRequest> = Vec::new();

    if let Some(items) = v["item"].as_array() {
        parse_postman_items(items, &workspace_id, &collection_id, &mut requests, 0);
    }

    Ok(PostmanImportResult { collection_name, requests })
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

#[tauri::command]
pub fn import_har(
    json_string: String,
    workspace_id: String,
    collection_id: String,
) -> Result<Vec<APIRequest>, String> {
    let v: Value = serde_json::from_str(&json_string).map_err(|e| e.to_string())?;
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
                collection_id: collection_id.clone(),
                workspace_id: workspace_id.clone(),
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

// ─── OpenAPI 3.x import ────────────────────────────────────────────────────────

#[tauri::command]
pub fn import_openapi(
    json_string: String,
    workspace_id: String,
    collection_id: String,
) -> Result<Vec<APIRequest>, String> {
    let v: Value = serde_json::from_str(&json_string).map_err(|e| {
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
                        collection_id: collection_id.clone(),
                        workspace_id: workspace_id.clone(),
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
