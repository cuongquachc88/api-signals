import SwiftUI
import AppKit
import PDFKit
import APISignalsCore
import APISignalsScripting

// MARK: - Response View

struct ResponseView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 0) {
            responseHeader
            DSDivider()

            if let response = viewModel.response {
                switch viewModel.selectedResponseTab {
                case .body:
                    ResponseBodyView(response: response)
                case .headers:
                    ResponseHeadersView(headers: response.headers)
                case .cookies:
                    ResponseCookiesView(cookies: response.cookies)
                case .tests:
                    TestsListView(tests: viewModel.scriptTests, errors: viewModel.scriptErrors)
                }
            } else if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                placeholderView
            }
        }
        .background(Color.dsSurf)
    }

    // MARK: Header

    private var responseHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Status + metrics
            if let response = viewModel.response {
                StatusBadgeDS(code: response.statusCode)

                DSDivider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)

                timingBadge(label: "Time", value: formatTime(response.timing.total), icon: "clock")
                sizeBadge(label: "Size", value: formatSize(response.size.total))
            } else if let error = viewModel.errorMessage {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.dsError)
                        .font(.system(size: 12))
                    Text(error)
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsError)
                        .lineLimit(1)
                }
            } else {
                Text("Response")
                    .font(DS.Font.label)
                    .foregroundStyle(Color.dsTextSec)
            }

            Spacer()

            // Tab picker (underline style)
            if viewModel.response != nil {
                HStack(spacing: 0) {
                    ForEach(RequestViewModel.ResponseTab.allCases, id: \.self) { tab in
                        responseTabButton(tab)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .frame(height: 42)
        .background(Color.dsSurf)
    }

    @ViewBuilder
    private func responseTabButton(_ tab: RequestViewModel.ResponseTab) -> some View {
        let isSelected = viewModel.selectedResponseTab == tab
        Button {
            viewModel.selectedResponseTab = tab
        } label: {
            Text(tab.rawValue)
                .font(isSelected ? DS.Font.label : DS.Font.body)
                .foregroundStyle(isSelected ? Color.dsTextPrim : Color.dsTextSec)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(Color.dsAcc)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func timingBadge(label: String, value: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.dsTextTertiary)
            Text(value)
                .font(DS.Font.captionMono)
                .foregroundStyle(Color.dsTextSec)
        }
    }

    private func sizeBadge(label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 10))
                .foregroundStyle(Color.dsTextTertiary)
            Text(value)
                .font(DS.Font.captionMono)
                .foregroundStyle(Color.dsTextSec)
        }
    }

    // MARK: Loading

    private var loadingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.dsAcc)
            Text("Sending request…")
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
            Button("Cancel") { viewModel.cancelRequest() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
        }
    }

    // MARK: Error

    private func errorView(message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(Color.dsError.opacity(0.7))
            Text("Request Failed")
                .font(DS.Font.title)
                .foregroundStyle(Color.dsTextPrim)
            Text(message)
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Placeholder

    private var placeholderView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Spacer()
            Image(systemName: "arrow.up.circle.dotted")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.dsTextTertiary)
            Text("Send a request to see the response")
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
            Text("⌘ Return to send")
                .font(DS.Font.captionMono)
                .foregroundStyle(Color.dsTextTertiary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(Color.dsBord.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let ms = interval * 1000
        if ms < 1000 { return String(format: "%.0f ms", ms) }
        return String(format: "%.2f s", interval)
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.2f KB", Double(bytes) / 1024) }
        return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - Response Body View

struct ResponseBodyView: View {
    let response: APIResponse
    @State private var viewMode: ResponseViewMode = .auto
    @State private var copied = false

    enum ResponseViewMode: String, CaseIterable {
        case auto = "Pretty"
        case raw = "Raw"
        case preview = "Preview"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Body toolbar
            HStack(spacing: DS.Spacing.sm) {
                Picker("", selection: $viewMode) {
                    ForEach(ResponseViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .controlSize(.small)

                if let data = response.body {
                    Text(mimeLabel)
                        .font(DS.Font.captionMono)
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.dsBord.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))

                    Spacer()

                    Button {
                        if let text = String(data: data, encoding: .utf8) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.clipboard")
                            .font(DS.Font.caption)
                            .foregroundStyle(copied ? Color.dsGET : Color.dsTextSec)
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveToDisk(data: data)
                    } label: {
                        Label("Save", systemImage: "arrow.down.to.line")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextSec)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            bodyContent
        }
    }

    private var mimeLabel: String {
        response.mimeType ?? "text/plain"
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let data = response.body {
            let mime = response.mimeType ?? ""
            switch viewMode {
            case .preview:
                previewContent(data: data, mime: mime)
            case .raw:
                rawContent(data: data)
            case .auto:
                if mime.hasPrefix("image/") {
                    ImagePreviewView(data: data)
                } else if mime == "application/pdf" {
                    PDFPreviewView(data: data)
                } else {
                    prettyContent(data: data, mime: mime)
                }
            }
        } else {
            HStack {
                Image(systemName: "tray")
                    .foregroundStyle(Color.dsTextTertiary)
                Text("Empty response body")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func previewContent(data: Data, mime: String) -> some View {
        if mime.hasPrefix("image/") {
            ImagePreviewView(data: data)
        } else if mime == "application/pdf" {
            PDFPreviewView(data: data)
        } else {
            prettyContent(data: data, mime: mime)
        }
    }

    private func rawContent(data: Data) -> some View {
        ScrollView {
            Text(String(data: data, encoding: .utf8) ?? data.base64EncodedString())
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
                .textSelection(.enabled)
        }
        .background(Color.dsBg)
    }

    private func prettyContent(data: Data, mime: String) -> some View {
        let text: String = {
            if mime.contains("json"),
               let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: prettyData, encoding: .utf8) {
                return s
            }
            return String(data: data, encoding: .utf8) ?? "(binary: \(data.count) bytes)"
        }()

        return ScrollView {
            Text(text)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
                .textSelection(.enabled)
        }
        .background(Color.dsBg)
    }

    private func saveToDisk(data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "response"
        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }
}

// MARK: - Response Headers View

struct ResponseHeadersView: View {
    let headers: [Header]
    @State private var searchText = ""

    private var filtered: [Header] {
        if searchText.isEmpty { return headers }
        let q = searchText.lowercased()
        return headers.filter { $0.key.lowercased().contains(q) || $0.value.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextTertiary)
                TextField("Filter headers…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                Spacer()
                Text("\(headers.count) header\(headers.count == 1 ? "" : "s")")
                    .font(DS.Font.caption)
                    .foregroundStyle(Color.dsTextTertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            List(filtered) { header in
                HStack(spacing: 0) {
                    Text(header.key)
                        .font(DS.Font.bodyMono)
                        .foregroundStyle(Color.dsAcc)
                        .frame(minWidth: 180, alignment: .leading)
                        .padding(.trailing, DS.Spacing.md)
                    Text(header.value)
                        .font(DS.Font.bodyMono)
                        .foregroundStyle(Color.dsTextPrim)
                        .textSelection(.enabled)
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .listStyle(.plain)
            .background(Color.dsBg)
        }
    }
}

// MARK: - Response Cookies View

struct ResponseCookiesView: View {
    let cookies: [Cookie]

    var body: some View {
        if cookies.isEmpty {
            VStack(spacing: DS.Spacing.sm) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.dsTextTertiary)
                Text("No cookies in response")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(cookies) { cookie in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(cookie.name)
                            .font(DS.Font.label)
                            .foregroundStyle(Color.dsTextPrim)
                        Text("=")
                            .foregroundStyle(Color.dsTextTertiary)
                        Text(cookie.value)
                            .font(DS.Font.bodyMono)
                            .foregroundStyle(Color.dsTextSec)
                            .lineLimit(1)
                        Spacer()
                    }
                    HStack(spacing: DS.Spacing.sm) {
                        if let domain = cookie.domain {
                            cookieTag(domain, icon: "globe")
                        }
                        if let path = cookie.path {
                            cookieTag(path, icon: "folder")
                        }
                        if cookie.isSecure {
                            cookieTag("Secure", icon: "lock", color: Color.dsGET)
                        }
                        if cookie.isHttpOnly {
                            cookieTag("HttpOnly", icon: "eye.slash", color: Color.dsWarning)
                        }
                        if let expires = cookie.expires {
                            cookieTag(expires.formatted(date: .abbreviated, time: .shortened), icon: "clock")
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .listStyle(.plain)
        }
    }

    private var dsWarning: Color { Color(hex: "#D29922") }

    @ViewBuilder
    private func cookieTag(_ label: String, icon: String, color: Color = Color.dsTextTertiary) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(DS.Font.caption)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
    let data: Data

    var body: some View {
        if let nsImage = NSImage(data: data) {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding(DS.Spacing.lg)
            }
            .background(Color.dsBg)
        } else {
            VStack {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.dsTextTertiary)
                Text("Cannot display image")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            nsView.document = document
        }
    }
}

// MARK: - Tests List View

struct TestsListView: View {
    let tests: [ScriptTest]
    let errors: [String]

    private var passed: Int { tests.filter(\.passed).count }
    private var failed: Int { tests.filter { !$0.passed }.count }

    var body: some View {
        VStack(spacing: 0) {
            if !tests.isEmpty {
                HStack(spacing: DS.Spacing.md) {
                    Spacer()
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.dsGET)
                        Text("\(passed) passed")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextSec)
                    }
                    if failed > 0 {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.dsError)
                            Text("\(failed) failed")
                                .font(DS.Font.caption)
                                .foregroundStyle(Color.dsError)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(Color.dsSurf)

                DSDivider()
            }

            if tests.isEmpty && errors.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Spacer()
                    Image(systemName: "testtube.2")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("No tests run")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    if !tests.isEmpty {
                        Section("Tests") {
                            ForEach(tests) { test in
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(test.passed ? Color.dsGET : Color.dsError)
                                        .font(.system(size: 14))
                                    Text(test.name)
                                        .font(DS.Font.body)
                                        .foregroundStyle(Color.dsTextPrim)
                                    Spacer()
                                    if let message = test.message {
                                        Text(message)
                                            .font(DS.Font.caption)
                                            .foregroundStyle(Color.dsTextSec)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if !errors.isEmpty {
                        Section("Script Errors") {
                            ForEach(errors, id: \.self) { error in
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.dsWarning)
                                    Text(error)
                                        .font(DS.Font.bodyMono)
                                        .foregroundStyle(Color.dsError)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.dsBg)
    }

    private var dsWarning: Color { Color(hex: "#D29922") }
}
