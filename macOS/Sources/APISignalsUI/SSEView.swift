import SwiftUI
import APISignalsNetwork

public struct SSEEventItem: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp = Date()
    public let event: String?
    public let data: String
    public let eventId: String?
}

@MainActor
public final class SSEViewModel: ObservableObject {
    @Published public var url: String = "http://localhost:8080/events"
    @Published public var events: [SSEEventItem] = []
    @Published public var isConnected: Bool = false
    @Published public var errorMessage: String?
    @Published public var customHeaders: String = ""

    private let engine = SSEEngine()
    private var streamTask: Task<Void, Never>?

    public init() {}

    public func connect() {
        guard let url = URL(string: url) else {
            errorMessage = "Invalid URL"
            return
        }
        errorMessage = nil
        isConnected = true
        events = []

        var headers: [String: String] = [:]
        for line in customHeaders.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: ":")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !key.isEmpty { headers[key] = value }
            }
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = await engine.connect(to: url, headers: headers)
            for await event in stream {
                await MainActor.run {
                    self.events.append(SSEEventItem(
                        event: event.event,
                        data: event.data,
                        eventId: event.id
                    ))
                }
            }
            await MainActor.run { self.isConnected = false }
        }
    }

    public func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        Task { await engine.disconnect() }
        isConnected = false
    }
}

public struct SSEView: View {
    @StateObject private var viewModel = SSEViewModel()
    @State private var showHeaders = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("SSE URL", text: $viewModel.url)
                    .textFieldStyle(.roundedBorder)

                Button {
                    showHeaders.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .buttonStyle(.bordered)
                .help("Custom Headers")

                if viewModel.isConnected {
                    Button("Disconnect") { viewModel.disconnect() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Connect") { viewModel.connect() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            if showHeaders {
                VStack(alignment: .leading) {
                    Text("Headers (one per line, Key: Value)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $viewModel.customHeaders)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .border(Color.secondary.opacity(0.3))
                }
                .padding(.horizontal)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            HStack {
                Text("\(viewModel.events.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !viewModel.events.isEmpty {
                    Button("Clear") { viewModel.events.removeAll() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            Divider()

            List(viewModel.events) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        if let event = item.event {
                            Text(event)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .cornerRadius(4)
                        } else {
                            Text("message")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let eventId = item.eventId {
                            Text("id: \(eventId)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(item.data)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
