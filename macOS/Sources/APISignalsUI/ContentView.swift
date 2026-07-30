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
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            TabsContainerView(appState: appState)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    NotificationCenter.default.post(name: .showQuickOpen, object: nil)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                        Text("Quick Open")
                            .font(DS.Font.caption)
                        Text("⌘P")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                    .foregroundStyle(Color.dsTextSec)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(Color.dsBord.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
                .help("Quick Open (⌘P)")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                EnvironmentQuickSwitcherDS(appState: appState)

                Divider()

                Button {
                    isSSEPresented = true
                } label: {
                    Label("SSE", systemImage: "antenna.radiowaves.left.and.right")
                        .font(DS.Font.caption)
                }
                .help("Server-Sent Events")

                Button {
                    isWebSocketPresented = true
                } label: {
                    Label("WS", systemImage: "arrow.up.arrow.down.circle")
                        .font(DS.Font.caption)
                }
                .help("WebSocket")

                Button {
                    isCollectionRunnerPresented = true
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(DS.Font.caption)
                }
                .help("Run Collection (⌘⇧R)")

                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                }
                .help("Settings (⌘,)")
            }
        }
        .sheet(isPresented: $isWebSocketPresented) { WebSocketView() }
        .sheet(isPresented: $isSSEPresented) { SSEView() }
        .sheet(isPresented: $isSettingsPresented) { SettingsView() }
        .sheet(isPresented: $isQuickOpenPresented) {
            QuickOpenViewDS(appState: appState) {
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

// MARK: - Tabs Container

struct TabsContainerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !appState.openTabs.isEmpty {
                TabBarView(appState: appState)
                DSDivider()
            }

            if let request = appState.openTabs.first(where: { $0.id == appState.selectedTabId }) {
                RequestEditorView(appState: appState, request: request)
                    .id(request.id)
            } else if let request = appState.selectedRequest {
                Color.clear.onAppear { appState.openTab(request) }
            } else {
                EmptyStateView()
            }
        }
        .background(Color.dsBg)
        .onChange(of: appState.selectedRequest) { _, newRequest in
            if let request = newRequest {
                appState.openTab(request)
            }
        }
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(appState.openTabs) { request in
                    TabItemViewDS(
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

                // New tab button
                Button {
                    if let collection = appState.selectedCollection {
                        Task { await appState.createNewRequest(in: collection.id) }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dsTextSec)
                        .frame(width: 28, height: 36)
                }
                .buttonStyle(.plain)
                .dsRowHover()
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .frame(height: 38)
        .background(Color.dsSurf)
    }
}

// MARK: - Tab Item (redesigned)

struct TabItemViewDS: View {
    let request: APIRequest
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            MethodBadge(method: request.method, compact: true)

            Text(request.name)
                .font(DS.Font.body)
                .foregroundStyle(isSelected ? Color.dsTextPrim : Color.dsTextSec)
                .lineLimit(1)
                .frame(maxWidth: 110, alignment: .leading)

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(width: 14, height: 14)
                    .background(isHovered ? Color.dsBord : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSelected ? 1 : 0)
            .frame(width: 14)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(isSelected ? Color.dsSurf : Color.clear)
        )
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(Color.dsAcc)
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.dsAcc.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.dsAcc.opacity(0.6))
            }
            VStack(spacing: DS.Spacing.xs) {
                Text("No Request Open")
                    .font(DS.Font.title)
                    .foregroundStyle(Color.dsTextPrim)
                Text("Select a request from the sidebar or press ⌘P to search")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBg)
    }
}

// MARK: - Environment Quick Switcher (redesigned)

struct EnvironmentQuickSwitcherDS: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Menu {
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
                        if env.isActive { Image(systemName: "checkmark") }
                    }
                }
            }
            if appState.environments.isEmpty {
                Text("No environments").foregroundStyle(Color.dsTextSec)
            }
            Divider()
            Button("Manage Environments") {
                NotificationCenter.default.post(name: .showEnvironmentsTab, object: nil)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(appState.activeEnvironment != nil ? Color.dsGET : Color.dsTextSec)
                    .frame(width: 6, height: 6)
                Text(appState.activeEnvironment?.name ?? "No Environment")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextPrim)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.dsTextSec)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xs)
            .background(Color.dsBord.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Quick Open (Spotlight-style)

struct QuickOpenViewDS: View {
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedIndex: Int = 0

    private var filteredRequests: [APIRequest] {
        if searchText.isEmpty { return Array(appState.requests.prefix(12)) }
        let q = searchText.lowercased()
        return appState.requests.filter {
            $0.name.lowercased().contains(q) ||
            ($0.url.url?.absoluteString ?? "").lowercased().contains(q) ||
            $0.method.rawValue.lowercased().contains(q)
        }
    }

    private func collectionName(for request: APIRequest) -> String {
        appState.collections.first { $0.id == request.collectionId }?.name ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Search field ──────────────────────────────────────────
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: searchText.isEmpty ? "magnifyingglass" : "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(searchText.isEmpty ? Color.dsTextTertiary : Color.dsAcc)
                    .frame(width: 22)

                TextField("Search requests…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.dsTextPrim)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, 18)

            // ── Results ───────────────────────────────────────────────
            if filteredRequests.isEmpty && !searchText.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .padding(.bottom, DS.Spacing.sm)
            } else if !filteredRequests.isEmpty {
                Divider().opacity(0.5)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredRequests.enumerated()), id: \.element.id) { index, request in
                                QuickOpenRow(
                                    request: request,
                                    collectionName: collectionName(for: request),
                                    isSelected: index == selectedIndex
                                ) {
                                    appState.openTab(request)
                                    onDismiss()
                                }
                                .id(index)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selectedIndex) { _, i in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(i, anchor: .center)
                        }
                    }
                }
            } else {
                // Empty search — show recent label
                if !appState.requests.isEmpty {
                    Divider().opacity(0.5)
                    HStack {
                        Text("RECENT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.dsTextTertiary)
                            .tracking(1)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xs)

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(filteredRequests.enumerated()), id: \.element.id) { index, request in
                                    QuickOpenRow(
                                        request: request,
                                        collectionName: collectionName(for: request),
                                        isSelected: index == selectedIndex
                                    ) {
                                        appState.openTab(request)
                                        onDismiss()
                                    }
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.bottom, DS.Spacing.xs)
                        }
                        .frame(maxHeight: 320)
                        .onChange(of: selectedIndex) { _, i in
                            proxy.scrollTo(i, anchor: .center)
                        }
                    }
                }
            }

            // ── Footer hint bar ───────────────────────────────────────
            if !filteredRequests.isEmpty {
                Divider().opacity(0.4)
                HStack(spacing: DS.Spacing.lg) {
                    Spacer()
                    hintItem(keys: ["↑", "↓"], label: "navigate")
                    hintItem(keys: ["↵"], label: "open")
                    hintItem(keys: ["esc"], label: "close")
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
        }
        .background(.regularMaterial)
        .frame(width: 600)
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, filteredRequests.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < filteredRequests.count {
                appState.openTab(filteredRequests[selectedIndex])
                onDismiss()
            }
            return .handled
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
    }

    private func hintItem(keys: [String], label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { k in
                Text(k)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.dsTextSec)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
        }
    }
}

// MARK: - Quick Open Row

struct QuickOpenRow: View {
    let request: APIRequest
    let collectionName: String
    let isSelected: Bool
    let onOpen: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: DS.Spacing.md) {
                // Method badge — fixed width for alignment
                Text(request.method.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(request.method.color)
                    .frame(width: 44, alignment: .center)
                    .padding(.vertical, 3)
                    .background(request.method.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                // Name + collection
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? Color.dsTextPrim : Color.dsTextPrim.opacity(0.9))
                        .lineLimit(1)
                    if !collectionName.isEmpty {
                        Text(collectionName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsTextTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Host
                Text(request.url.url?.host ?? request.url.url?.path ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.dsTextTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .trailing)

                // Arrow indicator when selected
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.dsAcc : Color.clear)
                    .frame(width: 16)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(isSelected
                        ? Color.dsAcc.opacity(0.13)
                        : isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(isSelected ? Color.dsAcc.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
    static let showCollectionRunner = Notification.Name("showCollectionRunner")
    static let showQuickOpen = Notification.Name("showQuickOpen")
    static let showEnvironmentsTab = Notification.Name("showEnvironmentsTab")
}
