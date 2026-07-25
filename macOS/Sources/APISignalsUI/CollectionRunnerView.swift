import SwiftUI
import APISignalsCore
import APISignalsNetwork

public struct CollectionRunnerResult: Identifiable, Sendable {
    public let id = UUID()
    public let request: APIRequest
    public var status: RunStatus
    public var response: APIResponse?
    public var error: String?
    public var duration: TimeInterval?

    public enum RunStatus: Sendable {
        case pending
        case running
        case success
        case failure
    }
}

@MainActor
public final class CollectionRunnerViewModel: ObservableObject {
    @Published public var results: [CollectionRunnerResult] = []
    @Published public var isRunning = false
    @Published public var currentIndex: Int = 0
    @Published public var delay: Double = 0.0
    @Published public var stopOnFailure = false
    @Published public var selectedIndices: Set<UUID>

    private let requests: [APIRequest]
    private let networkEngine: URLSessionNetworkEngine
    private let environment: WorkspaceEnvironment?
    private var runTask: Task<Void, Never>?

    public init(
        requests: [APIRequest],
        networkEngine: URLSessionNetworkEngine,
        environment: WorkspaceEnvironment?
    ) {
        self.requests = requests
        self.networkEngine = networkEngine
        self.environment = environment
        self.selectedIndices = Set(requests.map(\.id))
        self.results = requests.map {
            CollectionRunnerResult(request: $0, status: .pending)
        }
    }

    public func run() {
        guard !isRunning else { return }
        isRunning = true
        currentIndex = 0

        results = requests.map { CollectionRunnerResult(request: $0, status: .pending) }

        runTask = Task {
            for (index, request) in requests.enumerated() {
                guard !Task.isCancelled else { break }
                guard selectedIndices.contains(request.id) else {
                    currentIndex = index + 1
                    continue
                }

                currentIndex = index
                results[index].status = .running

                let start = Date()
                let result = await networkEngine.execute(request, environment: environment)
                let duration = Date().timeIntervalSince(start)

                switch result {
                case .success(let response):
                    results[index].status = .success
                    results[index].response = response
                    results[index].duration = duration
                case .failure(let error):
                    results[index].status = .failure
                    results[index].error = error.localizedDescription
                    results[index].duration = duration
                    if stopOnFailure { break }
                }

                currentIndex = index + 1

                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            isRunning = false
        }
    }

    public func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    public var passCount: Int { results.filter { $0.status == .success }.count }
    public var failCount: Int { results.filter { $0.status == .failure }.count }
    public var pendingCount: Int { results.filter { $0.status == .pending }.count }
}

public struct CollectionRunnerView: View {
    @StateObject private var viewModel: CollectionRunnerViewModel
    let collection: Collection
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init(
        collection: Collection,
        requests: [APIRequest],
        networkEngine: URLSessionNetworkEngine,
        environment: WorkspaceEnvironment?
    ) {
        self.collection = collection
        _viewModel = StateObject(wrappedValue: CollectionRunnerViewModel(
            requests: requests,
            networkEngine: networkEngine,
            environment: environment
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Run Collection")
                        .font(.headline)
                    Text(collection.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                // Request list
                VStack(alignment: .leading, spacing: 0) {
                    Text("Requests (\(viewModel.selectedIndices.count) selected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    List(viewModel.results) { result in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { viewModel.selectedIndices.contains(result.request.id) },
                                set: { enabled in
                                    if enabled {
                                        viewModel.selectedIndices.insert(result.request.id)
                                    } else {
                                        viewModel.selectedIndices.remove(result.request.id)
                                    }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .disabled(viewModel.isRunning)

                            Image(systemName: statusIcon(result.status))
                                .foregroundStyle(statusColor(result.status))
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.request.name)
                                    .lineLimit(1)
                                HStack {
                                    Text(result.request.method.rawValue)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(methodColor(result.request.method))

                                    if let duration = result.duration {
                                        Text(String(format: "%.0fms", duration * 1000))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let response = result.response {
                                        Text("\(response.statusCode)")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(response.statusCode < 400 ? .green : .red)
                                    }

                                    if let error = result.error {
                                        Text(error)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: 320)

                Divider()

                // Run controls + summary
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Run Options") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Delay between requests:")
                                Spacer()
                                Slider(value: $viewModel.delay, in: 0...5, step: 0.5)
                                    .frame(width: 120)
                                Text(String(format: "%.1fs", viewModel.delay))
                                    .frame(width: 30)
                            }
                            Toggle("Stop on failure", isOn: $viewModel.stopOnFailure)
                        }
                        .padding(4)
                    }
                    .disabled(viewModel.isRunning)

                    GroupBox("Summary") {
                        VStack(spacing: 12) {
                            if viewModel.isRunning {
                                ProgressView(value: Double(viewModel.currentIndex), total: Double(viewModel.results.count))
                                Text("Running \(viewModel.currentIndex) / \(viewModel.results.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 20) {
                                summaryBadge(count: viewModel.passCount, label: "Passed", color: .green)
                                summaryBadge(count: viewModel.failCount, label: "Failed", color: .red)
                                summaryBadge(count: viewModel.pendingCount, label: "Pending", color: .secondary)
                            }
                        }
                        .padding(4)
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        if viewModel.isRunning {
                            Button("Stop") { viewModel.stop() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Run All") { viewModel.run() }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.selectedIndices.isEmpty)
                        }
                    }
                }
                .padding()
                .frame(minWidth: 280)
            }
        }
        .frame(minWidth: 650, minHeight: 450)
    }

    private func statusIcon(_ status: CollectionRunnerResult.RunStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .running: return "arrow.clockwise"
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: CollectionRunnerResult.RunStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .running: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .orange
        case .put: return .blue
        case .delete: return .red
        default: return .secondary
        }
    }

    private func summaryBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
