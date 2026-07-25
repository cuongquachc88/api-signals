import SwiftUI
import APISignalsCore

public struct RequestEditorView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: RequestViewModel
    @State private var selectedRequestTab: RequestTab = .params

    public init(appState: AppState, request: APIRequest) {
        self.appState = appState
        let collection = appState.collections.first { $0.id == request.collectionId }
        _viewModel = StateObject(wrappedValue: RequestViewModel(
            request: request,
            networkEngine: appState.networkEngine,
            environment: appState.activeEnvironment,
            collection: collection,
            workspaceId: appState.selectedWorkspace?.id ?? UUID(),
            onRequestUpdated: { updatedRequest in
                await appState.updateRequest(updatedRequest)
            },
            onHistoryEntry: { entry in
                await appState.addHistoryEntry(entry)
            },
            onEnvironmentUpdated: { updatedEnvironment in
                do {
                    _ = try await appState.environmentRepository.update(updatedEnvironment)
                } catch {
                    print("Failed to update environment: \(error)")
                }
                await appState.selectWorkspace(appState.selectedWorkspace!)
            }
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            RequestBarView(viewModel: viewModel)
                .padding()

            Picker("", selection: $selectedRequestTab) {
                ForEach(RequestTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch selectedRequestTab {
            case .params:
                ParamsEditorView(viewModel: viewModel)
            case .headers:
                HeadersEditorView(viewModel: viewModel)
            case .auth:
                AuthEditorView(viewModel: viewModel)
            case .body:
                BodyEditorView(viewModel: viewModel)
            case .scripts:
                ScriptsEditorView(viewModel: viewModel)
            case .settings:
                RequestSettingsEditorView(viewModel: viewModel)
            }

            Divider()

            ResponseView(viewModel: viewModel)
                .frame(minHeight: 200)
        }
    }
}

enum RequestTab: String, CaseIterable, Identifiable {
    case params = "Params"
    case headers = "Headers"
    case auth = "Auth"
    case body = "Body"
    case scripts = "Scripts"
    case settings = "Settings"

    var id: String { rawValue }
}

struct RequestSettingsEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Form {
                    Section("Network") {
                        Toggle("Follow Redirects", isOn: Binding(
                            get: { viewModel.request.settings.followRedirects },
                            set: { viewModel.request.settings.followRedirects = $0; viewModel.updateRequest() }
                        ))

                        Toggle("Verify SSL Certificates", isOn: Binding(
                            get: { viewModel.request.settings.verifySSL },
                            set: { viewModel.request.settings.verifySSL = $0; viewModel.updateRequest() }
                        ))

                        Toggle("Accept Compression (gzip, br)", isOn: Binding(
                            get: { viewModel.request.settings.acceptCompression },
                            set: { viewModel.request.settings.acceptCompression = $0; viewModel.updateRequest() }
                        ))

                        HStack {
                            Text("Timeout")
                            Spacer()
                            Stepper(
                                "\(Int(viewModel.request.settings.timeout))s",
                                value: Binding(
                                    get: { viewModel.request.settings.timeout },
                                    set: { viewModel.request.settings.timeout = $0; viewModel.updateRequest() }
                                ),
                                in: 1...600,
                                step: 5
                            )
                            .frame(width: 140)
                        }
                    }

                    Section("Cookies") {
                        Toggle("Send Cookies", isOn: Binding(
                            get: { viewModel.request.settings.sendCookies },
                            set: { viewModel.request.settings.sendCookies = $0; viewModel.updateRequest() }
                        ))

                        Toggle("Store Cookies", isOn: Binding(
                            get: { viewModel.request.settings.storeCookies },
                            set: { viewModel.request.settings.storeCookies = $0; viewModel.updateRequest() }
                        ))
                    }

                    Section("Proxy") {
                        let proxyEnabled = Binding(
                            get: { viewModel.request.settings.proxy?.isEnabled ?? false },
                            set: { enabled in
                                if viewModel.request.settings.proxy == nil {
                                    viewModel.request.settings.proxy = ProxyConfig()
                                }
                                viewModel.request.settings.proxy?.isEnabled = enabled
                                viewModel.updateRequest()
                            }
                        )
                        Toggle("Use Custom Proxy", isOn: proxyEnabled)

                        if viewModel.request.settings.proxy?.isEnabled == true {
                            HStack {
                                TextField("Host", text: Binding(
                                    get: { viewModel.request.settings.proxy?.host ?? "" },
                                    set: { viewModel.request.settings.proxy?.host = $0; viewModel.updateRequest() }
                                ))
                                .textFieldStyle(.roundedBorder)

                                Text(":")
                                    .foregroundStyle(.secondary)

                                TextField("Port", value: Binding(
                                    get: { viewModel.request.settings.proxy?.port ?? 8080 },
                                    set: { viewModel.request.settings.proxy?.port = $0; viewModel.updateRequest() }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            }

                            HStack {
                                TextField("Username (optional)", text: Binding(
                                    get: { viewModel.request.settings.proxy?.username ?? "" },
                                    set: { viewModel.request.settings.proxy?.username = $0.isEmpty ? nil : $0; viewModel.updateRequest() }
                                ))
                                .textFieldStyle(.roundedBorder)

                                SecureField("Password (optional)", text: Binding(
                                    get: { viewModel.request.settings.proxy?.password ?? "" },
                                    set: { viewModel.request.settings.proxy?.password = $0.isEmpty ? nil : $0; viewModel.updateRequest() }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
    }
}

struct RequestBarView: View {
    @ObservedObject var viewModel: RequestViewModel
    @State private var isCodeSheetPresented = false

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewModel.request.method) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: viewModel.request.method) { _, _ in
                viewModel.updateRequest()
            }

            TextField("URL or paste cURL...", text: Binding(
                get: { viewModel.request.url.url?.absoluteString ?? "" },
                set: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("curl ") {
                        // Auto-parse cURL command
                        if let parsed = try? CurlConverter().parse(trimmed) {
                            viewModel.request.method = parsed.method
                            viewModel.request.url = parsed.url
                            viewModel.request.headers = parsed.headers
                            viewModel.request.queryParams = parsed.queryParams
                            viewModel.request.body = parsed.body
                            viewModel.updateRequest()
                        }
                    } else {
                        viewModel.request.url = URLComponents(string: newValue) ?? URLComponents()
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)

            Button(viewModel.isLoading ? "Cancel" : "Send") {
                if viewModel.isLoading {
                    viewModel.cancelRequest()
                } else {
                    viewModel.sendRequest()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 80)
            .keyboardShortcut(.return, modifiers: .command)

            Button("Code") {
                isCodeSheetPresented = true
            }
            .buttonStyle(.borderless)
            .help("Generate code snippets")
            .sheet(isPresented: $isCodeSheetPresented) {
                CodeSnippetView(request: viewModel.request)
            }
        }
    }
}

struct CodeSnippetView: View {
    let request: APIRequest
    @State private var selectedLanguage = 0
    @SwiftUI.Environment(\.dismiss) private var dismiss

    private let languages = ["cURL", "Python", "JavaScript", "Swift"]

    private var snippet: String {
        let generator = CodeSnippetGenerator()
        switch selectedLanguage {
        case 0: return generator.curlCommand(from: request)
        case 1: return generator.pythonRequest(from: request)
        case 2: return generator.javaScriptFetch(from: request)
        case 3: return generator.swiftUrlSession(from: request)
        default: return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(0..<languages.count, id: \.self) { index in
                        Text(languages[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Spacer()

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet, forType: .string)
                }

                Button("Close") {
                    dismiss()
                }
            }
            .padding()

            ScrollView {
                Text(snippet)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
}

struct ScriptsEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Pre-request Script")
                    .font(.headline)
                CodeEditor(text: Binding(
                    get: { viewModel.request.preRequestScript ?? "" },
                    set: { viewModel.request.preRequestScript = $0; viewModel.updateRequest() }
                ))
            }

            VStack(alignment: .leading) {
                Text("Post-response Script")
                    .font(.headline)
                CodeEditor(text: Binding(
                    get: { viewModel.request.postResponseScript ?? "" },
                    set: { viewModel.request.postResponseScript = $0; viewModel.updateRequest() }
                ))
            }
        }
        .padding()
    }
}
