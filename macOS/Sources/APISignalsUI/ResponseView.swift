import SwiftUI
import AppKit
import PDFKit
import APISignalsCore
import APISignalsScripting

struct ResponseView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let response = viewModel.response {
                    StatusBadge(statusCode: response.statusCode)
                    Text("\(formatTime(response.timing.total))")
                    Text("\(formatSize(response.size.total))")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }

                Spacer()

                Picker("", selection: $viewModel.selectedResponseTab) {
                    ForEach(RequestViewModel.ResponseTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            .padding()

            if let response = viewModel.response {
                switch viewModel.selectedResponseTab {
                case .body:
                    ResponseBodyView(response: response)
                case .headers:
                    HeadersListView(headers: response.headers)
                case .cookies:
                    CookiesListView(cookies: response.cookies)
                case .tests:
                    TestsListView(tests: viewModel.scriptTests, errors: viewModel.scriptErrors)
                }
            } else if !viewModel.isLoading {
                Spacer()
                Text("Click Send to get a response")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        String(format: "%.0f ms", interval * 1000)
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.2f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

struct StatusBadge: View {
    let statusCode: Int

    var body: some View {
        Text("\(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch statusCode {
        case 200..<300: return .green
        case 300..<400: return .orange
        case 400..<600: return .red
        default: return .gray
        }
    }
}

struct ResponseBodyView: View {
    let response: APIResponse
    @State private var viewMode: ResponseViewMode = .auto

    enum ResponseViewMode: String, CaseIterable {
        case auto = "Auto"
        case raw = "Raw"
        case preview = "Preview"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $viewMode) {
                    ForEach(ResponseViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                if let data = response.body {
                    Button("Copy") {
                        if let text = String(data: data, encoding: .utf8) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            bodyContent
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let data = response.body {
            let mime = response.mimeType ?? ""
            switch viewMode {
            case .preview:
                if mime.hasPrefix("image/") {
                    ImagePreviewView(data: data)
                } else if mime == "application/pdf" {
                    PDFPreviewView(data: data)
                } else {
                    textBody(data: data, mime: mime)
                }
            case .raw:
                ScrollView {
                    Text(String(data: data, encoding: .utf8) ?? data.base64EncodedString())
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            case .auto:
                if mime.hasPrefix("image/") {
                    ImagePreviewView(data: data)
                } else if mime == "application/pdf" {
                    PDFPreviewView(data: data)
                } else {
                    textBody(data: data, mime: mime)
                }
            }
        } else {
            Text("(empty body)").foregroundStyle(.secondary).padding()
        }
    }

    @ViewBuilder
    private func textBody(data: Data, mime: String) -> some View {
        let text: String = {
            if mime.contains("json"),
               let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: prettyData, encoding: .utf8) {
                return s
            }
            return String(data: data, encoding: .utf8) ?? "(binary data: \(data.count) bytes)"
        }()

        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
    }
}

struct ImagePreviewView: View {
    let data: Data

    var body: some View {
        if let nsImage = NSImage(data: data) {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        } else {
            Text("Cannot display image")
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

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

struct HeadersListView: View {
    let headers: [Header]

    var body: some View {
        List(headers) { header in
            HStack {
                Text(header.key)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 200, alignment: .leading)
                Text(header.value)
                    .font(.system(.body, design: .monospaced))
                Spacer()
            }
        }
    }
}

struct CookiesListView: View {
    let cookies: [Cookie]

    var body: some View {
        if cookies.isEmpty {
            VStack {
                Spacer()
                Text("No cookies")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List(cookies) { cookie in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(cookie.name)
                            .fontWeight(.medium)
                            .frame(width: 160, alignment: .leading)
                        Text(cookie.value)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        if let domain = cookie.domain {
                            Label(domain, systemImage: "globe")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let path = cookie.path {
                            Label(path, systemImage: "folder")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if cookie.isSecure {
                            Label("Secure", systemImage: "lock")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        if cookie.isHttpOnly {
                            Label("HttpOnly", systemImage: "eye.slash")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if let expires = cookie.expires {
                            Label(expires.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct TestsListView: View {
    let tests: [ScriptTest]
    let errors: [String]

    var body: some View {
        VStack {
            if tests.isEmpty && errors.isEmpty {
                Text("No tests run")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    Section("Tests") {
                        ForEach(tests) { test in
                            HStack {
                                Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(test.passed ? .green : .red)
                                Text(test.name)
                                Spacer()
                                if let message = test.message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !errors.isEmpty {
                        Section("Errors") {
                            ForEach(errors, id: \.self) { error in
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}
