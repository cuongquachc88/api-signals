import Foundation

public struct CodeSnippetGenerator {
    public init() {}

    public func curlCommand(from request: APIRequest) -> String {
        return CurlConverter().generate(from: request)
    }

    public func pythonRequest(from request: APIRequest) -> String {
        var lines: [String] = [
            "import requests",
            "",
            "url = \"\(request.url.url?.absoluteString ?? "")\"",
        ]

        if !request.headers.isEmpty {
            let headers = request.headers.filter(\.isEnabled).map { "    \"\($0.key)\": \"\($0.value)\"" }.joined(separator: ",\n")
            lines.append("headers = {\n\(headers)\n}")
        } else {
            lines.append("headers = {}")
        }

        switch request.body {
        case .json(let text), .raw(let text, _):
            lines.append("payload = '''\(text)'''")
            lines.append("response = requests.\(request.method.rawValue.lowercased())(url, headers=headers, data=payload)")
        case .urlEncoded(let params):
            let data = params.filter(\.isEnabled).map { "    \"\($0.key)\": \"\($0.value)\"" }.joined(separator: ",\n")
            lines.append("data = {\n\(data)\n}")
            lines.append("response = requests.\(request.method.rawValue.lowercased())(url, headers=headers, data=data)")
        case .none:
            lines.append("response = requests.\(request.method.rawValue.lowercased())(url, headers=headers)")
        default:
            lines.append("response = requests.\(request.method.rawValue.lowercased())(url, headers=headers)")
        }

        lines.append("print(response.status_code)")
        lines.append("print(response.text)")

        return lines.joined(separator: "\n")
    }

    public func javaScriptFetch(from request: APIRequest) -> String {
        var lines: [String] = [
            "const url = '\(request.url.url?.absoluteString ?? "")';",
            "",
        ]

        let options = "const options = {\n    method: '\(request.method.rawValue)',\n"
        var optionsBody = [String]()

        if !request.headers.isEmpty {
            let headers = request.headers.filter(\.isEnabled).map { "        '\($0.key)': '\($0.value)'" }.joined(separator: ",\n")
            optionsBody.append("    headers: {\n\(headers)\n    }")
        }

        switch request.body {
        case .json(let text):
            optionsBody.append("    body: '\(text.replacingOccurrences(of: "'", with: "\\'"))'")
        case .raw(let text, _):
            optionsBody.append("    body: '\(text.replacingOccurrences(of: "'", with: "\\'"))'")
        default:
            break
        }

        lines.append(options + optionsBody.joined(separator: ",\n") + "\n};")
        lines.append("")
        lines.append("fetch(url, options)")
        lines.append("    .then(response => response.text())")
        lines.append("    .then(data => console.log(data))")
        lines.append("    .catch(error => console.error(error));")

        return lines.joined(separator: "\n")
    }

    public func swiftUrlSession(from request: APIRequest) -> String {
        var lines = [String]()
        lines.append("var request = URLRequest(url: URL(string: \"\(request.url.url?.absoluteString ?? "")\")!)")
        lines.append("request.httpMethod = \"\(request.method.rawValue)\"")

        for header in request.headers where header.isEnabled {
            lines.append("request.setValue(\"\(header.value)\", forHTTPHeaderField: \"\(header.key)\")")
        }

        switch request.body {
        case .json(let text), .raw(let text, _):
            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("request.httpBody = \"\(escaped)\".data(using: .utf8)")
        default:
            break
        }

        lines.append("")
        lines.append("let task = URLSession.shared.dataTask(with: request) { data, response, error in")
        lines.append("    if let error = error { print(error); return }")
        lines.append("    if let data = data { print(String(data: data, encoding: .utf8) ?? \"\") }")
        lines.append("}")
        lines.append("task.resume()")

        return lines.joined(separator: "\n")
    }
}
