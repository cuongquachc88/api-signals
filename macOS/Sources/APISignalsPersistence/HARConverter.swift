import Foundation
import APISignalsCore

public enum HARConverterError: Error {
    case invalidData
    case invalidVersion
}

public struct HARConverter {
    public init() {}

    // MARK: - Import

    public func importFromFile(url: URL, workspaceId: UUID) throws -> (collection: Collection, requests: [APIRequest]) {
        let data = try Data(contentsOf: url)
        return try importFromData(data, workspaceId: workspaceId)
    }

    public func importFromData(_ data: Data, workspaceId: UUID) throws -> (collection: Collection, requests: [APIRequest]) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let log = json["log"] as? [String: Any] else {
            throw HARConverterError.invalidData
        }

        let title = (log["pages"] as? [[String: Any]])?.first?["title"] as? String ?? "HAR Import"
        let collection = Collection(workspaceId: workspaceId, name: title)

        var requests: [APIRequest] = []
        let entries = log["entries"] as? [[String: Any]] ?? []

        for entry in entries {
            guard let request = entry["request"] as? [String: Any] else { continue }
            if let apiRequest = convertEntry(request: request, collectionId: collection.id) {
                requests.append(apiRequest)
            }
        }

        return (collection, requests)
    }

    private func convertEntry(request: [String: Any], collectionId: UUID) -> APIRequest? {
        guard let methodStr = request["method"] as? String,
              let urlStr = request["url"] as? String else { return nil }

        let method = HTTPMethod(rawValue: methodStr.uppercased()) ?? .get
        var components = URLComponents(string: urlStr) ?? URLComponents()

        let name = "\(methodStr.uppercased()) \(components.path.isEmpty ? urlStr : components.path)"

        // Strip query from URL components (we'll add them as params)
        let queryItems = components.queryItems ?? []
        components.queryItems = nil

        var headers: [Header] = []
        if let harHeaders = request["headers"] as? [[String: Any]] {
            for h in harHeaders {
                guard let name = h["name"] as? String,
                      let value = h["value"] as? String else { continue }
                // Skip pseudo-headers and common browser-only headers
                guard !name.hasPrefix(":") else { continue }
                headers.append(Header(key: name, value: value))
            }
        }

        let params = queryItems.map { Parameter(key: $0.name, value: $0.value ?? "") }

        var body: RequestBody = .none
        if let postData = request["postData"] as? [String: Any],
           let mimeType = postData["mimeType"] as? String,
           let text = postData["text"] as? String {
            if mimeType.contains("application/x-www-form-urlencoded") {
                let fields = text.components(separatedBy: "&").compactMap { pair -> Parameter? in
                    let parts = pair.components(separatedBy: "=")
                    guard parts.count >= 1 else { return nil }
                    let key = parts[0].removingPercentEncoding ?? parts[0]
                    let value = (parts.count > 1 ? parts[1...].joined(separator: "=") : "")
                        .removingPercentEncoding ?? ""
                    return Parameter(key: key, value: value)
                }
                body = .urlEncoded(fields)
            } else if mimeType.contains("multipart/form-data") {
                if let params = postData["params"] as? [[String: Any]] {
                    let fields = params.compactMap { p -> FormField? in
                        guard let name = p["name"] as? String else { return nil }
                        let value = p["value"] as? String ?? ""
                        return FormField(key: name, value: value)
                    }
                    body = .formData(fields)
                }
            } else {
                body = .raw(text: text, mimeType: mimeType)
            }
        }

        return APIRequest(
            collectionId: collectionId,
            name: name,
            method: method,
            url: components,
            headers: headers,
            queryParams: params,
            body: body,
            auth: .none
        )
    }

    // MARK: - Export

    public func export(responses: [(request: APIRequest, response: APIResponse)]) -> Data {
        let entries = responses.map { pair in
            harEntry(request: pair.request, response: pair.response)
        }

        let har: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": ["name": "API Signals", "version": "1.0"],
                "entries": entries
            ]
        ]

        return (try? JSONSerialization.data(withJSONObject: har, options: [.prettyPrinted])) ?? Data()
    }

    private func harEntry(request: APIRequest, response: APIResponse) -> [String: Any] {
        let urlStr = request.url.url?.absoluteString ?? ""

        let harHeaders = request.headers.filter(\.isEnabled).map { h -> [String: String] in
            ["name": h.key, "value": h.value]
        }
        let harQueryString = request.queryParams.filter(\.isEnabled).map { p -> [String: String] in
            ["name": p.key, "value": p.value]
        }

        var postData: [String: Any] = [:]
        switch request.body {
        case .raw(let text, let mime):
            postData = ["mimeType": mime as Any, "text": text]
        case .urlEncoded(let fields):
            let text = fields.filter(\.isEnabled).map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            postData = ["mimeType": "application/x-www-form-urlencoded", "text": text]
        default:
            break
        }

        let harRequest: [String: Any] = [
            "method": request.method.rawValue,
            "url": urlStr,
            "httpVersion": "HTTP/1.1",
            "headers": harHeaders,
            "queryString": harQueryString,
            "postData": postData,
            "headersSize": -1,
            "bodySize": -1
        ]

        let responseHeaders = response.headers.map { h -> [String: String] in
            ["name": h.key, "value": h.value]
        }
        let bodyText = response.body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let mimeType = response.mimeType ?? "text/plain"

        let harResponse: [String: Any] = [
            "status": response.statusCode,
            "statusText": response.statusText,
            "httpVersion": "HTTP/1.1",
            "headers": responseHeaders,
            "cookies": [],
            "content": [
                "size": response.size.body,
                "mimeType": mimeType,
                "text": bodyText
            ],
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": response.size.body
        ]

        return [
            "startedDateTime": ISO8601DateFormatter().string(from: Date()),
            "time": response.timing.total * 1000,
            "request": harRequest,
            "response": harResponse,
            "cache": [:],
            "timings": ["send": 0, "wait": response.timing.total * 1000, "receive": 0]
        ]
    }
}
