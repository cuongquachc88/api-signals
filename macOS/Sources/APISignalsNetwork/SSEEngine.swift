import Foundation

public struct SSEEvent: Sendable {
    public let id: String?
    public let event: String?
    public let data: String
    public let retry: Int?
}

public actor SSEEngine {
    private var task: URLSessionDataTask?
    private var continuation: AsyncStream<SSEEvent>.Continuation?

    public init() {}

    public func connect(to url: URL, headers: [String: String] = [:]) -> AsyncStream<SSEEvent> {
        disconnect()

        return AsyncStream { cont in
            self.continuation = cont

            var request = URLRequest(url: url)
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let session = URLSession(configuration: .default)
            let delegate = SSEDelegate(continuation: cont)
            let task = session.dataTask(with: request)
            task.delegate = delegate
            task.resume()
            self.task = task

            cont.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func disconnect() {
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
    }
}

private final class SSEDelegate: NSObject, URLSessionDataDelegate {
    private let continuation: AsyncStream<SSEEvent>.Continuation
    private var buffer = ""
    private let lock = NSLock()

    init(continuation: AsyncStream<SSEEvent>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        buffer += text
        lock.unlock()
        processBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        continuation.finish()
    }

    private func processBuffer() {
        lock.lock()
        var lines = buffer.components(separatedBy: "\n")
        buffer = lines.removeLast()
        lock.unlock()

        var eventId: String?
        var eventType: String?
        var dataLines: [String] = []
        var retryValue: Int?

        for line in lines {
            if line.isEmpty {
                if !dataLines.isEmpty {
                    let event = SSEEvent(
                        id: eventId,
                        event: eventType,
                        data: dataLines.joined(separator: "\n"),
                        retry: retryValue
                    )
                    continuation.yield(event)
                }
                eventId = nil
                eventType = nil
                dataLines = []
                retryValue = nil
            } else if line.hasPrefix(":") {
                // comment, ignore
            } else if line.hasPrefix("id:") {
                eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("retry:") {
                retryValue = Int(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
            }
        }
    }
}
