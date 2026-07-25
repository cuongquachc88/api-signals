import SwiftUI
import APISignalsCore
import APISignalsNetwork

@MainActor
public final class WebSocketViewModel: ObservableObject {
    @Published public var url: String = "wss://echo.websocket.org"
    @Published public var messages: [WebSocketMessageItem] = []
    @Published public var inputMessage: String = ""
    @Published public var isConnected: Bool = false
    @Published public var errorMessage: String?

    private let engine = WebSocketEngine()

    public init() {
        engine.onEvent { [weak self] event in
            DispatchQueue.main.async {
                self?.handleEvent(event)
            }
        }
    }

    public func connect() {
        guard let url = URL(string: url) else {
            errorMessage = "Invalid URL"
            return
        }
        errorMessage = nil
        engine.connect(url: url)
    }

    public func disconnect() {
        engine.disconnect()
    }

    public func send() {
        guard !inputMessage.isEmpty else { return }
        let message = inputMessage
        Task {
            await engine.send(.text(message))
            DispatchQueue.main.async {
                self.messages.append(WebSocketMessageItem(direction: .sent, content: message))
                self.inputMessage = ""
            }
        }
    }

    private func handleEvent(_ event: WebSocketEngine.WebSocketEvent) {
        switch event {
        case .connected:
            isConnected = true
            messages.append(WebSocketMessageItem(direction: .system, content: "Connected"))
        case .disconnected(let reason):
            isConnected = false
            messages.append(WebSocketMessageItem(direction: .system, content: "Disconnected\(reason.map { ": \($0)" } ?? "")"))
        case .message(let message):
            switch message {
            case .text(let text):
                messages.append(WebSocketMessageItem(direction: .received, content: text))
            case .data(let data):
                messages.append(WebSocketMessageItem(direction: .received, content: "Data: \(data.count) bytes"))
            }
        case .error(let error):
            errorMessage = error
            messages.append(WebSocketMessageItem(direction: .system, content: "Error: \(error)"))
        }
    }
}

public struct WebSocketMessageItem: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp = Date()
    public var direction: Direction
    public var content: String

    public enum Direction: String, Sendable {
        case sent
        case received
        case system
    }
}

public struct WebSocketView: View {
    @StateObject private var viewModel = WebSocketViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("WebSocket URL", text: $viewModel.url)
                    .textFieldStyle(.roundedBorder)

                if viewModel.isConnected {
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Connect") {
                        viewModel.connect()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            List(viewModel.messages) { message in
                HStack {
                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60)

                    Text(message.direction.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(directionColor(message.direction))
                        .frame(width: 70)

                    Text(message.content)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(5)
                    Spacer()
                }
            }

            HStack {
                TextField("Message", text: $viewModel.inputMessage)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    viewModel.send()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isConnected || viewModel.inputMessage.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func directionColor(_ direction: WebSocketMessageItem.Direction) -> Color {
        switch direction {
        case .sent: return .blue
        case .received: return .green
        case .system: return .gray
        }
    }
}
