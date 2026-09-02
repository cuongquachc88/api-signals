use crate::models::{APIRequest, Auth, RequestBody, KeyValue};
use base64::Engine;

#[derive(serde::Serialize, serde::Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SnippetRequest {
    pub language: String, // "curl" | "fetch" | "python" | "go" | "php" | "ruby"
    pub request: APIRequest,
}

#[tauri::command]
pub fn generate_snippet(language: String, request: APIRequest) -> Result<String, String> {
    match language.as_str() {
        "curl" => Ok(generate_curl(&request)),
        "fetch" => Ok(generate_fetch(&request)),
        "python" => Ok(generate_python(&request)),
        "go" => Ok(generate_go(&request)),
        "php" => Ok(generate_php(&request)),
        "ruby" => Ok(generate_ruby(&request)),
        _ => Err(format!("Unknown language: {}", language)),
    }
}

fn build_url_with_params(request: &APIRequest) -> String {
    let enabled_params: Vec<_> = request.params.iter()
        .filter(|p| p.enabled && !p.key.is_empty())
        .collect();

    if enabled_params.is_empty() {
        return request.url.clone();
    }

    let query: Vec<String> = enabled_params.iter()
        .map(|p| format!("{}={}", urlencoding(&p.key), urlencoding(&p.value)))
        .collect();

    let separator = if request.url.contains('?') { "&" } else { "?" };
    format!("{}{}{}", request.url, separator, query.join("&"))
}

fn urlencoding(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}

fn get_headers(request: &APIRequest) -> Vec<(String, String)> {
    let mut headers: Vec<(String, String)> = request.headers.iter()
        .filter(|h| h.enabled && !h.key.is_empty())
        .map(|h| (h.key.clone(), h.value.clone()))
        .collect();

    // Add auth headers
    match &request.auth {
        Auth::Bearer { token } => {
            headers.push(("Authorization".to_string(), format!("Bearer {}", token)));
        }
        Auth::Basic { username, password } => {
            let creds = base64::engine::general_purpose::STANDARD
                .encode(format!("{}:{}", username, password));
            headers.push(("Authorization".to_string(), format!("Basic {}", creds)));
        }
        Auth::ApiKey { key, value, location } if location == "header" => {
            headers.push((key.clone(), value.clone()));
        }
        _ => {}
    }

    headers
}

fn generate_curl(request: &APIRequest) -> String {
    let mut parts: Vec<String> = vec![format!("curl -X {}", request.method)];
    let url = build_url_with_params(request);
    parts.push(format!("  '{}'", url));

    for (key, value) in get_headers(request) {
        parts.push(format!("  -H '{}: {}'", key, value));
    }

    match &request.body {
        RequestBody::Json { content } => {
            parts.push("  -H 'Content-Type: application/json'".to_string());
            // Compact JSON for curl
            let compact = serde_json::from_str::<serde_json::Value>(content)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| content.clone());
            parts.push(format!("  -d '{}'", compact.replace('\'', "'\\''")));
        }
        RequestBody::Raw { content, content_type } => {
            parts.push(format!("  -H 'Content-Type: {}'", content_type));
            parts.push(format!("  -d '{}'", content.replace('\'', "'\\''")));
        }
        RequestBody::UrlEncoded { fields } => {
            for f in fields.iter().filter(|f| f.enabled && !f.key.is_empty()) {
                parts.push(format!("  --data-urlencode '{}={}'", f.key, f.value));
            }
        }
        RequestBody::FormData { fields } => {
            for f in fields.iter().filter(|f| f.enabled && !f.key.is_empty()) {
                parts.push(format!("  -F '{}={}'", f.key, f.value));
            }
        }
        RequestBody::GraphQL { query, variables } => {
            let body = serde_json::json!({ "query": query, "variables": serde_json::from_str::<serde_json::Value>(variables).unwrap_or(serde_json::Value::Null) });
            parts.push("  -H 'Content-Type: application/json'".to_string());
            parts.push(format!("  -d '{}'", body.to_string().replace('\'', "'\\''")));
        }
        _ => {}
    }

    parts.join(" \\\n")
}

fn generate_fetch(request: &APIRequest) -> String {
    let url = build_url_with_params(request);
    let headers = get_headers(request);

    let mut headers_obj = String::from("{\n");
    for (k, v) in &headers {
        headers_obj.push_str(&format!("    '{}': '{}',\n", k, v));
    }

    // Content-Type for body
    let (body_str, content_type) = match &request.body {
        RequestBody::Json { content } => {
            let compact = serde_json::from_str::<serde_json::Value>(content)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| content.clone());
            (Some(format!("JSON.stringify({})", compact)), Some("application/json"))
        }
        RequestBody::Raw { content, content_type } => {
            (Some(format!("'{}'", content.replace('\'', "\\'"))), Some(content_type.as_str()))
        }
        RequestBody::UrlEncoded { fields } => {
            let pairs: Vec<String> = fields.iter()
                .filter(|f| f.enabled && !f.key.is_empty())
                .map(|f| format!("{}={}", urlencoding(&f.key), urlencoding(&f.value)))
                .collect();
            (Some(format!("'{}'", pairs.join("&"))), Some("application/x-www-form-urlencoded"))
        }
        RequestBody::GraphQL { query, variables } => {
            let body = serde_json::json!({ "query": query, "variables": serde_json::from_str::<serde_json::Value>(variables).unwrap_or(serde_json::Value::Null) });
            (Some(format!("JSON.stringify({})", body)), Some("application/json"))
        }
        _ => (None, None),
    };

    if let Some(ct) = content_type {
        headers_obj.push_str(&format!("    'Content-Type': '{}',\n", ct));
    }
    headers_obj.push_str("  }");

    let mut code = format!(
        "const response = await fetch('{}', {{\n  method: '{}',\n  headers: {}\n",
        url, request.method, headers_obj
    );

    if let Some(body) = body_str {
        code.push_str(&format!("  body: {}\n", body));
    }

    code.push_str("});\n\nconst data = await response.json();\nconsole.log(data);");
    code
}

fn generate_python(request: &APIRequest) -> String {
    let url = build_url_with_params(request);
    let headers = get_headers(request);

    let mut code = String::from("import requests\n\n");

    if !headers.is_empty() {
        code.push_str("headers = {\n");
        for (k, v) in &headers {
            code.push_str(&format!("    '{}': '{}',\n", k, v));
        }
        code.push_str("}\n\n");
    }

    let headers_arg = if headers.is_empty() { "" } else { ", headers=headers" };

    match &request.body {
        RequestBody::Json { content } => {
            let compact = serde_json::from_str::<serde_json::Value>(content)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| content.clone());
            code.push_str(&format!("data = {}\n\n", compact));
            code.push_str(&format!(
                "response = requests.{}('{}'{}, json=data)\n",
                request.method.to_lowercase(), url, headers_arg
            ));
        }
        RequestBody::UrlEncoded { fields } => {
            code.push_str("data = {\n");
            for f in fields.iter().filter(|f| f.enabled && !f.key.is_empty()) {
                code.push_str(&format!("    '{}': '{}',\n", f.key, f.value));
            }
            code.push_str("}\n\n");
            code.push_str(&format!(
                "response = requests.{}('{}'{}, data=data)\n",
                request.method.to_lowercase(), url, headers_arg
            ));
        }
        RequestBody::FormData { fields } => {
            code.push_str("files = {\n");
            for f in fields.iter().filter(|f| f.enabled && !f.key.is_empty()) {
                code.push_str(&format!("    '{}': '{}',\n", f.key, f.value));
            }
            code.push_str("}\n\n");
            code.push_str(&format!(
                "response = requests.{}('{}'{}, files=files)\n",
                request.method.to_lowercase(), url, headers_arg
            ));
        }
        _ => {
            code.push_str(&format!(
                "response = requests.{}('{}'{})\n",
                request.method.to_lowercase(), url, headers_arg
            ));
        }
    }

    code.push_str("\nprint(response.status_code)\nprint(response.json())");
    code
}

fn generate_go(request: &APIRequest) -> String {
    let url = build_url_with_params(request);
    let headers = get_headers(request);

    let mut code = String::from("package main\n\nimport (\n\t\"fmt\"\n\t\"io\"\n\t\"net/http\"\n\t\"strings\"\n)\n\nfunc main() {\n");

    let (body_str, content_type) = match &request.body {
        RequestBody::Json { content } => {
            let compact = serde_json::from_str::<serde_json::Value>(content)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| content.clone());
            (Some(compact), Some("application/json"))
        }
        RequestBody::Raw { content, content_type } => {
            (Some(content.clone()), Some(content_type.as_str()))
        }
        _ => (None, None),
    };

    if let Some(ref body) = body_str {
        code.push_str(&format!("\tbody := strings.NewReader(`{}`)\n\n", body));
        code.push_str(&format!("\treq, _ := http.NewRequest(\"{}\", \"{}\", body)\n", request.method, url));
    } else {
        code.push_str(&format!("\treq, _ := http.NewRequest(\"{}\", \"{}\", nil)\n", request.method, url));
    }

    for (k, v) in &headers {
        code.push_str(&format!("\treq.Header.Set(\"{}\", \"{}\")\n", k, v));
    }
    if let Some(ct) = content_type {
        code.push_str(&format!("\treq.Header.Set(\"Content-Type\", \"{}\")\n", ct));
    }

    code.push_str("\n\tclient := &http.Client{}\n\tresp, err := client.Do(req)\n");
    code.push_str("\tif err != nil {\n\t\tpanic(err)\n\t}\n\tdefer resp.Body.Close()\n\n");
    code.push_str("\tbody2, _ := io.ReadAll(resp.Body)\n\tfmt.Println(resp.StatusCode)\n\tfmt.Println(string(body2))\n}\n");

    code
}

fn generate_php(request: &APIRequest) -> String {
    let url = build_url_with_params(request);
    let headers = get_headers(request);

    let mut code = String::from("<?php\n\n$curl = curl_init();\n\n");
    code.push_str("curl_setopt_array($curl, [\n");
    code.push_str(&format!("  CURLOPT_URL => '{}',\n", url));
    code.push_str("  CURLOPT_RETURNTRANSFER => true,\n");
    code.push_str(&format!("  CURLOPT_CUSTOMREQUEST => '{}',\n", request.method));

    if !headers.is_empty() {
        code.push_str("  CURLOPT_HTTPHEADER => [\n");
        for (k, v) in &headers {
            code.push_str(&format!("    '{}: {}',\n", k, v));
        }
        code.push_str("  ],\n");
    }

    match &request.body {
        RequestBody::Json { content } => {
            let compact = serde_json::from_str::<serde_json::Value>(content)
                .map(|v| v.to_string())
                .unwrap_or_else(|_| content.clone());
            code.push_str(&format!("  CURLOPT_POSTFIELDS => '{}',\n", compact.replace('\'', "\\'")));
        }
        RequestBody::Raw { content, .. } => {
            code.push_str(&format!("  CURLOPT_POSTFIELDS => '{}',\n", content.replace('\'', "\\'")));
        }
        _ => {}
    }

    code.push_str("]);\n\n");
    code.push_str("$response = curl_exec($curl);\n$info = curl_getinfo($curl);\ncurl_close($curl);\n\n");
    code.push_str("echo $info['http_code'] . \"\\n\";\necho $response;\n");

    code
}

fn generate_ruby(request: &APIRequest) -> String {
    let url = build_url_with_params(request);
    let headers = get_headers(request);

    let mut code = String::from("require 'net/http'\nrequire 'uri'\nrequire 'json'\n\n");
    code.push_str(&format!("uri = URI.parse('{}')\n", url));
    code.push_str("http = Net::HTTP.new(uri.host, uri.port)\n");

    if url.starts_with("https://") {
        code.push_str("http.use_ssl = true\n");
    }

    code.push_str(&format!("\nrequest = Net::HTTP::{}.\nnew(uri.request_uri)\n",
        capitalize_first(&request.method.to_lowercase())));

    for (k, v) in &headers {
        code.push_str(&format!("request['{}'] = '{}'\n", k, v));
    }

    match &request.body {
        RequestBody::Json { content } => {
            code.push_str("request['Content-Type'] = 'application/json'\n");
            code.push_str(&format!("request.body = '{}'.to_json\n",
                content.replace('\'', "\\'")));
        }
        RequestBody::Raw { content, content_type } => {
            code.push_str(&format!("request['Content-Type'] = '{}'\n", content_type));
            code.push_str(&format!("request.body = '{}'\n", content.replace('\'', "\\'")));
        }
        _ => {}
    }

    code.push_str("\nresponse = http.request(request)\n");
    code.push_str("puts response.code\nputs response.body\n");

    code
}

fn capitalize_first(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}
