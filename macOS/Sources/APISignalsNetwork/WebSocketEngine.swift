import Foundation
import APISignalsCore

public final class WebSocketEngine: @unchecked Sendable {
    public enum WebSocketEvent: Sendable {
        case connected
        case disconnected(String?)
        case message(WebSocketMessage)
        case error(String)
    }

    public enum WebSocketMessage: Sendable {
        case text(String)
        case data(Data)
    }

    private var task: URLSessionWebSocketTask?
    private let lock = NSLock()
    private var eventHandler: ((WebSocketEvent) -> Void)?

    public init() {}

    public func connect(url: URL, headers: [Header] = []) {
        disconnect()

        var request = URLRequest(url: url)
        for header in headers where header.isEnabled {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        let task = URLSession.shared.webSocketTask(with: request)
        lock.lock()
        self.task = task
        lock.unlock()

        task.resume()
        DispatchQueue.main.async {
            self.eventHandler?(.connected)
        }

        receiveMessages(task: task)
    }

    public func disconnect(message: String? = nil) {
        lock.lock()
        let task = self.task
        self.task = nil
        lock.unlock()

        task?.cancel(with: .normalClosure, reason: message?.data(using: .utf8))
        DispatchQueue.main.async {
            self.eventHandler?(.disconnected(message))
        }
    }

    public func send(_ message: WebSocketMessage) async {
        let task = lock.withLock { self.task }

        guard let task = task else {
            DispatchQueue.main.async {
                self.eventHandler?(.error("Not connected"))
            }
            return
        }

        do {
            switch message {
            case .text(let text):
                try await task.send(.string(text))
            case .data(let data):
                try await task.send(.data(data))
            }
        } catch {
            DispatchQueue.main.async {
                self.eventHandler?(.error(error.localizedDescription))
            }
        }
    }

    public func onEvent(_ handler: @escaping @Sendable (WebSocketEvent) -> Void) {
        lock.lock()
        self.eventHandler = handler
        lock.unlock()
    }

    private func receiveMessages(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self.eventHandler?(.message(.text(text)))
                    }
                case .data(let data):
                    DispatchQueue.main.async {
                        self.eventHandler?(.message(.data(data)))
                    }
                @unknown default:
                    break
                }
                self.receiveMessages(task: task)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.eventHandler?(.error(error.localizedDescription))
                }
            }
        }
    }
}
