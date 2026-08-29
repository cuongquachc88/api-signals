import SwiftUI
import AppKit
import APISignalsCore

// MARK: - Main Sidebar

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    @State private var collectionsExpanded = true
    @State private var environmentsExpanded = false
    @State private var historyExpanded = false
    @State private var isAddingWorkspace = false
    @State private var newWorkspaceName = ""
    @State private var searchText = ""

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            DSDivider()
            searchBar
            DSDivider()

            ScrollView {
                VStack(spacing: 0) {
                    collectionsSection
                    DSDivider().padding(.vertical, DS.Spacing.xs)
                    environmentsSection
                    DSDivider().padding(.vertical, DS.Spacing.xs)
                    historySection
                }
                .padding(.vertical, DS.Spacing.xs)
            }

            DSDivider()
            bottomBar
        }
        .background(Color.dsSurfEl)
        .onReceive(NotificationCenter.default.publisher(for: .showEnvironmentsTab)) { _ in
            environmentsExpanded = true
            collectionsExpanded = false
            historyExpanded = false
        }
    }

    // MARK: Workspace Header

    private var workspaceHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            // App icon + workspace
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#2F81F7"), Color(hex: "#1A56CC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 28, height: 28)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                Menu {
                    ForEach(appState.workspaces) { workspace in
                        Button {
                            Task { await appState.selectWorkspace(workspace) }
                        } label: {
                            HStack {
                                Text(workspace.name)
                                if workspace.id == appState.selectedWorkspace?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("New Workspace…") { isAddingWorkspace = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(appState.selectedWorkspace?.name ?? "Workspace")
                            .font(DS.Font.label)
                            .foregroundStyle(Color.dsTextPrim)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.dsTextSec)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { NotificationCenter.default.post(name: .showQuickOpen, object: nil) } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dsTextSec)
                    .frame(width: 28, height: 28)
                    .background(Color.dsBord.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            }
            .buttonStyle(.plain)
            .help("Search requests (⌘P)")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(height: 50)

        // New workspace inline
        .overlay(alignment: .bottom) {
            if isAddingWorkspace {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("Workspace name", text: $newWorkspaceName)
                        .textFieldStyle(.roundedBorder)
                        .font(DS.Font.body)
                        .onSubmit { createWorkspace() }
                    Button("Add") { createWorkspace() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("✕") {
                        isAddingWorkspace = false
                        newWorkspaceName = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dsTextSec)
                }
                .padding(DS.Spacing.sm)
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .padding(.horizontal, DS.Spacing.sm)
                .offset(y: 44)
                .zIndex(10)
            }
        }
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
            TextField("Search requests…", text: $searchText)
                .font(DS.Font.body)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(height: 36)
    }

    // MARK: Collections Section

    private var collectionsSection: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    collectionsExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: collectionsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.dsTextSec)
                        .frame(width: 12)
                    Text("COLLECTIONS")
                        .font(DS.Font.labelSm)
                        .foregroundStyle(Color.dsTextSec)
                        .tracking(0.5)
                    Spacer()
                    Button {
                        Task { await appState.createCollection(name: "New Collection") }
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsTextSec)
                    }
                    .buttonStyle(.plain)
                    .help("New Collection")
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .frame(height: 28)
            }
            .buttonStyle(.plain)

            if collectionsExpanded {
                CollectionsSidebarNew(appState: appState, searchText: searchText)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Environments Section

    private var environmentsSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    environmentsExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: environmentsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.dsTextSec)
                        .frame(width: 12)
                    Text("ENVIRONMENTS")
                        .font(DS.Font.labelSm)
                        .foregroundStyle(Color.dsTextSec)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .frame(height: 28)
            }
            .buttonStyle(.plain)

            if environmentsExpanded {
                EnvironmentsSidebarNew(appState: appState)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: History Section

    private var historySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: historyExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.dsTextSec)
                        .frame(width: 12)
                    Text("HISTORY")
                        .font(DS.Font.labelSm)
                        .foregroundStyle(Color.dsTextSec)
                        .tracking(0.5)
                    Spacer()
                    if !appState.history.isEmpty {
                        Button {
                            Task { await appState.clearHistory() }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dsTextSec)
                        }
                        .buttonStyle(.plain)
                        .help("Clear History")
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .frame(height: 28)
            }
            .buttonStyle(.plain)

            if historyExpanded {
                HistorySidebarNew(appState: appState)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "server.rack")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(appState.activeEnvironment != nil ? Color.dsGET : Color.dsTextTertiary)
            Text(appState.activeEnvironment?.name ?? "No environment")
                .font(DS.Font.caption)
                .foregroundStyle(Color.dsTextSec)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.sm)
            Text("\(appState.requests.count) requests")
                .font(DS.Font.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(minHeight: 36)
    }

    private func createWorkspace() {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isAddingWorkspace = false
        newWorkspaceName = ""
        Task { await appState.createWorkspace(name: name) }
    }
}

// MARK: - Collections Sidebar (redesigned)

struct CollectionsSidebarNew: View {
    @ObservedObject var appState: AppState
    let searchText: String
    @State private var renamingRequest: APIRequest?
    @State private var renameValue = ""
    @State private var renamingCollection: Collection?
    @State private var renameCollectionValue = ""
    @State private var expandedCollections: Set<UUID> = []
    @State private var addingRequestInCollection: UUID?
    @State private var importError: String?
    @State private var showImportError = false
    @State private var docCollection: Collection?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(appState.collections) { collection in
                collectionGroup(collection)
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .alert("Rename Request", isPresented: Binding(
            get: { renamingRequest != nil },
            set: { if !$0 { renamingRequest = nil } }
        )) {
            TextField("Name", text: $renameValue)
            Button("Save") {
                if let req = renamingRequest {
                    Task { await appState.renameRequest(req, newName: renameValue) }
                }
                renamingRequest = nil
            }
            Button("Cancel", role: .cancel) { renamingRequest = nil }
        }
        .alert("Rename Collection", isPresented: Binding(
            get: { renamingCollection != nil },
            set: { if !$0 { renamingCollection = nil } }
        )) {
            TextField("Name", text: $renameCollectionValue)
            Button("Save") {
                if let col = renamingCollection {
                    Task { await appState.renameCollection(col, newName: renameCollectionValue) }
                }
                renamingCollection = nil
            }
            Button("Cancel", role: .cancel) { renamingCollection = nil }
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .sheet(item: $docCollection) { col in
            CollectionDocView(collection: col) { updated in
                Task { _ = try? await appState.collectionRepository.update(updated) }
            }
        }
    }

    private func exportCollection(_ collection: Collection) {
        let requests = appState.requests.filter { $0.collectionId == collection.id }
        let exportData = CollectionExport(collection: collection, requests: requests)
        guard let data = try? JSONEncoder().encode(exportData) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(collection.name).json"
        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func importRequests(into collection: Collection) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url) else {
                importError = "Could not read file"; showImportError = true; return
            }
            do {
                let exportData = try JSONDecoder().decode(CollectionExport.self, from: data)
                for req in exportData.requests {
                    var imported = req
                    imported.collectionId = collection.id
                    await appState.importRequest(imported)
                }
                expandedCollections.insert(collection.id)
            } catch {
                importError = error.localizedDescription; showImportError = true
            }
        }
    }

    private func filteredRequests(for collection: Collection) -> [APIRequest] {
        let all = appState.requests.filter { $0.collectionId == collection.id }
        if searchText.isEmpty { return all }
        let q = searchText.lowercased()
        return all.filter {
            $0.name.lowercased().contains(q) ||
            $0.method.rawValue.lowercased().contains(q) ||
            ($0.url.url?.absoluteString ?? "").lowercased().contains(q)
        }
    }

    @ViewBuilder
    private func collectionGroup(_ collection: Collection) -> some View {
        let isExpanded = expandedCollections.contains(collection.id)
        let requests = filteredRequests(for: collection)

        VStack(spacing: 0) {
            // Collection header row
            HStack(spacing: DS.Spacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded { expandedCollections.remove(collection.id) }
                        else { expandedCollections.insert(collection.id) }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.dsTextSec)
                            .frame(width: 10)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsAcc)
                        Text(collection.name)
                            .font(DS.Font.label)
                            .foregroundStyle(Color.dsTextPrim)
                            .lineLimit(1)
                        Spacer()
                        Text("\(requests.count)")
                            .font(DS.Font.captionMono)
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
                .buttonStyle(.plain)

                Menu {
                    Button("New Request") {
                        Task { await appState.createNewRequest(in: collection.id) }
                        expandedCollections.insert(collection.id)
                    }
                    Divider()
                    Button("Documentation…") {
                        docCollection = collection
                    }
                    Divider()
                    Button("Export Collection…") {
                        exportCollection(collection)
                    }
                    Button("Import Requests…") {
                        importRequests(into: collection)
                    }
                    Divider()
                    Button("Rename") {
                        renamingCollection = collection
                        renameCollectionValue = collection.name
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        Task { await appState.deleteCollection(collection) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 5)
            .background(Color.dsBord.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))

            // Requests
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(requests) { request in
                        RequestRowNew(
                            request: request,
                            isSelected: appState.selectedRequest?.id == request.id
                        )
                        .onTapGesture {
                            appState.selectedRequest = request
                        }
                        .contextMenu {
                            Button("Open in New Tab") {
                                appState.openTab(request)
                            }
                            Button("Rename") {
                                renamingRequest = request
                                renameValue = request.name
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task { await appState.deleteRequest(request) }
                            }
                        }
                    }

                    // Add request button
                    Button {
                        Task { await appState.createNewRequest(in: collection.id) }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Spacer().frame(width: 10)
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.dsTextTertiary)
                            Text("New Request")
                                .font(DS.Font.caption)
                                .foregroundStyle(Color.dsTextTertiary)
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .dsRowHover()
                }
                .padding(.leading, DS.Spacing.sm)
            }
        }
        .onAppear {
            // Auto-expand collection containing selected request
            if appState.requests.filter({ $0.collectionId == collection.id })
                .contains(where: { $0.id == appState.selectedRequest?.id }) {
                expandedCollections.insert(collection.id)
            }
        }
    }
}

// MARK: - Request Row (redesigned)

struct RequestRowNew: View {
    let request: APIRequest
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Active indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.dsAcc : Color.clear)
                .frame(width: 2, height: 24)

            MethodBadge(method: request.method, compact: true)

            Text(request.name)
                .font(DS.Font.body)
                .foregroundStyle(isSelected ? Color.dsTextPrim : Color(nsColor: .labelColor).opacity(0.85))
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.trailing, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(isSelected
                    ? Color.dsAcc.opacity(0.12)
                    : isHovered ? Color.dsBord.opacity(0.4) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Environments Sidebar (redesigned)

struct EnvironmentsSidebarNew: View {
    @ObservedObject var appState: AppState
    @State private var newEnvironmentName = ""
    @State private var editingEnvironment: WorkspaceEnvironment?
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 2) {
            ForEach(appState.environments) { env in
                envRow(env)
            }

            if isAdding {
                HStack(spacing: DS.Spacing.xs) {
                    TextField("Environment name", text: $newEnvironmentName)
                        .textFieldStyle(.roundedBorder)
                        .font(DS.Font.body)
                        .controlSize(.small)
                        .onSubmit { addEnvironment() }
                    Button("Add") { addEnvironment() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newEnvironmentName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("✕") { isAdding = false; newEnvironmentName = "" }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.dsTextSec)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
            } else {
                Button {
                    isAdding = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.dsTextTertiary)
                        Text("New Environment")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextTertiary)
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, DS.Spacing.md)
                }
                .buttonStyle(.plain)
                .dsRowHover()
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .sheet(item: $editingEnvironment) { env in
            EnvironmentEditorSheet(environment: env) { updated in
                Task {
                    _ = try? await appState.environmentRepository.update(updated)
                    await appState.selectWorkspace(appState.selectedWorkspace!)
                }
                editingEnvironment = nil
            } onDismiss: {
                editingEnvironment = nil
            }
        }
    }

    @ViewBuilder
    private func envRow(_ env: WorkspaceEnvironment) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(env.isActive ? Color.dsGET : Color.dsTextTertiary)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(env.name)
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextPrim)
                Text("\(env.variables.count) var\(env.variables.count == 1 ? "" : "s")")
                    .font(DS.Font.caption)
                    .foregroundStyle(Color.dsTextTertiary)
            }
            Spacer()
            if env.isActive {
                Text("Active")
                    .font(DS.Font.captionMono)
                    .foregroundStyle(Color.dsGET)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.dsGET.opacity(0.12))
                    .clipShape(Capsule())
            }
            Button { editingEnvironment = env } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextSec)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xs)
                .fill(env.isActive ? Color.dsAcc.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                try? await appState.environmentRepository.setActive(id: env.id, workspaceId: env.workspaceId)
                await appState.selectWorkspace(appState.selectedWorkspace!)
            }
        }
        .dsRowHover()
    }

    private func addEnvironment() {
        let name = newEnvironmentName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let workspace = appState.selectedWorkspace else { return }
        Task {
            let env = WorkspaceEnvironment(workspaceId: workspace.id, name: name)
            _ = try? await appState.environmentRepository.create(env)
            newEnvironmentName = ""
            isAdding = false
            await appState.selectWorkspace(workspace)
        }
    }
}

// MARK: - History Sidebar (redesigned)

struct HistorySidebarNew: View {
    @ObservedObject var appState: AppState

    private var grouped: [(String, [HistoryEntry])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        var groups: [String: [HistoryEntry]] = [:]
        for entry in appState.history {
            let d = cal.startOfDay(for: entry.timestamp)
            let label: String
            if d == today { label = "Today" }
            else if d == yesterday { label = "Yesterday" }
            else { label = entry.timestamp.formatted(date: .abbreviated, time: .omitted) }
            groups[label, default: []].append(entry)
        }
        return groups.sorted { $0.value[0].timestamp > $1.value[0].timestamp }
    }

    var body: some View {
        if appState.history.isEmpty {
            HStack {
                Text("No history yet")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                ForEach(grouped, id: \.0) { (label, entries) in
                    HStack {
                        Text(label)
                            .font(DS.Font.captionMono)
                            .foregroundStyle(Color.dsTextTertiary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, DS.Spacing.xs)
                        Spacer()
                    }
                    ForEach(entries) { entry in
                        historyRow(entry)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
    }

    @ViewBuilder
    private func historyRow(_ entry: HistoryEntry) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            MethodBadge(method: entry.request.method, compact: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.request.url.url?.path ?? entry.request.name)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextPrim)
                    .lineLimit(1)
                if let response = entry.response {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(response.statusCode)")
                            .font(DS.Font.captionMono)
                            .foregroundStyle(statusCodeColor(response.statusCode))
                        Text("·")
                            .foregroundStyle(Color.dsTextTertiary)
                        Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedRequest = entry.request
        }
        .contextMenu {
            Button("Load Request") { appState.selectedRequest = entry.request }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await appState.deleteHistoryEntry(entry) }
            }
        }
        .dsRowHover()
    }
}

// MARK: - EnvironmentEditorSheet (kept functional)

struct EnvironmentEditorSheet: View {
    @State private var environment: WorkspaceEnvironment
    let onSave: (WorkspaceEnvironment) -> Void
    let onDismiss: () -> Void

    init(environment: WorkspaceEnvironment, onSave: @escaping (WorkspaceEnvironment) -> Void, onDismiss: @escaping () -> Void) {
        _environment = State(initialValue: environment)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.name)
                        .font(DS.Font.title)
                        .foregroundStyle(Color.dsTextPrim)
                    Text("\(environment.variables.count) variables")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextSec)
                }
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Save") { onSave(environment) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(DS.Spacing.lg)

            DSDivider()

            // Variable rows
            List {
                // Column headers
                HStack(spacing: DS.Spacing.sm) {
                    Color.clear.frame(width: 20)
                    Text("KEY")
                        .font(DS.Font.captionMono)
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("VALUE")
                        .font(DS.Font.captionMono)
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 56)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                ForEach($environment.variables) { $variable in
                    HStack(spacing: DS.Spacing.sm) {
                        Toggle("", isOn: $variable.isEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .frame(width: 20)
                        TextField("Key", text: $variable.key)
                            .textFieldStyle(.roundedBorder)
                            .font(DS.Font.bodyMono)
                            .frame(maxWidth: .infinity)
                        if variable.type == .secret {
                            SecureField("Value", text: $variable.value)
                                .textFieldStyle(.roundedBorder)
                                .font(DS.Font.bodyMono)
                                .frame(maxWidth: .infinity)
                        } else {
                            TextField("Value", text: $variable.value)
                                .textFieldStyle(.roundedBorder)
                                .font(DS.Font.bodyMono)
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            withAnimation { variable.type = variable.type == .secret ? .default : .secret }
                        } label: {
                            Image(systemName: variable.type == .secret ? "eye.slash.fill" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(variable.type == .secret ? Color.dsAcc : Color.dsTextTertiary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help(variable.type == .secret ? "Secret (masked)" : "Plain text")
                        Button {
                            environment.variables.removeAll { $0.id == variable.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dsError)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    environment.variables.append(Variable(key: "", value: ""))
                } label: {
                    Label("Add Variable", systemImage: "plus.circle")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsAcc)
                }
                .buttonStyle(.plain)
                .padding(.vertical, DS.Spacing.xs)
            }
            .listStyle(.plain)
        }
        .background(Color.dsSurf)
        .frame(width: 560, height: 420)
    }
}

// MARK: - Collection Export/Import format

struct CollectionExport: Codable {
    let version: Int
    let collectionName: String
    let requests: [APIRequest]

    init(collection: Collection, requests: [APIRequest]) {
        self.version = 1
        self.collectionName = collection.name
        self.requests = requests
    }
}
