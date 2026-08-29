import Foundation
import Network
import APISignalsCore

@MainActor
public final class MockServer: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var port: UInt16 = 8788
    @Published public var routes: [MockRoute] = []
    @Published public private(set) var lastError: String?

    private var listener: NWListener?
    private var connections: [NWConnection] = []

    public init() {}

    public func start(port: UInt16 = 8788) {
        stop()
        self.port = port
        self.lastError = nil
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            lastError = "Failed to create listener: \(error.localizedDescription)"
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                case .failed(let err):
                    self.isRunning = false
                    self.lastError = err.localizedDescription
                case .cancelled:
                    self.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.handle(connection)
            }
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
    }

    private func handle(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, _ in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let response = self.buildResponse(for: data)
                let responseData = response.data(using: .utf8) ?? Data()
                connection.send(content: responseData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func buildResponse(for requestData: Data) -> String {
        guard let requestText = String(data: requestData, encoding: .utf8),
              let firstLine = requestText.components(separatedBy: "\r\n").first else {
            return httpResponse(status: 400, body: "Bad Request", contentType: "text/plain")
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return httpResponse(status: 400, body: "Bad Request", contentType: "text/plain")
        }

        let method = parts[0]
        let path = parts[1].components(separatedBy: "?").first ?? parts[1]

        let matchingRoute = routes.first { route in
            route.isEnabled &&
            route.method.rawValue == method &&
            pathMatches(route.path, path)
        }

        if let route = matchingRoute {
            return httpResponse(status: route.statusCode, body: route.responseBody, contentType: route.responseContentType)
        } else {
            return httpResponse(status: 404, body: "{\"error\":\"No mock route matched\"}", contentType: "application/json")
        }
    }

    private func pathMatches(_ pattern: String, _ actual: String) -> Bool {
        if pattern == actual { return true }
        // Wildcard suffix match
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return actual.hasPrefix(prefix)
        }
        return false
    }

    private func httpResponse(status: Int, body: String, contentType: String) -> String {
        let statusText = HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        let bodyData = body.data(using: .utf8) ?? Data()
        return """
        HTTP/1.1 \(status) \(statusText)\r\n\
        Content-Type: \(contentType)\r\n\
        Content-Length: \(bodyData.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        Connection: close\r\n\
        \r\n\
        \(body)
        """
    }
}
