import Foundation

public enum CurlConversionError: Error {
    case invalidCommand
    case missingURL
}

public struct CurlConverter {
    public init() {}

    /// Returns true when `text` looks like a curl command (including multiline paste).
    public static func looksLikeCurl(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let first = trimmed.split(whereSeparator: { $0.isNewline || $0.isWhitespace }).first.map(String.init) ?? ""
        return first.lowercased() == "curl"
    }

    public func parse(_ command: String) throws -> APIRequest {
        var trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.looksLikeCurl(trimmed) else {
            throw CurlConversionError.invalidCommand
        }

        // Collapse shell line-continuations so `\` never becomes the URL token.
        trimmed = trimmed
            .replacingOccurrences(of: "\\\r\n", with: " ")
            .replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\\\r", with: " ")

        // Drop leading `curl`
        if let range = trimmed.range(of: #"^curl\b"#, options: [.regularExpression, .caseInsensitive]) {
            trimmed.removeSubrange(range)
        }
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = tokenize(trimmed)
        var method: HTTPMethod = .get
        var methodExplicit = false
        var urlString: String?
        var headers: [Header] = []
        var bodyString: String?
        var contentType: String?
        var auth: Auth = .none
        var formFields: [FormField] = []

        var index = 0
        while index < tokens.count {
            let token = tokens[index]

            // Skip bare line-continuation leftovers
            if token == "\\" {
                index += 1
                continue
            }

            switch token {
            case "-X", "--request":
                if index + 1 < tokens.count {
                    method = HTTPMethod(rawValue: tokens[index + 1].uppercased()) ?? .get
                    methodExplicit = true
                    index += 2
                } else {
                    index += 1
                }
            case "-H", "--header":
                if index + 1 < tokens.count {
                    let headerString = tokens[index + 1]
                    if let separatorIndex = headerString.firstIndex(of: ":") {
                        let key = String(headerString[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(headerString[headerString.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
                        headers.append(Header(key: key, value: value))

                        if key.lowercased() == "content-type" {
                            contentType = value
                        }
                        if key.lowercased() == "authorization", case .none = auth {
                            auth = parseAuthorization(value)
                        }
                    }
                    index += 2
                } else {
                    index += 1
                }
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii", "--data-urlencode", "--json":
                if index + 1 < tokens.count {
                    let value = tokens[index + 1]
                    if bodyString == nil {
                        bodyString = value
                    } else {
                        bodyString = (bodyString ?? "") + "&" + value
                    }
                    // `--json` implies JSON content-type + POST
                    if token == "--json" {
                        contentType = contentType ?? "application/json"
                    }
                    index += 2
                } else {
                    index += 1
                }
            case "-F", "--form", "--form-string":
                if index + 1 < tokens.count {
                    let field = tokens[index + 1]
                    if let eq = field.firstIndex(of: "=") {
                        let key = String(field[..<eq])
                        var value = String(field[field.index(after: eq)...])
                        var type: FormField.FieldType = .text
                        if value.hasPrefix("@") {
                            type = .file
                            value = String(value.dropFirst())
                        }
                        formFields.append(FormField(key: key, value: value, type: type))
                    }
                    index += 2
                } else {
                    index += 1
                }
            case "-u", "--user":
                if index + 1 < tokens.count {
                    let credentials = tokens[index + 1]
                    let parts = credentials.split(separator: ":", maxSplits: 1)
                    let username = String(parts.first ?? "")
                    let password = parts.count > 1 ? String(parts[1]) : ""
                    auth = .basic(username: username, password: password)
                    index += 2
                } else {
                    index += 1
                }
            case "-G", "--get":
                method = .get
                methodExplicit = true
                index += 1
            case "-I", "--head":
                method = .head
                methodExplicit = true
                index += 1
            // Flags with a following value we should skip
            case "-A", "--user-agent",
                 "-b", "--cookie",
                 "-c", "--cookie-jar",
                 "-e", "--referer",
                 "-m", "--max-time",
                 "--connect-timeout",
                 "-o", "--output",
                 "-w", "--write-out",
                 "--proxy", "-x",
                 "--max-redirs",
                 "--cert", "--key", "--cacert", "--capath",
                 "--unix-socket",
                 "--resolve",
                 "--retry":
                index += tokenHasValue(after: index, in: tokens) ? 2 : 1
            // Boolean / no-value flags
            case "-L", "--location",
                 "-k", "--insecure",
                 "-s", "--silent",
                 "-S", "--show-error",
                 "-v", "--verbose",
                 "-i", "--include",
                 "-f", "--fail",
                 "-C", "--continue-at",
                 "--compressed",
                 "--http1.1", "--http2", "--http2-prior-knowledge",
                 "--location-trusted",
                 "--raw",
                 "--globoff", "-g":
                index += 1
            default:
                if token.hasPrefix("--") || token.hasPrefix("-") {
                    // Unknown flag: skip optional value if next token isn't another flag/URL-looking token
                    if index + 1 < tokens.count,
                       !tokens[index + 1].hasPrefix("-"),
                       !(tokens[index + 1].contains("://") || tokens[index + 1].hasPrefix("http")) {
                        index += 2
                    } else {
                        index += 1
                    }
                } else {
                    // Prefer the first URL-looking token; don't overwrite a real URL with junk.
                    let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if urlString == nil || looksLikeURL(cleaned) {
                        if looksLikeURL(cleaned) || urlString == nil {
                            urlString = cleaned
                        }
                    }
                    index += 1
                }
            }
        }

        guard let urlString, !urlString.isEmpty, urlString != "\\" else {
            throw CurlConversionError.missingURL
        }

        var components = URLComponents(string: urlString) ?? URLComponents()
        let queryParams = components.queryItems?.map { Parameter(key: $0.name, value: $0.value ?? "") } ?? []
        components.queryItems = nil

        var body: RequestBody = .none
        if !formFields.isEmpty {
            body = .formData(formFields)
            if !methodExplicit { method = .post }
        } else if let bodyString {
            if let contentType, contentType.lowercased().contains("json") {
                body = .json(bodyString)
            } else if let contentType, contentType.lowercased().contains("urlencoded") {
                let params = bodyString.split(separator: "&").map { pair -> Parameter in
                    let parts = pair.split(separator: "=", maxSplits: 1)
                    return Parameter(
                        key: String(parts.first ?? ""),
                        value: parts.count > 1 ? String(parts[1]) : ""
                    )
                }
                body = .urlEncoded(params)
            } else if bodyString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                body = .json(bodyString)
            } else {
                body = .raw(text: bodyString, mimeType: contentType ?? "application/x-www-form-urlencoded")
            }
            if !methodExplicit { method = .post }
        }

        let host = components.host ?? "cURL"
        return APIRequest(
            name: "Imported cURL — \(host)",
            method: method,
            url: components,
            headers: headers,
            queryParams: queryParams,
            body: body,
            auth: auth
        )
    }

    public func generate(from request: APIRequest) -> String {
        var parts: [String] = ["curl"]

        if request.method != .get {
            parts.append("-X \(request.method.rawValue)")
        }

        let urlString = request.url.url?.absoluteString ?? ""
        parts.append("\"\(urlString)\"")

        for header in request.headers where header.isEnabled {
            parts.append("-H \"\(header.key): \(header.value)\"")
        }

        switch request.auth {
        case .bearer(let token):
            parts.append("-H \"Authorization: Bearer \(token)\"")
        case .basic(let username, let password):
            parts.append("-u \"\(username):\(password)\"")
        case .apiKey(let key, let value, let location):
            switch location {
            case .header:
                parts.append("-H \"\(key): \(value)\"")
            case .query:
                break
            }
        default:
            break
        }

        switch request.body {
        case .none:
            break
        case .raw(let text, let mimeType):
            parts.append("-H \"Content-Type: \(mimeType)\"")
            parts.append("-d '\(text)'")
        case .json(let text):
            parts.append("-H \"Content-Type: application/json\"")
            parts.append("-d '\(text)'")
        case .urlEncoded(let params):
            let encoded = params.filter(\.isEnabled).map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            parts.append("-H \"Content-Type: application/x-www-form-urlencoded\"")
            parts.append("-d '\(encoded)'")
        case .formData(let fields):
            for field in fields where field.isEnabled {
                if field.type == .file {
                    parts.append("-F '\(field.key)=@\(field.value)'")
                } else {
                    parts.append("-F '\(field.key)=\(field.value)'")
                }
            }
        case .graphql(let query, let variables):
            parts.append("-H \"Content-Type: application/json\"")
            if let data = try? GraphQLPayload.encode(query: query, variablesJSON: variables),
               let json = String(data: data, encoding: .utf8) {
                let escaped = json.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("-d '\(escaped)'")
            } else {
                let escapedQuery = query
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                parts.append("-d '{\"query\":\"\(escapedQuery)\"}'")
            }
        case .binary:
            parts.append("--data-binary @file")
        }

        return parts.joined(separator: " ")
    }

    private func tokenize(_ command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character?

        for char in command {
            if char == "\"" || char == "'" {
                if inQuotes {
                    if quoteChar == char {
                        inQuotes = false
                        quoteChar = nil
                    } else {
                        current.append(char)
                    }
                } else {
                    inQuotes = true
                    quoteChar = char
                }
            } else if char.isWhitespace && !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func tokenHasValue(after index: Int, in tokens: [String]) -> Bool {
        guard index + 1 < tokens.count else { return false }
        let next = tokens[index + 1]
        return !next.hasPrefix("-")
    }

    private func looksLikeURL(_ token: String) -> Bool {
        let lower = token.lowercased()
        return lower.hasPrefix("http://")
            || lower.hasPrefix("https://")
            || lower.hasPrefix("ws://")
            || lower.hasPrefix("wss://")
            || lower.contains("://")
    }

    private func parseAuthorization(_ value: String) -> Auth {
        let lowercased = value.lowercased()
        if lowercased.hasPrefix("bearer ") {
            let token = String(value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            return .bearer(token: token)
        } else if lowercased.hasPrefix("basic ") {
            let base64 = String(value.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if let data = Data(base64Encoded: base64),
               let credentials = String(data: data, encoding: .utf8) {
                let parts = credentials.split(separator: ":", maxSplits: 1)
                return .basic(username: String(parts.first ?? ""), password: parts.count > 1 ? String(parts[1]) : "")
            }
        }
        return .none
    }
}
