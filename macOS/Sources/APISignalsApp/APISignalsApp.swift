import SwiftUI
import AppKit
import APISignalsUI
import APISignalsPersistence
import APISignalsCore
import APISignalsNetwork

@main
struct APISignalsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Export Workspace...") {
                    exportWorkspace()
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])

                Button("Import Workspace...") {
                    importWorkspace()
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])

                Divider()

                Button("Import Postman Collection...") {
                    importPostmanCollection()
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])

                Button("Export as Postman Collection...") {
                    exportPostmanCollection()
                }
                .keyboardShortcut("P", modifiers: [.command, .option])

                Divider()

                Button("Import cURL...") {
                    importCurl()
                }
                .keyboardShortcut("C", modifiers: [.command, .shift])

                Divider()

                Button("Import OpenAPI...") {
                    importOpenAPI()
                }

                Divider()

                Button("Import HAR...") {
                    importHAR()
                }

                Button("Export HAR...") {
                    exportHAR()
                }
            }

            CommandGroup(after: .toolbar) {
                Button("Quick Open...") {
                    NotificationCenter.default.post(name: .showQuickOpen, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandMenu("Request") {
                Button("New Request") {
                    Task {
                        if let collection = appState.selectedCollection {
                            await appState.createNewRequest(in: collection.id)
                        }
                    }
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Delete Request") {
                    Task {
                        if let request = appState.selectedRequest {
                            await appState.deleteRequest(request)
                        }
                    }
                }
                .keyboardShortcut("d", modifiers: [.command])

                Divider()

                Button("Run Collection") {
                    NotificationCenter.default.post(name: .showCollectionRunner, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func exportWorkspace() {
        guard let workspace = appState.selectedWorkspace else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(workspace.name).apisignals.json"

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }

            let exporter = WorkspaceExporter(
                workspaceRepository: appState.workspaceRepository,
                collectionRepository: appState.collectionRepository,
                requestRepository: appState.requestRepository,
                environmentRepository: appState.environmentRepository
            )

            do {
                try await exporter.exportToFile(workspaceId: workspace.id, url: url)
            } catch {
                print("Export failed: \(error)")
            }
        }
    }

    private func importWorkspace() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }

            let exporter = WorkspaceExporter(
                workspaceRepository: appState.workspaceRepository,
                collectionRepository: appState.collectionRepository,
                requestRepository: appState.requestRepository,
                environmentRepository: appState.environmentRepository
            )

            do {
                let snapshot = try await exporter.importFromFile(url: url)
                try await exporter.importSnapshot(snapshot)
                await appState.loadWorkspaces()
            } catch {
                print("Import failed: \(error)")
            }
        }
    }

    private func importPostmanCollection() {
        guard let workspace = appState.selectedWorkspace else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }

            do {
                let postmanCollection = try PostmanCollection.importFromFile(url: url)
                let converter = PostmanCollectionConverter()
                let (collection, requests) = converter.convert(postmanCollection: postmanCollection, workspaceId: workspace.id)

                let createdCollection = try await appState.collectionRepository.create(collection)
                for request in requests {
                    var request = request
                    request.collectionId = createdCollection.id
                    _ = try await appState.requestRepository.create(request)
                }

                await appState.selectWorkspace(workspace)
            } catch {
                print("Postman import failed: \(error)")
            }
        }
    }

    private func exportPostmanCollection() {
        guard let collection = appState.selectedCollection else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(collection.name).postman_collection.json"

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }

            do {
                let requests = try await appState.requestRepository.all(in: collection.id)
                let converter = PostmanCollectionConverter()
                let postmanCollection = converter.convert(collection: collection, requests: requests)
                try postmanCollection.exportToFile(url: url)
            } catch {
                print("Postman export failed: \(error)")
            }
        }
    }

    private func importCurl() {
        guard let collection = appState.selectedCollection else { return }

        let alert = NSAlert()
        alert.messageText = "Import cURL"
        alert.informativeText = "Paste your cURL command below:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        textView.isEditable = true
        alert.accessoryView = textView

        Task { @MainActor in
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let command = textView.string

            do {
                let converter = CurlConverter()
                var request = try converter.parse(command)
                request.collectionId = collection.id
                _ = try await appState.requestRepository.create(request)
                await appState.selectWorkspace(appState.selectedWorkspace!)
            } catch {
                print("cURL import failed: \(error)")
            }
        }
    }

    private func importOpenAPI() {
        guard let workspace = appState.selectedWorkspace else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import OpenAPI 3.0 Specification"

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }

            do {
                let importer = OpenAPIImporter()
                var (collection, requests, _) = try importer.importFromFile(url: url)
                collection.workspaceId = workspace.id
                let createdCollection = try await appState.collectionRepository.create(collection)
                for var request in requests {
                    request.collectionId = createdCollection.id
                    _ = try await appState.requestRepository.create(request)
                }
                await appState.selectWorkspace(workspace)
            } catch {
                print("OpenAPI import failed: \(error)")
            }
        }
    }

    private func importHAR() {
        guard let workspace = appState.selectedWorkspace else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import HAR File"

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }

            do {
                let converter = HARConverter()
                var (collection, requests) = try converter.importFromFile(url: url, workspaceId: workspace.id)
                collection.workspaceId = workspace.id
                let createdCollection = try await appState.collectionRepository.create(collection)
                for var request in requests {
                    request.collectionId = createdCollection.id
                    _ = try await appState.requestRepository.create(request)
                }
                await appState.selectWorkspace(workspace)
            } catch {
                print("HAR import failed: \(error)")
            }
        }
    }

    private func exportHAR() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "export.har"
        panel.title = "Export HAR"

        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }
            let converter = HARConverter()
            let data = converter.export(responses: [])
            try? data.write(to: url)
        }
    }
}
