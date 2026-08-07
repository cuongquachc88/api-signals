import SwiftUI
import APISignalsCore

struct BodyEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Type picker header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsTextSec)
                Spacer()
                Picker("", selection: Binding(
                    get: { viewModel.selectedBodyTab },
                    set: { viewModel.setBodyTab($0) }
                )) {
                    ForEach(RequestViewModel.BodyTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)
                .controlSize(.small)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBg)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch viewModel.request.body {
        case .none:
            noneView

        case .raw(let text, let mimeType):
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("MIME Type")
                        .font(DS.Font.label)
                        .foregroundStyle(Color.dsTextSec)
                    TextField("text/plain", text: Binding(
                        get: { mimeType },
                        set: { viewModel.request.body = .raw(text: text, mimeType: $0); viewModel.updateRequest() }
                    ))
                    .textFieldStyle(.plain)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextPrim)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(Color.dsSurf)

                DSDivider()

                CodeEditorDS(text: Binding(
                    get: { text },
                    set: { viewModel.request.body = .raw(text: $0, mimeType: mimeType); viewModel.updateRequest() }
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .json:
            JSONEditorView(
                text: Binding(
                    get: {
                        if case .json(let text) = viewModel.request.body { return text }
                        return ""
                    },
                    set: { viewModel.request.body = .json($0) }
                ),
                onChange: { viewModel.schedulePersist() },
                placeholder: "{\n  \"key\": \"value\"\n}"
            )

        case .formData(let fields):
            FormDataEditorDS(fields: Binding(
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
                valuePlaceholder: "Value",
                emptyMessage: "No form fields"
            )

        case .graphql(let query, let variables):
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Query")
                        .font(DS.Font.labelSm)
                        .foregroundStyle(Color.dsTextSec)
                        .tracking(0.3)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xs)
                .background(Color.dsSurf)

                DSDivider()

                CodeEditorDS(text: Binding(
                    get: { query },
                    set: { viewModel.request.body = .graphql(query: $0, variables: variables); viewModel.schedulePersist() }
                ), hint: "query { }")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .binary(let data):
            VStack(spacing: DS.Spacing.sm) {
                Spacer()
                Image(systemName: "doc.zipper")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.dsTextTertiary)
                Text("Binary Data")
                    .font(DS.Font.title)
                    .foregroundStyle(Color.dsTextPrim)
                Text("\(data.count) bytes")
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextSec)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var noneView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Spacer()
            Image(systemName: "doc")
                .font(.system(size: 28))
                .foregroundStyle(Color.dsTextTertiary)
            Text("No Body")
                .font(DS.Font.title)
                .foregroundStyle(Color.dsTextPrim)
            Text("Select a body type above")
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Code Editor (redesigned)

struct CodeEditorDS: View {
    @Binding var text: String
    var hint: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !hint.isEmpty {
                Text(hint)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(DS.Spacing.md)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBg)
    }
}

// Backward compat alias
typealias CodeEditor = CodeEditorDS

// MARK: - Form Data Editor (redesigned)

struct FormDataEditorDS: View {
    @Binding var fields: [FormField]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: DS.Spacing.sm) {
                Text("\(fields.filter(\.isEnabled).count) active fields")
                    .font(DS.Font.caption)
                    .foregroundStyle(Color.dsTextTertiary)
                Spacer()
                Button { importCSV() } label: {
                    Label("Import CSV", systemImage: "arrow.down.doc")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextSec)
                }
                .buttonStyle(.plain)

                Button { exportCSV() } label: {
                    Label("Export CSV", systemImage: "arrow.up.doc")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextSec)
                }
                .buttonStyle(.plain)
                .disabled(fields.isEmpty)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            if fields.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Spacer()
                    Image(systemName: "tablecells")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("No form fields")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                    Button {
                        fields.append(FormField(key: "", value: ""))
                    } label: {
                        Label("Add Field", systemImage: "plus.circle")
                            .foregroundStyle(Color.dsAcc)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.dsBg)
            } else {
                List {
                    ForEach($fields) { $field in
                        HStack(spacing: DS.Spacing.sm) {
                            Toggle("", isOn: $field.isEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                            TextField("Key", text: $field.key)
                                .textFieldStyle(.plain)
                                .font(DS.Font.bodyMono)
                                .foregroundStyle(Color.dsTextPrim)
                                .frame(maxWidth: .infinity)

                            TextField("Value", text: $field.value)
                                .textFieldStyle(.plain)
                                .font(DS.Font.bodyMono)
                                .foregroundStyle(Color.dsAcc)
                                .frame(maxWidth: .infinity)

                            Picker("", selection: $field.type) {
                                Image(systemName: "text.alignleft").tag(FormField.FieldType.text)
                                Image(systemName: "doc.fill").tag(FormField.FieldType.file)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 60)
                            .controlSize(.small)

                            Button {
                                fields.removeAll { $0.id == field.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.dsError)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                        .opacity(field.isEnabled ? 1 : 0.5)
                    }

                    Button {
                        fields.append(FormField(key: "", value: ""))
                    } label: {
                        Label("Add Field", systemImage: "plus")
                            .font(DS.Font.body)
                            .foregroundStyle(Color.dsAcc)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .background(Color.dsBg)
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

// Backward compat
typealias FormDataEditor = FormDataEditorDS
