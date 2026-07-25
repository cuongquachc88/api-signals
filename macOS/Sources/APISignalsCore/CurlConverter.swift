import Foundation

public enum CurlConversionError: Error {
    case invalidCommand
    case missingURL
}

public struct CurlConverter {
    public init() {}

    public func parse(_ command: String) throws -> APIRequest {
        var trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("curl") else {
            throw CurlConversionError.invalidCommand
        }

        trimmed.removeFirst(4)
        trimmed = trimmed.trimmingCharacters(in: .whitespaces)

        let tokens = tokenize(trimmed)
        var method: HTTPMethod = .get
        var urlString: String?
        var headers: [Header] = []
        var bodyString: String?
        var contentType: String?
        var auth: Auth = .none

        var index = 0
        while index < tokens.count {
            let token = tokens[index]

            switch token {
            case "-X", "--request":
                if index + 1 < tokens.count {
                    method = HTTPMethod(rawValue: tokens[index + 1].uppercased()) ?? .get
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
                        if key.lowercased() == "authorization" {
                            auth = parseAuthorization(value)
                        }
                    }
                    index += 2
                } else {
                    index += 1
                }
            case "-d", "--data", "--data-raw", "--data-binary":
                if index + 1 < tokens.count {
                    bodyString = tokens[index + 1]
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
            default:
                if !token.hasPrefix("-") {
                    urlString = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
                index += 1
            }
        }

        guard let urlString = urlString else {
            throw CurlConversionError.missingURL
        }

        var components = URLComponents(string: urlString) ?? URLComponents()
        let queryParams = components.queryItems?.map { Parameter(key: $0.name, value: $0.value ?? "") } ?? []
        components.queryItems = nil

        var body: RequestBody = .none
        if let bodyString = bodyString {
            if let contentType = contentType, contentType.contains("json") {
                body = .json(bodyString)
            } else {
                body = .raw(text: bodyString, mimeType: contentType ?? "application/x-www-form-urlencoded")
            }
        }

        return APIRequest(
            name: "Imported cURL",
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
                // Already in URL query params
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
        case .graphql(let query, _):
            parts.append("-H \"Content-Type: application/json\"")
            let payload = "{\"query\":\"\(query.replacingOccurrences(of: "\"", with: "\\\""))\"}"
            parts.append("-d '\(payload)'")
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
