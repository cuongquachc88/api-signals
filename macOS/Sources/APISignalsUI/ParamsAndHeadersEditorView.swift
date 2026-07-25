import SwiftUI
import APISignalsCore

struct ParamsEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack {
            KeyValueEditor(
                items: Binding(
                    get: { viewModel.request.queryParams },
                    set: { viewModel.request.queryParams = $0; viewModel.updateRequest() }
                ),
                keyPlaceholder: "Key",
                valuePlaceholder: "Value"
            )
        }
        .padding()
    }
}

struct HeadersEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack {
            KeyValueEditor(
                items: Binding(
                    get: { viewModel.request.headers },
                    set: { viewModel.request.headers = $0; viewModel.updateRequest() }
                ),
                keyPlaceholder: "Header",
                valuePlaceholder: "Value"
            )
        }
        .padding()
    }
}

struct KeyValueEditor<T: KeyValueItem>: View where T: Equatable, T: Identifiable {
    @Binding var items: [T]
    var keyPlaceholder: String
    var valuePlaceholder: String

    var body: some View {
        List {
            ForEach($items) { $item in
                HStack(spacing: 8) {
                    Toggle("", isOn: $item.isEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                    TextField(keyPlaceholder, text: $item.key)
                        .textFieldStyle(.roundedBorder)

                    TextField(valuePlaceholder, text: $item.value)
                        .textFieldStyle(.roundedBorder)

                    Button("Remove") {
                        items.removeAll { $0.id == item.id }
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button("Add") {
                items.append(T.new())
            }
        }
    }
}

protocol KeyValueItem: Identifiable {
    init(key: String, value: String, isEnabled: Bool)
    var key: String { get set }
    var value: String { get set }
    var isEnabled: Bool { get set }
}

extension KeyValueItem {
    static func new() -> Self {
        Self(key: "", value: "", isEnabled: true)
    }
}

extension Header: KeyValueItem {}
extension Parameter: KeyValueItem {}
