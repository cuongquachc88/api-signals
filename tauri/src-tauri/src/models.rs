use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

// ─── Workspace ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Workspace {
    pub id: String,
    pub name: String,
    pub created_at: String,
    pub updated_at: String,
}

impl Workspace {
    pub fn new(name: &str) -> Self {
        let now = Utc::now().to_rfc3339();
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.to_string(),
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

// ─── Collection ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Collection {
    pub id: String,
    pub workspace_id: String,
    pub parent_id: Option<String>,
    pub name: String,
    pub description: Option<String>,
    pub sort_order: i64,
    pub created_at: String,
    pub updated_at: String,
}

impl Collection {
    pub fn new(workspace_id: &str, name: &str, parent_id: Option<&str>) -> Self {
        let now = Utc::now().to_rfc3339();
        Self {
            id: Uuid::new_v4().to_string(),
            workspace_id: workspace_id.to_string(),
            parent_id: parent_id.map(|s| s.to_string()),
            name: name.to_string(),
            description: None,
            sort_order: 0,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

// ─── Header / Parameter ──────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyValue {
    pub id: String,
    pub key: String,
    pub value: String,
    pub enabled: bool,
    pub description: Option<String>,
}

impl KeyValue {
    pub fn new(key: &str, value: &str) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            key: key.to_string(),
            value: value.to_string(),
            enabled: true,
            description: None,
        }
    }
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum Auth {
    None,
    Bearer { token: String },
    Basic { username: String, password: String },
    ApiKey { key: String, value: String, location: String }, // "header" | "query"
    OAuth2 {
        grant_type: String,
        auth_url: String,
        token_url: String,
        client_id: String,
        client_secret: String,
        scope: String,
        access_token: Option<String>,
    },
    Digest { username: String, password: String },
}

impl Default for Auth {
    fn default() -> Self {
        Auth::None
    }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum RequestBody {
    None,
    Raw { content: String, content_type: String },
    Json { content: String },
    FormData { fields: Vec<KeyValue> },
    UrlEncoded { fields: Vec<KeyValue> },
    Binary { file_path: String },
    GraphQL { query: String, variables: String },
}

impl Default for RequestBody {
    fn default() -> Self {
        RequestBody::None
    }
}

// ─── APIRequest ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct APIRequest {
    pub id: String,
    pub collection_id: String,
    pub workspace_id: String,
    pub name: String,
    pub method: String,
    pub url: String,
    pub headers: Vec<KeyValue>,
    pub params: Vec<KeyValue>,
    pub body: RequestBody,
    pub auth: Auth,
    pub pre_request_script: String,
    pub post_response_script: String,
    pub description: String,
    pub sort_order: i64,
    pub created_at: String,
    pub updated_at: String,
}

impl APIRequest {
    pub fn new(collection_id: &str, workspace_id: &str, name: &str) -> Self {
        let now = Utc::now().to_rfc3339();
        Self {
            id: Uuid::new_v4().to_string(),
            collection_id: collection_id.to_string(),
            workspace_id: workspace_id.to_string(),
            name: name.to_string(),
            method: "GET".to_string(),
            url: String::new(),
            headers: Vec::new(),
            params: Vec::new(),
            body: RequestBody::None,
            auth: Auth::None,
            pre_request_script: String::new(),
            post_response_script: String::new(),
            description: String::new(),
            sort_order: 0,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

// ─── Response ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct APIResponse {
    pub status: u16,
    pub status_text: String,
    pub headers: Vec<KeyValue>,
    pub body: String,
    pub body_size: u64,
    pub timing: RequestTiming,
    pub cookies: Vec<Cookie>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RequestTiming {
    pub dns_ms: f64,
    pub connect_ms: f64,
    pub tls_ms: f64,
    pub send_ms: f64,
    pub wait_ms: f64,
    pub receive_ms: f64,
    pub total_ms: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Cookie {
    pub name: String,
    pub value: String,
    pub domain: Option<String>,
    pub path: Option<String>,
    pub expires: Option<String>,
    pub http_only: bool,
    pub secure: bool,
}

// ─── Environment ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Environment {
    pub id: String,
    pub workspace_id: String,
    pub name: String,
    pub variables: Vec<Variable>,
    pub is_active: bool,
    pub created_at: String,
    pub updated_at: String,
}

impl Environment {
    pub fn new(workspace_id: &str, name: &str) -> Self {
        let now = Utc::now().to_rfc3339();
        Self {
            id: Uuid::new_v4().to_string(),
            workspace_id: workspace_id.to_string(),
            name: name.to_string(),
            variables: Vec::new(),
            is_active: false,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Variable {
    pub id: String,
    pub key: String,
    pub value: String,
    pub enabled: bool,
    pub secret: bool,
}

impl Variable {
    pub fn new(key: &str, value: &str) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            key: key.to_string(),
            value: value.to_string(),
            enabled: true,
            secret: false,
        }
    }
}

// ─── History ──────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryEntry {
    pub id: String,
    pub workspace_id: String,
    pub request_name: String,
    pub method: String,
    pub url: String,
    pub status: u16,
    pub duration_ms: f64,
    pub response_size: u64,
    pub timestamp: String,
    pub request_snapshot: String, // JSON string
    pub response_snapshot: String, // JSON string
}

// ─── MockRoute ────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MockRoute {
    pub id: String,
    pub method: String,
    pub path: String,
    pub status_code: u16,
    pub response_body: String,
    pub response_headers: Vec<KeyValue>,
    pub delay_ms: u64,
    pub enabled: bool,
}

impl MockRoute {
    pub fn new(method: &str, path: &str) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            method: method.to_string(),
            path: path.to_string(),
            status_code: 200,
            response_body: r#"{"message": "ok"}"#.to_string(),
            response_headers: vec![KeyValue::new("Content-Type", "application/json")],
            delay_ms: 0,
            enabled: true,
        }
    }
}

// ─── Settings ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    pub theme: String, // "dark" | "light"
    pub timeout_ms: u64,
    pub ssl_verify: bool,
    pub proxy_url: Option<String>,
    pub follow_redirects: bool,
    pub max_redirects: u32,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            theme: "dark".to_string(),
            timeout_ms: 30000,
            ssl_verify: true,
            proxy_url: None,
            follow_redirects: true,
            max_redirects: 10,
        }
    }
}
