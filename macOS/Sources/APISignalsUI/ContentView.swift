import SwiftUI
import APISignalsCore

public struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var isWebSocketPresented = false
    @State private var isSSEPresented = false
    @State private var isSettingsPresented = false
    @State private var isCollectionRunnerPresented = false
    @State private var isQuickOpenPresented = false
    @State private var isMockServerPresented = false
    @AppStorage("colorScheme") private var colorSchemePref: String = "auto"
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 250
    @State private var isDragging = false

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            SidebarView(appState: appState)
                .frame(width: max(180, min(CGFloat(sidebarWidth), 400)))
                .frame(maxHeight: .infinity)

            Rectangle()
                .fill(Color.dsBorder)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let newWidth = sidebarWidth + value.translation.width
                            sidebarWidth = max(180, min(newWidth, 400))
                        }
                )
                .onHover { inside in
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            VStack(spacing: 0) {
                AppChromeBar(
                    appState: appState,
                    onSearch: { isQuickOpenPresented = true },
                    onSSE: { isSSEPresented = true },
                    onWebSocket: { isWebSocketPresented = true },
                    onRun: { isCollectionRunnerPresented = true },
                    onSettings: { isSettingsPresented = true },
                    onMockServer: { isMockServerPresented = true }
                )
                TabsContainerView(appState: appState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color.dsBg)
        .sheet(isPresented: $isWebSocketPresented) { WebSocketView() }
        .sheet(isPresented: $isSSEPresented) { SSEView() }
        .sheet(isPresented: $isSettingsPresented) { SettingsView() }
        .sheet(isPresented: $isQuickOpenPresented) {
            QuickOpenViewDS(appState: appState) {
                isQuickOpenPresented = false
            }
        }
        .sheet(isPresented: $isMockServerPresented) {
            MockServerView()
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
        .onKeyPress(.init("k"), phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            isQuickOpenPresented = true
            return .handled
        }
        .onKeyPress(.init("p"), phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            isQuickOpenPresented = true
            return .handled
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

// MARK: - App Chrome Bar (search + environment — not in system toolbar)

struct AppChromeBar: View {
    @ObservedObject var appState: AppState
    let onSearch: () -> Void
    let onSSE: () -> Void
    let onWebSocket: () -> Void
    let onRun: () -> Void
    let onSettings: () -> Void
    var onMockServer: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Search — opens request finder (⌘P)
            Button(action: onSearch) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dsTextSec)
                    Text("Search requests…")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextTertiary)
                    Spacer(minLength: DS.Spacing.sm)
                    Text("⌘P")
                        .font(DS.Font.captionMono)
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.dsBord.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 10)
                .frame(maxWidth: 320)
                .background(Color.dsBg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(Color.dsBord, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            .help("Search requests by name, URL, or method (⌘P)")

            Spacer(minLength: DS.Spacing.lg)

            EnvironmentQuickSwitcherDS(appState: appState)

            HStack(spacing: DS.Spacing.xs) {
                chromeIconButton("antenna.radiowaves.left.and.right", help: "Server-Sent Events", action: onSSE)
                chromeIconButton("arrow.up.arrow.down.circle", help: "WebSocket", action: onWebSocket)
                if let mockAction = onMockServer {
                    chromeIconButton("server.rack", help: "Mock Server", action: mockAction)
                }
                chromeIconButton("play.fill", help: "Run Collection (⌘⇧R)", action: onRun)
                chromeIconButton("gearshape", help: "Settings (⌘,)", action: onSettings)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .frame(height: 52)
        .background(Color.dsSurf)
        .overlay(alignment: .bottom) {
            DSDivider()
        }
    }

    private func chromeIconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.dsTextSec)
                .frame(width: 32, height: 32)
                .background(Color.dsBg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(Color.dsBord, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .help(help)
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
                        isDirty: appState.dirtyTabIds.contains(request.id),
                        onSelect: {
                            appState.selectedTabId = request.id
                            appState.selectedRequest = request
                        },
                        onClose: {
                            appState.closeTab(request)
                        },
                        onRename: { newName in
                            Task { await appState.renameRequest(request, newName: newName) }
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
    let isDirty: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingName = ""
    @State private var glowPulse = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            MethodBadge(method: request.method, compact: true)

            if isEditing {
                TextField("", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextPrim)
                    .frame(maxWidth: 110, alignment: .leading)
                    .focused($nameFocused)
                    .onSubmit { commitRename() }
                    .onKeyPress(.escape) { cancelRename(); return .handled }
            } else {
                Text(request.name)
                    .font(DS.Font.body)
                    .foregroundStyle(isSelected ? Color.dsTextPrim : Color.dsTextSec)
                    .lineLimit(1)
                    .frame(maxWidth: 110, alignment: .leading)
                    .onTapGesture(count: 2) { startEditing() }
            }

            // Dirty indicator — glowing green dot when unsaved changes
            if isDirty && !isEditing {
                Circle()
                    .fill(Color.dsSuccess)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.dsSuccess.opacity(glowPulse ? 0.9 : 0.3), radius: glowPulse ? 4 : 2)
                    .scaleEffect(glowPulse ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: glowPulse)
                    .onAppear { glowPulse = true }
                    .onDisappear { glowPulse = false }
            }

            // Close button
            if isEditing {
                Color.clear.frame(width: 14, height: 14)
            } else {
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
        .onTapGesture { if !isEditing { onSelect() } }
        .onHover { isHovered = $0 }
    }

    private func startEditing() {
        editingName = request.name
        isEditing = true
        nameFocused = true
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        nameFocused = false
        if !trimmed.isEmpty && trimmed != request.name {
            onRename(trimmed)
        }
    }

    private func cancelRename() {
        isEditing = false
        nameFocused = false
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
            VStack(spacing: DS.Spacing.sm) {
                Text("No Request Open")
                    .font(DS.Font.title)
                    .foregroundStyle(Color.dsTextPrim)
                Text("Pick a request in the sidebar, or press ⌘P to search by name or URL.")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
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

    private var isActive: Bool { appState.activeEnvironment != nil }

    var body: some View {
        Menu {
            Section("Switch environment") {
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
                    Text("No environments yet")
                        .foregroundStyle(Color.dsTextSec)
                }
            }
            Divider()
            Button("Manage Environments…") {
                NotificationCenter.default.post(name: .showEnvironmentsTab, object: nil)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? Color.dsGET : Color.dsTextSec)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Environment")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text(appState.activeEnvironment?.name ?? "None selected")
                        .font(DS.Font.labelSm)
                        .foregroundStyle(Color.dsTextPrim)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.dsTextSec)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 10)
            .frame(minWidth: 180, maxWidth: 240, alignment: .leading)
            .background(Color.dsBg)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(Color.dsBord, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .menuStyle(.borderlessButton)
        .help("Active environment — variables applied when sending requests")
    }
}

// MARK: - Command Palette action

private struct PaletteAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let perform: () -> Void
}

// MARK: - Quick Open / Command Palette (⌘P / ⌘K)

struct QuickOpenViewDS: View {
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedIndex: Int = 0

    // Combined result items: requests first, then actions
    private enum ResultItem: Identifiable {
        case request(APIRequest, String) // request, collectionName
        case action(PaletteAction)
        var id: UUID {
            switch self {
            case .request(let r, _): return r.id
            case .action(let a): return a.id
            }
        }
    }

    private var allActions: [PaletteAction] {
        [
            PaletteAction(icon: "plus.circle", title: "New Request", subtitle: "Create a new request in current collection") {
                if let col = appState.selectedCollection {
                    Task { await appState.createNewRequest(in: col.id) }
                }
                onDismiss()
            },
            PaletteAction(icon: "gearshape", title: "Open Settings", subtitle: "Preferences, themes, timeouts") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
                onDismiss()
            },
            PaletteAction(icon: "play.fill", title: "Run Collection", subtitle: "Run all requests in active collection") {
                NotificationCenter.default.post(name: .showCollectionRunner, object: nil)
                onDismiss()
            },
            PaletteAction(icon: "arrow.up.arrow.down.circle", title: "Open WebSocket", subtitle: "WebSocket client panel") {
                onDismiss()
            },
            PaletteAction(icon: "antenna.radiowaves.left.and.right", title: "Open SSE Client", subtitle: "Server-Sent Events panel") {
                onDismiss()
            }
        ]
    }

    private var filteredResults: [ResultItem] {
        if searchText.isEmpty {
            let reqs = Array(appState.requests.prefix(8)).map {
                ResultItem.request($0, collectionName(for: $0))
            }
            let acts = allActions.map { ResultItem.action($0) }
            return reqs + acts
        }
        let q = searchText.lowercased()
        let reqs = appState.requests.filter {
            $0.name.lowercased().contains(q) ||
            ($0.url.url?.absoluteString ?? "").lowercased().contains(q) ||
            $0.method.rawValue.lowercased().contains(q)
        }.map { ResultItem.request($0, collectionName(for: $0)) }
        let acts = allActions.filter {
            $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
        }.map { ResultItem.action($0) }
        return reqs + acts
    }

    private func collectionName(for request: APIRequest) -> String {
        appState.collections.first { $0.id == request.collectionId }?.name ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Search field ──────────────────────────────────────────
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(searchText.isEmpty ? Color.dsTextTertiary : Color.dsAcc)
                    .frame(width: 22)

                TextField("Search requests or type a command…", text: $searchText)
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
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.sm)

            // ── Results ───────────────────────────────────────────────
            if filteredResults.isEmpty && !searchText.isEmpty {
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
            } else {
                Divider().opacity(0.5)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, item in
                                resultRow(for: item, index: index)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, i in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(i, anchor: .center)
                        }
                    }
                }
            }

            // ── Footer hint bar ───────────────────────────────────────
            if !filteredResults.isEmpty {
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
        .frame(width: 620)
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, filteredResults.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            activateItem(at: selectedIndex)
            return .handled
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
    }

    private func activateItem(at index: Int) {
        guard index < filteredResults.count else { return }
        switch filteredResults[index] {
        case .request(let r, _):
            appState.openTab(r)
            onDismiss()
        case .action(let a):
            a.perform()
        }
    }

    @ViewBuilder
    private func resultRow(for item: ResultItem, index: Int) -> some View {
        let isSelected = index == selectedIndex
        switch item {
        case .request(let request, let colName):
            QuickOpenRow(
                request: request,
                collectionName: colName,
                isSelected: isSelected
            ) {
                appState.openTab(request)
                onDismiss()
            }
        case .action(let action):
            PaletteActionRow(action: action, isSelected: isSelected) {
                action.perform()
            }
        }
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

// MARK: - Palette Action Row

private struct PaletteActionRow: View {
    let action: PaletteAction
    let isSelected: Bool
    let onActivate: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.dsAcc)
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dsTextPrim)
                        .lineLimit(1)
                    Text(action.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text("Action")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.dsBord.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

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
