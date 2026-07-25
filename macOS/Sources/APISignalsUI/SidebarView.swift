import SwiftUI
import APISignalsCore

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SidebarTab = .collections
    @State private var isAddingWorkspace = false
    @State private var newWorkspaceName = ""

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Workspace switcher header
            HStack {
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
                    Button("New Workspace...") { isAddingWorkspace = true }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundStyle(.blue)
                        Text(appState.selectedWorkspace?.name ?? "Workspace")
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            if isAddingWorkspace {
                HStack {
                    TextField("Workspace name", text: $newWorkspaceName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { createWorkspace() }
                    Button("Add") { createWorkspace() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newWorkspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        isAddingWorkspace = false
                        newWorkspaceName = ""
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .collections:
                CollectionsSidebar(appState: appState)
            case .environments:
                EnvironmentsSidebar(appState: appState)
            case .history:
                HistorySidebar(appState: appState)
            }

            if let environment = appState.activeEnvironment {
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(environment.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .navigationTitle("API Signals")
        .onReceive(NotificationCenter.default.publisher(for: .showEnvironmentsTab)) { _ in
            selectedTab = .environments
        }
    }

    private func createWorkspace() {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isAddingWorkspace = false
        newWorkspaceName = ""
        Task {
            await appState.createWorkspace(name: name)
        }
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case collections = "Collections"
    case environments = "Environments"
    case history = "History"

    var id: String { rawValue }
}

struct CollectionsSidebar: View {
    @ObservedObject var appState: AppState
    @State private var renamingRequest: APIRequest?
    @State private var renameValue = ""
    @State private var renamingCollection: Collection?
    @State private var renameCollectionValue = ""
    @State private var isAddingCollection = false
    @State private var newCollectionName = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedRequest) {
                ForEach(appState.collections) { collection in
                    Section {
                        ForEach(appState.requests.filter { $0.collectionId == collection.id }) { request in
                            RequestRow(request: request)
                                .tag(request)
                                .contextMenu {
                                    Button("Rename") {
                                        renamingRequest = request
                                        renameValue = request.name
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await appState.deleteRequest(request)
                                        }
                                    }
                                }
                        }
                        Button("+ New Request") {
                            Task {
                                await appState.createNewRequest(in: collection.id)
                            }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    } header: {
                        HStack {
                            Text(collection.name)
                                .font(.headline)
                            Spacer()
                            Menu {
                                Button("Rename Collection") {
                                    renamingCollection = collection
                                    renameCollectionValue = collection.name
                                }
                                Divider()
                                Button("Delete Collection", role: .destructive) {
                                    Task {
                                        await appState.deleteCollection(collection)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 20)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            if isAddingCollection {
                HStack {
                    TextField("Collection name", text: $newCollectionName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addCollection()
                        }
                    Button("Add") {
                        addCollection()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cancel", role: .cancel) {
                        isAddingCollection = false
                        newCollectionName = ""
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
            } else {
                Button("+ New Collection") {
                    isAddingCollection = true
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .alert("Rename Request", isPresented: Binding(
            get: { renamingRequest != nil },
            set: { if !$0 { renamingRequest = nil } }
        )) {
            TextField("Name", text: $renameValue)
            Button("Save") {
                if let request = renamingRequest {
                    Task {
                        await appState.renameRequest(request, newName: renameValue)
                    }
                }
                renamingRequest = nil
            }
            Button("Cancel", role: .cancel) {
                renamingRequest = nil
            }
        }
        .alert("Rename Collection", isPresented: Binding(
            get: { renamingCollection != nil },
            set: { if !$0 { renamingCollection = nil } }
        )) {
            TextField("Name", text: $renameCollectionValue)
            Button("Save") {
                if let collection = renamingCollection {
                    Task {
                        await appState.renameCollection(collection, newName: renameCollectionValue)
                    }
                }
                renamingCollection = nil
            }
            Button("Cancel", role: .cancel) {
                renamingCollection = nil
            }
        }
    }

    private func addCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            await appState.createCollection(name: name)
        }
        newCollectionName = ""
        isAddingCollection = false
    }
}

struct RequestRow: View {
    let request: APIRequest

    var body: some View {
        HStack {
            Text(request.method.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(methodColor)
                .frame(width: 48, alignment: .leading)
            Text(request.name)
                .lineLimit(1)
            Spacer()
        }
    }

    private var methodColor: Color {
        switch request.method {
        case .get: return .blue
        case .post: return .green
        case .put: return .orange
        case .delete: return .red
        case .patch: return .purple
        default: return .gray
        }
    }
}

struct EnvironmentsSidebar: View {
    @ObservedObject var appState: AppState
    @State private var newEnvironmentName = ""
    @State private var editingEnvironment: WorkspaceEnvironment?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(appState.environments) { (environment: WorkspaceEnvironment) in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(environment.name)
                            Text("\(environment.variables.count) variable\(environment.variables.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if environment.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        Button {
                            editingEnvironment = environment
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            try? await appState.environmentRepository.setActive(id: environment.id, workspaceId: environment.workspaceId)
                            await appState.selectWorkspace(appState.selectedWorkspace!)
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("New environment", text: $newEnvironmentName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addEnvironment() }
                Button("Add") {
                    addEnvironment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newEnvironmentName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
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

    private func addEnvironment() {
        let name = newEnvironmentName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let workspace = appState.selectedWorkspace else { return }
        Task {
            let env = WorkspaceEnvironment(workspaceId: workspace.id, name: name)
            _ = try? await appState.environmentRepository.create(env)
            newEnvironmentName = ""
            await appState.selectWorkspace(workspace)
        }
    }
}

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
            HStack {
                Text("Edit: \(environment.name)")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.borderless)
                Button("Save") { onSave(environment) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            List {
                ForEach($environment.variables) { $variable in
                    HStack(spacing: 8) {
                        Toggle("", isOn: $variable.isEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        TextField("Key", text: $variable.key)
                            .textFieldStyle(.roundedBorder)
                        if variable.type == .secret {
                            SecureField("Value", text: $variable.value)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("Value", text: $variable.value)
                                .textFieldStyle(.roundedBorder)
                        }
                        Picker("", selection: $variable.type) {
                            Text("Default").tag(Variable.VariableType.default)
                            Text("Secret").tag(Variable.VariableType.secret)
                        }
                        .frame(width: 90)
                        .labelsHidden()
                        Button(role: .destructive) {
                            environment.variables.removeAll { $0.id == variable.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button("+ Add Variable") {
                    environment.variables.append(Variable(key: "", value: ""))
                }
                .buttonStyle(.link)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct HistorySidebar: View {
    @ObservedObject var appState: AppState
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(appState.history) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.request.method.rawValue)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(methodColor(entry.request.method))
                            Text(entry.request.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        HStack {
                            if let response = entry.response {
                                Text("\(response.statusCode)")
                                    .font(.caption2)
                                    .foregroundStyle(response.statusCode < 400 ? .green : .red)
                                Text(formatTime(response.timing.total))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedRequest = entry.request
                    }
                    .contextMenu {
                        Button("Delete") {
                            Task {
                                await appState.deleteHistoryEntry(entry)
                            }
                        }
                    }
                }
            }

            if !appState.history.isEmpty {
                Divider()
                Button("Clear All History") {
                    showClearConfirmation = true
                }
                .foregroundStyle(.red)
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .confirmationDialog("Clear all history?", isPresented: $showClearConfirmation) {
                    Button("Clear All", role: .destructive) {
                        Task {
                            await appState.clearHistory()
                        }
                    }
                }
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        String(format: "%.0fms", interval * 1000)
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .blue
        case .post: return .green
        case .put: return .orange
        case .delete: return .red
        case .patch: return .purple
        default: return .gray
        }
    }
}
