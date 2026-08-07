import SwiftUI
import Combine
import APISignalsCore
import APISignalsNetwork
import APISignalsPersistence

@MainActor
public final class AppState: ObservableObject {
    @Published public var workspaces: [Workspace] = []
    @Published public var selectedWorkspace: Workspace?
    @Published public var collections: [Collection] = []
    @Published public var environments: [WorkspaceEnvironment] = []
    @Published public var activeEnvironment: WorkspaceEnvironment?
    @Published public var selectedCollection: Collection?
    @Published public var requests: [APIRequest] = []
    @Published public var selectedRequest: APIRequest?
    @Published public var history: [HistoryEntry] = []

    // Multi-tab support
    @Published public var openTabs: [APIRequest] = []
    @Published public var selectedTabId: UUID?

    public var selectedTab: APIRequest? {
        get { openTabs.first { $0.id == selectedTabId } }
    }

    public func openTab(_ request: APIRequest) {
        if let idx = openTabs.firstIndex(where: { $0.id == request.id }) {
            openTabs[idx] = request
        } else {
            openTabs.append(request)
        }
        selectedTabId = request.id
        if selectedRequest?.id != request.id {
            selectedRequest = request
        } else if selectedRequest != request {
            selectedRequest = request
        }
    }

    public func closeTab(_ request: APIRequest) {
        openTabs.removeAll { $0.id == request.id }
        if selectedTabId == request.id {
            selectedTabId = openTabs.last?.id
            selectedRequest = openTabs.last
        }
    }

    public func updateTab(_ request: APIRequest) {
        if let idx = openTabs.firstIndex(where: { $0.id == request.id }) {
            openTabs[idx] = request
        }
    }

    public let persistence: GRDBPersistence
    public let workspaceRepository: any WorkspaceRepository
    public let collectionRepository: any CollectionRepository
    public let requestRepository: any RequestRepository
    public let environmentRepository: any EnvironmentRepository
    public let historyRepository: any HistoryRepository
    public let networkEngine: URLSessionNetworkEngine

    public init() {
        let baseDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("APISignals", isDirectory: true)

        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let dbPath = baseDirectory.appendingPathComponent("default.sqlite").path

        let persistence = try! GRDBPersistence(path: dbPath)
        self.persistence = persistence
        self.workspaceRepository = GRDBWorkspaceRepository(dbPool: persistence.dbPool)
        self.collectionRepository = GRDBCollectionRepository(dbPool: persistence.dbPool)
        self.requestRepository = GRDBRequestRepository(dbPool: persistence.dbPool)
        self.environmentRepository = GRDBEnvironmentRepository(dbPool: persistence.dbPool)
        self.historyRepository = GRDBHistoryRepository(dbPool: persistence.dbPool)
        self.networkEngine = URLSessionNetworkEngine()

        Task {
            await loadWorkspaces()
        }
    }

    public func loadWorkspaces() async {
        do {
            let workspaces = try await workspaceRepository.all()
            self.workspaces = workspaces
            if let first = workspaces.first {
                await selectWorkspace(first)
            } else {
                let defaultWorkspace = Workspace(name: "Default Workspace")
                let created = try await workspaceRepository.create(defaultWorkspace)
                self.workspaces = [created]
                await selectWorkspace(created)
            }
        } catch {
            print("Failed to load workspaces: \(error)")
        }
    }

    public func selectWorkspace(_ workspace: Workspace) async {
        self.selectedWorkspace = workspace
        do {
            let collections = try await collectionRepository.all(in: workspace.id)
            self.collections = collections
            if collections.isEmpty {
                let defaultCollection = Collection(workspaceId: workspace.id, name: "Default Collection")
                let created = try await collectionRepository.create(defaultCollection)
                self.collections = [created]
                self.selectedCollection = created
            } else {
                self.selectedCollection = collections.first
            }

            let environments = try await environmentRepository.all(in: workspace.id)
            self.environments = environments
            self.activeEnvironment = environments.first(where: \.isActive)

            await loadAllRequests(for: self.collections)

            await loadHistory(workspaceId: workspace.id)
        } catch {
            print("Failed to select workspace: \(error)")
        }
    }

    public func loadAllRequests(for collections: [Collection]) async {
        do {
            var all: [APIRequest] = []
            for collection in collections {
                let reqs = try await requestRepository.all(in: collection.id)
                all.append(contentsOf: reqs)
            }
            self.requests = all
            if selectedRequest == nil {
                self.selectedRequest = all.first
            }
            if all.isEmpty, let first = collections.first {
                await createNewRequest(in: first.id)
            }
        } catch {
            print("Failed to load requests: \(error)")
        }
    }

    public func loadRequests(collectionId: UUID) async {
        do {
            let requests = try await requestRepository.all(in: collectionId)
            let others = self.requests.filter { $0.collectionId != collectionId }
            self.requests = others + requests
            if let first = requests.first, selectedRequest == nil || selectedRequest?.collectionId == collectionId {
                self.selectedRequest = first
            } else if requests.isEmpty {
                await createNewRequest(in: collectionId)
            }
        } catch {
            print("Failed to load requests: \(error)")
        }
    }

    public func createNewRequest(in collectionId: UUID) async {
        let request = APIRequest(collectionId: collectionId, name: "New Request")
        do {
            let created = try await requestRepository.create(request)
            self.requests.append(created)
            self.selectedRequest = created
        } catch {
            print("Failed to create request: \(error)")
        }
    }

    public func renameRequest(_ request: APIRequest, newName: String) async {
        var updated = request
        updated.name = newName
        await updateRequest(updated)
    }

    public func deleteRequest(_ request: APIRequest) async {
        do {
            try await requestRepository.delete(id: request.id)
            self.requests.removeAll { $0.id == request.id }
            if selectedRequest?.id == request.id {
                selectedRequest = requests.first
            }
        } catch {
            print("Failed to delete request: \(error)")
        }
    }

    public func updateRequest(_ request: APIRequest) async {
        do {
            let updated = try await requestRepository.update(request)
            if let index = requests.firstIndex(where: { $0.id == updated.id }) {
                requests[index] = updated
            }
            updateTab(updated)
            // Avoid resetting the editor StateObject on every keystroke persist.
            if selectedRequest?.id == updated.id {
                selectedRequest = updated
            }
        } catch {
            print("Failed to update request: \(error)")
        }
    }

    public func createWorkspace(name: String) async {
        let workspace = Workspace(name: name)
        do {
            let created = try await workspaceRepository.create(workspace)
            self.workspaces.append(created)
            await selectWorkspace(created)
        } catch {
            print("Failed to create workspace: \(error)")
        }
    }

    public func createCollection(name: String) async {
        guard let workspace = selectedWorkspace else { return }
        let collection = Collection(workspaceId: workspace.id, name: name, sortOrder: collections.count)
        do {
            let created = try await collectionRepository.create(collection)
            self.collections.append(created)
            self.selectedCollection = created
            await loadRequests(collectionId: created.id)
        } catch {
            print("Failed to create collection: \(error)")
        }
    }

    public func renameCollection(_ collection: Collection, newName: String) async {
        var updated = collection
        updated.name = newName
        do {
            let saved = try await collectionRepository.update(updated)
            if let index = collections.firstIndex(where: { $0.id == saved.id }) {
                collections[index] = saved
            }
            if selectedCollection?.id == saved.id {
                selectedCollection = saved
            }
        } catch {
            print("Failed to rename collection: \(error)")
        }
    }

    public func deleteCollection(_ collection: Collection) async {
        do {
            let collectionRequests = try await requestRepository.all(in: collection.id)
            for request in collectionRequests {
                try await requestRepository.delete(id: request.id)
            }
            try await collectionRepository.delete(id: collection.id)
            self.collections.removeAll { $0.id == collection.id }
            self.requests.removeAll { $0.collectionId == collection.id }
            if selectedCollection?.id == collection.id {
                selectedCollection = collections.first
                if let first = selectedCollection {
                    await loadRequests(collectionId: first.id)
                } else {
                    self.requests = []
                    self.selectedRequest = nil
                }
            }
        } catch {
            print("Failed to delete collection: \(error)")
        }
    }

    public func importRequest(_ request: APIRequest) async {
        do {
            let created = try await requestRepository.create(request)
            self.requests.append(created)
        } catch {
            print("Failed to import request: \(error)")
        }
    }

    public func loadHistory(workspaceId: UUID) async {
        do {
            let history = try await historyRepository.all(in: workspaceId, limit: 50)
            self.history = history
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    public func addHistoryEntry(_ entry: HistoryEntry) async {
        do {
            try await historyRepository.add(entry)
            await loadHistory(workspaceId: entry.workspaceId)
        } catch {
            print("Failed to add history: \(error)")
        }
    }

    public func deleteHistoryEntry(_ entry: HistoryEntry) async {
        do {
            try await historyRepository.delete(id: entry.id)
            self.history.removeAll { $0.id == entry.id }
        } catch {
            print("Failed to delete history entry: \(error)")
        }
    }

    public func clearHistory() async {
        guard let workspace = selectedWorkspace else { return }
        do {
            try await historyRepository.clear(workspaceId: workspace.id)
            self.history = []
        } catch {
            print("Failed to clear history: \(error)")
        }
    }
}
