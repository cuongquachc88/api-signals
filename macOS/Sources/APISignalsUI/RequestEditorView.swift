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
        VSplitView {
            // Top: request editor
            VStack(spacing: 0) {
                RequestURLBar(viewModel: viewModel)
                DSDivider()
                RequestTabBar(selectedTab: $selectedRequestTab, viewModel: viewModel)
                DSDivider()
                requestTabContent
            }
            .frame(minHeight: 260)
            .background(Color.dsSurf)

            // Bottom: response
            ResponseView(viewModel: viewModel)
                .frame(minHeight: 180)
                .background(Color.dsSurf)
        }
        .onChange(of: viewModel.editorFocusToken) { _, _ in
            if let raw = viewModel.editorFocusTabRaw,
               let tab = RequestTab(rawValue: raw) {
                selectedRequestTab = tab
            }
        }
    }

    @ViewBuilder
    private var requestTabContent: some View {
        Group {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - URL Bar

struct RequestURLBar: View {
    @ObservedObject var viewModel: RequestViewModel
    @State private var isCodeSheetPresented = false
    @State private var urlText: String = ""
    @State private var curlImportError: String?
    @FocusState private var isURLFocused: Bool

    private let barHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Method picker — same height as URL field
            Menu {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Button(method.rawValue) {
                        viewModel.request.method = method
                        viewModel.updateRequest()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(viewModel.request.method.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(viewModel.request.method.color)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(viewModel.request.method.color.opacity(0.7))
                }
                .frame(height: barHeight)
                .padding(.horizontal, DS.Spacing.sm)
                .background(viewModel.request.method.color.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(viewModel.request.method.color.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // URL field
            ZStack(alignment: .leading) {
                if urlText.isEmpty {
                    Text("Enter URL or paste cURL…")
                        .font(DS.Font.urlBar)
                        .foregroundStyle(Color.dsTextTertiary)
                        .allowsHitTesting(false)
                        .padding(.horizontal, DS.Spacing.md)
                }
                TextField("", text: $urlText, axis: .vertical)
                    .font(DS.Font.urlBar)
                    .foregroundStyle(Color.dsTextPrim)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isURLFocused)
                    .padding(.horizontal, DS.Spacing.md)
                    .onChange(of: urlText) { _, newValue in
                        handleURLTextChange(newValue)
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .background(Color.dsSurf)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(curlImportError == nil ? Color.dsBord : Color.dsError, lineWidth: 1)
            )
            .help(curlImportError ?? "Paste a URL or a full cURL command")

            // Code snippet button — same height
            Button {
                isCodeSheetPresented = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11))
                    Text("Code")
                        .font(DS.Font.label)
                }
                .foregroundStyle(Color.dsTextSec)
                .frame(height: barHeight)
                .padding(.horizontal, DS.Spacing.md)
                .background(Color.dsSurf)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(Color.dsBord, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isCodeSheetPresented) {
                CodeSnippetView(request: viewModel.request)
            }

            // Send / Cancel button — same height
            Button {
                if viewModel.isLoading { viewModel.cancelRequest() }
                else { viewModel.sendRequest() }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.7).tint(.white)
                        Text("Cancel")
                            .font(DS.Font.label)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                        Text("Send")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(height: barHeight)
                .padding(.horizontal, DS.Spacing.lg)
                .background(viewModel.isLoading ? Color.dsError : Color.dsAcc)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color.dsSurf)
        .onAppear {
            refreshURLTextFromModel(force: true)
        }
        .onChange(of: viewModel.request.url) { _, _ in
            refreshURLTextFromModel(force: false)
        }
        .onChange(of: viewModel.request.queryParams) { _, _ in
            refreshURLTextFromModel(force: false)
        }
    }

    private func refreshURLTextFromModel(force: Bool) {
        if RequestURLSync.migrateQueryOutOfURL(request: &viewModel.request) {
            viewModel.schedulePersist()
        }
        let next = RequestURLSync.displayString(
            url: viewModel.request.url,
            queryParams: viewModel.request.queryParams
        )
        if force || (!isURLFocused && urlText != next) {
            urlText = next
        }
    }

    private func handleURLTextChange(_ newValue: String) {
        curlImportError = nil
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if CurlConverter.looksLikeCurl(trimmed) {
            do {
                let parsed = try CurlConverter().parse(trimmed)
                viewModel.applyImportedRequest(parsed)
                urlText = RequestURLSync.displayString(
                    url: viewModel.request.url,
                    queryParams: viewModel.request.queryParams
                )
                isURLFocused = false
            } catch {
                curlImportError = "Could not parse cURL — check the command and try again"
                // Keep the pasted text visible so the user can edit/fix.
            }
            return
        }

        RequestURLSync.apply(fullURL: newValue, to: &viewModel.request)
        viewModel.schedulePersist()
    }
}

// MARK: - Tab Bar

struct RequestTabBar: View {
    @Binding var selectedTab: RequestTab
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RequestTab.allCases) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .background(Color.dsSurf)
    }

    @ViewBuilder
    private func tabButton(_ tab: RequestTab) -> some View {
        let isSelected = selectedTab == tab
        let badge = badgeCount(for: tab)

        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(tab.rawValue)
                    .font(isSelected ? DS.Font.label : DS.Font.body)
                    .foregroundStyle(isSelected ? Color.dsTextPrim : Color.dsTextSec)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if badge > 0 {
                    Text("\(badge)")
                        .font(DS.Font.captionMono)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.dsAcc)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(Color.dsAcc)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func badgeCount(for tab: RequestTab) -> Int {
        switch tab {
        case .params:
            return viewModel.request.queryParams.filter(\.isEnabled).count
        case .headers:
            return viewModel.request.headers.filter(\.isEnabled).count
        case .auth:
            return viewModel.request.auth != .none ? 1 : 0
        case .body:
            return viewModel.request.body != .none ? 1 : 0
        default:
            return 0
        }
    }
}

// MARK: - Request Tab enum

enum RequestTab: String, CaseIterable, Identifiable {
    case params = "Params"
    case headers = "Headers"
    case auth = "Auth"
    case body = "Body"
    case scripts = "Scripts"
    case settings = "Settings"

    var id: String { rawValue }
}

// MARK: - Request Settings Editor

struct RequestSettingsEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                settingsSection("Network") {
                    settingsToggle("Follow Redirects",
                                   icon: "arrow.triangle.branch",
                                   value: Binding(
                        get: { viewModel.request.settings.followRedirects },
                        set: { viewModel.request.settings.followRedirects = $0; viewModel.updateRequest() }
                    ))
                    DSDivider()
                    settingsToggle("Verify SSL Certificates",
                                   icon: "lock.shield",
                                   value: Binding(
                        get: { viewModel.request.settings.verifySSL },
                        set: { viewModel.request.settings.verifySSL = $0; viewModel.updateRequest() }
                    ))
                    DSDivider()
                    settingsToggle("Accept Compression",
                                   icon: "doc.zipper",
                                   value: Binding(
                        get: { viewModel.request.settings.acceptCompression },
                        set: { viewModel.request.settings.acceptCompression = $0; viewModel.updateRequest() }
                    ))
                    DSDivider()
                    HStack {
                        Label("Timeout", systemImage: "clock")
                            .font(DS.Font.body)
                            .foregroundStyle(Color.dsTextPrim)
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
                        .font(DS.Font.body)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }

                settingsSection("Cookies") {
                    settingsToggle("Send Cookies",
                                   icon: "tray.and.arrow.up",
                                   value: Binding(
                        get: { viewModel.request.settings.sendCookies },
                        set: { viewModel.request.settings.sendCookies = $0; viewModel.updateRequest() }
                    ))
                    DSDivider()
                    settingsToggle("Store Cookies",
                                   icon: "tray.and.arrow.down",
                                   value: Binding(
                        get: { viewModel.request.settings.storeCookies },
                        set: { viewModel.request.settings.storeCookies = $0; viewModel.updateRequest() }
                    ))
                }

                settingsSection("Proxy") {
                    settingsToggle("Use Custom Proxy",
                                   icon: "network.badge.shield.half.filled",
                                   value: Binding(
                        get: { viewModel.request.settings.proxy?.isEnabled ?? false },
                        set: { enabled in
                            if viewModel.request.settings.proxy == nil {
                                viewModel.request.settings.proxy = ProxyConfig()
                            }
                            viewModel.request.settings.proxy?.isEnabled = enabled
                            viewModel.updateRequest()
                        }
                    ))

                    if viewModel.request.settings.proxy?.isEnabled == true {
                        DSDivider()
                        HStack(spacing: DS.Spacing.sm) {
                            Label("Host", systemImage: "server.rack")
                                .font(DS.Font.body)
                                .foregroundStyle(Color.dsTextPrim)
                                .frame(width: 80, alignment: .leading)
                            TextField("proxy.example.com", text: Binding(
                                get: { viewModel.request.settings.proxy?.host ?? "" },
                                set: { viewModel.request.settings.proxy?.host = $0; viewModel.updateRequest() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(DS.Font.bodyMono)
                            Text(":")
                                .foregroundStyle(Color.dsTextSec)
                            TextField("8080", value: Binding(
                                get: { viewModel.request.settings.proxy?.port ?? 8080 },
                                set: { viewModel.request.settings.proxy?.port = $0; viewModel.updateRequest() }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(DS.Font.bodyMono)
                            .frame(width: 70)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)

                        DSDivider()
                        HStack(spacing: DS.Spacing.sm) {
                            Label("Auth", systemImage: "key")
                                .font(DS.Font.body)
                                .foregroundStyle(Color.dsTextPrim)
                                .frame(width: 80, alignment: .leading)
                            TextField("Username", text: Binding(
                                get: { viewModel.request.settings.proxy?.username ?? "" },
                                set: { viewModel.request.settings.proxy?.username = $0.isEmpty ? nil : $0; viewModel.updateRequest() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(DS.Font.bodyMono)
                            SecureField("Password", text: Binding(
                                get: { viewModel.request.settings.proxy?.password ?? "" },
                                set: { viewModel.request.settings.proxy?.password = $0.isEmpty ? nil : $0; viewModel.updateRequest() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(DS.Font.bodyMono)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(Color.dsBg)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionHeader(title: title)
                .padding(.bottom, DS.Spacing.xs)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.dsSurf)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.dsBord, lineWidth: 1)
            )
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    private func settingsToggle(_ title: String, icon: String, value: Binding<Bool>) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextPrim)
            Spacer()
            Toggle("", isOn: value)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Code Snippet View (redesigned)

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
                Text("Code Snippet")
                    .font(DS.Font.title)
                    .foregroundStyle(Color.dsTextPrim)
                Spacer()
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(0..<languages.count, id: \.self) { i in
                        Text(languages[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                        .font(DS.Font.label)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(DS.Spacing.lg)

            DSDivider()

            ScrollView {
                Text(snippet)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextPrim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.lg)
            }
            .background(Color.dsSurf)
        }
        .background(Color.dsBg)
        .frame(minWidth: 560, minHeight: 360)
    }
}

// MARK: - Scripts Editor (redesigned)

struct ScriptsEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 0) {
            scriptSection(
                title: "Pre-request Script",
                subtitle: "Runs before the request is sent",
                icon: "bolt.circle",
                text: Binding(
                    get: { viewModel.request.preRequestScript ?? "" },
                    set: { viewModel.request.preRequestScript = $0.isEmpty ? nil : $0; viewModel.updateRequest() }
                )
            )

            DSDivider()

            scriptSection(
                title: "Post-response Script",
                subtitle: "Runs after the response is received",
                icon: "checkmark.circle",
                text: Binding(
                    get: { viewModel.request.postResponseScript ?? "" },
                    set: { viewModel.request.postResponseScript = $0.isEmpty ? nil : $0; viewModel.updateRequest() }
                )
            )
        }
        .background(Color.dsBg)
    }

    @ViewBuilder
    private func scriptSection(title: String, subtitle: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsAcc)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DS.Font.label)
                        .foregroundStyle(Color.dsTextPrim)
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextSec)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            TextEditor(text: text)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
                .scrollContentBackground(.hidden)
                .background(Color.dsSurf)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.dsBord, lineWidth: 0)
                )
        }
    }
}
