use crate::models::{APIRequest, APIResponse, Auth, KeyValue, RequestBody, RequestTiming, Cookie};
use std::collections::HashMap;
use std::time::Instant;
use tauri::State;
use crate::db::DbState;

fn interpolate_variables(text: &str, variables: &HashMap<String, String>) -> String {
    let mut result = text.to_string();
    for (key, value) in variables {
        let placeholder = format!("{{{{{}}}}}", key);
        result = result.replace(&placeholder, value);
    }
    result
}

#[derive(serde::Serialize, serde::Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ExecuteRequestOptions {
    pub timeout_ms: Option<u64>,
    pub ssl_verify: Option<bool>,
    pub follow_redirects: Option<bool>,
    pub proxy_url: Option<String>,
    pub variables: Option<HashMap<String, String>>,
}

#[tauri::command]
pub async fn execute_request(
    request: APIRequest,
    options: Option<ExecuteRequestOptions>,
) -> Result<APIResponse, String> {
    let opts = options.unwrap_or(ExecuteRequestOptions {
        timeout_ms: Some(30000),
        ssl_verify: Some(true),
        follow_redirects: Some(true),
        proxy_url: None,
        variables: None,
    });

    let variables = opts.variables.unwrap_or_default();
    let timeout_ms = opts.timeout_ms.unwrap_or(30000);
    let ssl_verify = opts.ssl_verify.unwrap_or(true);
    let follow_redirects = opts.follow_redirects.unwrap_or(true);

    // Interpolate URL
    let url = interpolate_variables(&request.url, &variables);
    if url.is_empty() {
        return Err("URL is required".to_string());
    }

    // Build URL with query params
    let mut url_with_params = url::Url::parse(&url).map_err(|e| format!("Invalid URL: {}", e))?;

    let enabled_params: Vec<_> = request.params.iter()
        .filter(|p| p.enabled && !p.key.is_empty())
        .collect();

    if !enabled_params.is_empty() {
        let mut query_pairs = url_with_params.query_pairs_mut();
        for param in &enabled_params {
            let k = interpolate_variables(&param.key, &variables);
            let v = interpolate_variables(&param.value, &variables);
            query_pairs.append_pair(&k, &v);
        }
    }

    // Build client
    let mut client_builder = reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(timeout_ms))
        .danger_accept_invalid_certs(!ssl_verify);

    if !follow_redirects {
        client_builder = client_builder.redirect(reqwest::redirect::Policy::none());
    } else {
        client_builder = client_builder.redirect(reqwest::redirect::Policy::limited(10));
    }

    if let Some(proxy_url) = opts.proxy_url {
        if !proxy_url.is_empty() {
            let proxy = reqwest::Proxy::all(&proxy_url).map_err(|e| e.to_string())?;
            client_builder = client_builder.proxy(proxy);
        }
    }

    let client = client_builder.build().map_err(|e| e.to_string())?;

    let method = reqwest::Method::from_bytes(request.method.as_bytes())
        .map_err(|e| format!("Invalid method: {}", e))?;

    let mut req_builder = client.request(method, url_with_params.as_str());

    // Add headers
    for header in &request.headers {
        if header.enabled && !header.key.is_empty() {
            let k = interpolate_variables(&header.key, &variables);
            let v = interpolate_variables(&header.value, &variables);
            req_builder = req_builder.header(&k, &v);
        }
    }

    // Apply auth
    match &request.auth {
        Auth::Bearer { token } => {
            let t = interpolate_variables(token, &variables);
            req_builder = req_builder.header("Authorization", format!("Bearer {}", t));
        }
        Auth::Basic { username, password } => {
            let u = interpolate_variables(username, &variables);
            let p = interpolate_variables(password, &variables);
            req_builder = req_builder.basic_auth(u, Some(p));
        }
        Auth::ApiKey { key, value, location } => {
            let k = interpolate_variables(key, &variables);
            let v = interpolate_variables(value, &variables);
            if location == "header" {
                req_builder = req_builder.header(&k, &v);
            } else {
                let mut url2 = url::Url::parse(url_with_params.as_str()).unwrap();
                url2.query_pairs_mut().append_pair(&k, &v);
                req_builder = client.request(
                    reqwest::Method::from_bytes(request.method.as_bytes()).unwrap(),
                    url2.as_str(),
                );
            }
        }
        Auth::Digest { username, password } => {
            let u = interpolate_variables(username, &variables);
            let p = interpolate_variables(password, &variables);
            req_builder = req_builder.basic_auth(u, Some(p));
        }
        _ => {}
    }

    // Apply body
    match &request.body {
        RequestBody::Json { content } => {
            let interpolated = interpolate_variables(content, &variables);
            req_builder = req_builder
                .header("Content-Type", "application/json")
                .body(interpolated);
        }
        RequestBody::Raw { content, content_type } => {
            let interpolated = interpolate_variables(content, &variables);
            req_builder = req_builder
                .header("Content-Type", content_type.as_str())
                .body(interpolated);
        }
        RequestBody::UrlEncoded { fields } => {
            let form: Vec<(String, String)> = fields.iter()
                .filter(|f| f.enabled && !f.key.is_empty())
                .map(|f| (
                    interpolate_variables(&f.key, &variables),
                    interpolate_variables(&f.value, &variables),
                ))
                .collect();
            req_builder = req_builder.form(&form);
        }
        RequestBody::FormData { fields } => {
            let mut form = reqwest::multipart::Form::new();
            for field in fields.iter().filter(|f| f.enabled && !f.key.is_empty()) {
                let k = interpolate_variables(&field.key, &variables);
                let v = interpolate_variables(&field.value, &variables);
                form = form.text(k, v);
            }
            req_builder = req_builder.multipart(form);
        }
        RequestBody::GraphQL { query, variables: gql_vars } => {
            let vars_json: serde_json::Value = serde_json::from_str(gql_vars)
                .unwrap_or(serde_json::Value::Object(serde_json::Map::new()));
            let body = serde_json::json!({
                "query": query,
                "variables": vars_json
            });
            req_builder = req_builder
                .header("Content-Type", "application/json")
                .body(body.to_string());
        }
        RequestBody::Binary { file_path } => {
            let content = std::fs::read(file_path).map_err(|e| e.to_string())?;
            req_builder = req_builder.body(content);
        }
        RequestBody::None => {}
    }

    // Execute request with timing
    let start = Instant::now();
    let response = req_builder.send().await.map_err(|e| e.to_string())?;
    let total_elapsed = start.elapsed().as_secs_f64() * 1000.0;

    let status = response.status();
    let status_code = status.as_u16();
    let status_text = status.canonical_reason().unwrap_or("").to_string();

    // Collect response headers
    let resp_headers: Vec<KeyValue> = response.headers()
        .iter()
        .map(|(k, v)| KeyValue {
            id: uuid::Uuid::new_v4().to_string(),
            key: k.as_str().to_string(),
            value: v.to_str().unwrap_or("").to_string(),
            enabled: true,
            description: None,
        })
        .collect();

    // Extract cookies from Set-Cookie headers
    let cookies: Vec<Cookie> = response.headers()
        .get_all("set-cookie")
        .iter()
        .map(|v| {
            let cookie_str = v.to_str().unwrap_or("");
            parse_set_cookie(cookie_str)
        })
        .collect();

    let body_bytes = response.bytes().await.map_err(|e| e.to_string())?;
    let body_size = body_bytes.len() as u64;
    let body = String::from_utf8_lossy(&body_bytes).to_string();

    // Approximate timing breakdown (real DNS/TLS timing needs lower-level hooks)
    let wait_portion = total_elapsed * 0.7;
    let receive_portion = total_elapsed * 0.3;

    let timing = RequestTiming {
        dns_ms: 0.0,
        connect_ms: 0.0,
        tls_ms: 0.0,
        send_ms: 1.0,
        wait_ms: wait_portion,
        receive_ms: receive_portion,
        total_ms: total_elapsed,
    };

    Ok(APIResponse {
        status: status_code,
        status_text,
        headers: resp_headers,
        body,
        body_size,
        timing,
        cookies,
    })
}

fn parse_set_cookie(cookie_str: &str) -> Cookie {
    let parts: Vec<&str> = cookie_str.split(';').collect();
    let (name, value) = if let Some(first) = parts.first() {
        if let Some(eq_pos) = first.find('=') {
            (first[..eq_pos].trim().to_string(), first[eq_pos + 1..].trim().to_string())
        } else {
            (first.trim().to_string(), String::new())
        }
    } else {
        (String::new(), String::new())
    };

    let mut domain = None;
    let mut path = None;
    let mut expires = None;
    let mut http_only = false;
    let mut secure = false;

    for part in parts.iter().skip(1) {
        let p = part.trim();
        if p.eq_ignore_ascii_case("httponly") {
            http_only = true;
        } else if p.eq_ignore_ascii_case("secure") {
            secure = true;
        } else if let Some(rest) = p.strip_prefix("Domain=").or_else(|| p.strip_prefix("domain=")) {
            domain = Some(rest.to_string());
        } else if let Some(rest) = p.strip_prefix("Path=").or_else(|| p.strip_prefix("path=")) {
            path = Some(rest.to_string());
        } else if let Some(rest) = p.strip_prefix("Expires=").or_else(|| p.strip_prefix("expires=")) {
            expires = Some(rest.to_string());
        }
    }

    Cookie { name, value, domain, path, expires, http_only, secure }
}
