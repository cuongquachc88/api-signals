import SwiftUI
import APISignalsCore

struct BodyEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: Binding(
                get: { viewModel.selectedBodyTab },
                set: { viewModel.setBodyTab($0) }
            )) {
                ForEach(RequestViewModel.BodyTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            bodyContent
                .padding()
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch viewModel.request.body {
        case .none:
            Text("No body")
                .foregroundStyle(.secondary)
        case .raw(let text, let mimeType):
            VStack(alignment: .leading) {
                TextField("MIME Type (e.g. text/plain)", text: Binding(
                    get: { mimeType },
                    set: { viewModel.request.body = .raw(text: text, mimeType: $0); viewModel.updateRequest() }
                ))
                .textFieldStyle(.roundedBorder)
                CodeEditor(text: Binding(
                    get: { text },
                    set: { viewModel.request.body = .raw(text: $0, mimeType: mimeType); viewModel.updateRequest() }
                ))
            }
        case .json(let text):
            CodeEditor(text: Binding(
                get: { text },
                set: { viewModel.request.body = .json($0); viewModel.updateRequest() }
            ))
        case .formData(let fields):
            FormDataEditor(fields: Binding(
                get: { fields },
                set: { viewModel.request.body = .formData($0); viewModel.updateRequest() }
            ))
        case .urlEncoded(let params):
            KeyValueEditor(
                items: Binding(
                    get: { params },
                    set: { viewModel.request.body = .urlEncoded($0); viewModel.updateRequest() }
                ),
                keyPlaceholder: "Key",
                valuePlaceholder: "Value"
            )
        case .graphql(let query, let variables):
            VStack(alignment: .leading) {
                Text("Query")
                    .font(.caption)
                CodeEditor(text: Binding(
                    get: { query },
                    set: { viewModel.request.body = .graphql(query: $0, variables: variables); viewModel.updateRequest() }
                ))
                Text("Variables")
                    .font(.caption)
                CodeEditor(text: Binding(
                    get: { variables },
                    set: { viewModel.request.body = .graphql(query: query, variables: $0); viewModel.updateRequest() }
                ))
            }
        case .binary(let data):
            Text("Binary data: \(data.count) bytes")
                .foregroundStyle(.secondary)
        }
    }
}

struct FormDataEditor: View {
    @Binding var fields: [FormField]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Import CSV") { importCSV() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button("Export CSV") { exportCSV() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            List {
                ForEach($fields) { $field in
                    HStack(spacing: 8) {
                        Toggle("", isOn: $field.isEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                        TextField("Key", text: $field.key)
                            .textFieldStyle(.roundedBorder)

                        TextField("Value", text: $field.value)
                            .textFieldStyle(.roundedBorder)

                        Picker("", selection: $field.type) {
                            Text("Text").tag(FormField.FieldType.text)
                            Text("File").tag(FormField.FieldType.file)
                        }
                        .frame(width: 80)

                        Button("Remove") {
                            fields.removeAll { $0.id == field.id }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button("Add Field") {
                    fields.append(FormField(key: "", value: ""))
                }
            }
        }
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url,
                  let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            let newFields = content.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { line -> FormField in
                    let parts = line.components(separatedBy: ",")
                    let key = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
                    let value = (parts.count > 1 ? parts[1...].joined(separator: ",") : "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    return FormField(key: key, value: value)
                }
            fields.append(contentsOf: newFields)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "form-data.csv"
        Task { @MainActor in
            guard await panel.begin() == .OK, let url = panel.url else { return }
            let csv = fields.map { "\"\($0.key)\",\"\($0.value)\"" }.joined(separator: "\n")
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct CodeEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .lineSpacing(4)
            .frame(minHeight: 100)
    }
}
