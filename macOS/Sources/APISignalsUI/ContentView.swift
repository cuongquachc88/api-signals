import SwiftUI
import APISignalsCore

public struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var isWebSocketPresented = false
    @State private var isSSEPresented = false
    @State private var isSettingsPresented = false
    @State private var isCollectionRunnerPresented = false
    @State private var isQuickOpenPresented = false
    @AppStorage("colorScheme") private var colorSchemePref: String = "auto"

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            TabsContainerView(appState: appState)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .toolbar {
            ToolbarItemGroup {
                EnvironmentQuickSwitcher(appState: appState)
                Button("SSE") { isSSEPresented = true }
                Button("WebSocket") { isWebSocketPresented = true }
            }
        }
        .sheet(isPresented: $isWebSocketPresented) { WebSocketView() }
        .sheet(isPresented: $isSSEPresented) { SSEView() }
        .sheet(isPresented: $isSettingsPresented) { SettingsView() }
        .sheet(isPresented: $isQuickOpenPresented) {
            QuickOpenView(appState: appState) {
                isQuickOpenPresented = false
            }
        }
        .sheet(isPresented: $isCollectionRunnerPresented) {
            if let collection = appState.selectedCollection {
                CollectionRunnerView(
                    collection: collection,
                    requests: appState.requests.filter { $0.collectionId == collection.id },
                    networkEngine: appState.networkEngine,
                    environment: appState.activeEnvironment
                )
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            isSettingsPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCollectionRunner)) { _ in
            isCollectionRunnerPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showQuickOpen)) { _ in
            isQuickOpenPresented = true
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePref {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

struct TabsContainerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !appState.openTabs.isEmpty {
                // Tab bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(appState.openTabs) { request in
                            TabItemView(
                                request: request,
                                isSelected: request.id == appState.selectedTabId,
                                onSelect: {
                                    appState.selectedTabId = request.id
                                    appState.selectedRequest = request
                                },
                                onClose: {
                                    appState.closeTab(request)
                                }
                            )
                        }
                    }
                }
                .frame(height: 34)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()
            }

            if let request = appState.openTabs.first(where: { $0.id == appState.selectedTabId }) {
                RequestEditorView(appState: appState, request: request)
                    .id(request.id)
            } else if let request = appState.selectedRequest {
                // Fallback: open tab for selected request
                Color.clear.onAppear { appState.openTab(request) }
            } else {
                VStack {
                    Spacer()
                    Text("Select a request from the sidebar")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .onChange(of: appState.selectedRequest) { _, newRequest in
            if let request = newRequest {
                appState.openTab(request)
            }
        }
    }
}

struct TabItemView: View {
    let request: APIRequest
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(request.method.rawValue)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(methodColor(request.method))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(methodColor(request.method).opacity(0.15))
                .cornerRadius(3)

            Text(request.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .leading)

            if isHovered || isSelected {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 14)
            } else {
                Spacer().frame(width: 14)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(isSelected ? Color(nsColor: .windowBackgroundColor) : Color.clear)
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .orange
        case .put: return .blue
        case .patch: return .purple
        case .delete: return .red
        default: return .secondary
        }
    }
}

public extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
    static let showCollectionRunner = Notification.Name("showCollectionRunner")
    static let showQuickOpen = Notification.Name("showQuickOpen")
}

struct EnvironmentQuickSwitcher: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Menu {
            if appState.environments.isEmpty {
                Text("No environments")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.environments) { env in
                    Button {
                        Task {
                            try? await appState.environmentRepository.setActive(
                                id: env.id, workspaceId: env.workspaceId
                            )
                            await appState.selectWorkspace(appState.selectedWorkspace!)
                        }
                    } label: {
                        HStack {
                            Text(env.name)
                            if env.isActive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Manage Environments") {
                // switch sidebar to environments tab via notification
                NotificationCenter.default.post(name: .showEnvironmentsTab, object: nil)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.stack.3d.up")
                Text(appState.activeEnvironment?.name ?? "No Environment")
                    .font(.caption)
            }
        }
    }
}

public extension Notification.Name {
    static let showEnvironmentsTab = Notification.Name("showEnvironmentsTab")
}
