import SwiftUI
import APISignalsCore

// MARK: - Params Editor

struct ParamsEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        KeyValueEditor(
            items: Binding(
                get: { viewModel.request.queryParams },
                set: { viewModel.request.queryParams = $0; viewModel.updateRequest() }
            ),
            keyPlaceholder: "Parameter",
            valuePlaceholder: "Value",
            emptyMessage: "No query parameters"
        )
    }
}

// MARK: - Headers Editor

struct HeadersEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        KeyValueEditor(
            items: Binding(
                get: { viewModel.request.headers },
                set: { viewModel.request.headers = $0; viewModel.updateRequest() }
            ),
            keyPlaceholder: "Header",
            valuePlaceholder: "Value",
            emptyMessage: "No custom headers"
        )
    }
}

// MARK: - Key Value Editor (redesigned)

struct KeyValueEditor<T: KeyValueItem>: View where T: Equatable, T: Identifiable {
    @Binding var items: [T]
    var keyPlaceholder: String
    var valuePlaceholder: String
    var emptyMessage: String = "No items"

    var enabledCount: Int { items.filter(\.isEnabled).count }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: DS.Spacing.sm) {
                if enabledCount > 0 {
                    Text("\(enabledCount) active")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
                Spacer()
                Button {
                    items.append(T.new())
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsAcc)
                }
                .buttonStyle(.plain)
                .help("Add row")

                if !items.isEmpty {
                    Button {
                        items.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextSec)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            if items.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text(emptyMessage)
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                    Button {
                        items.append(T.new())
                    } label: {
                        Label("Add \(keyPlaceholder)", systemImage: "plus.circle")
                            .font(DS.Font.body)
                            .foregroundStyle(Color.dsAcc)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.dsBg)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Column headers
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 24)
                            Text(keyPlaceholder.uppercased())
                                .font(DS.Font.captionMono)
                                .foregroundStyle(Color.dsTextTertiary)
                                .tracking(0.3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.sm)
                            Text(valuePlaceholder.uppercased())
                                .font(DS.Font.captionMono)
                                .foregroundStyle(Color.dsTextTertiary)
                                .tracking(0.3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.sm)
                            Color.clear.frame(width: 28)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(Color.dsSurf.opacity(0.5))

                        DSDivider()

                        ForEach($items) { $item in
                            KeyValueRow(
                                item: $item,
                                keyPlaceholder: keyPlaceholder,
                                valuePlaceholder: valuePlaceholder,
                                onDelete: { items.removeAll { $0.id == item.id } }
                            )

                            DSDivider().opacity(0.4)
                        }

                        // Add row button
                        Button {
                            items.append(T.new())
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Add \(keyPlaceholder)")
                                    .font(DS.Font.body)
                            }
                            .foregroundStyle(Color.dsAcc)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                        .dsRowHover()
                    }
                }
                .background(Color.dsBg)
            }
        }
    }
}

// MARK: - Key Value Row

struct KeyValueRow<T: KeyValueItem>: View where T: Equatable, T: Identifiable {
    @Binding var item: T
    let keyPlaceholder: String
    let valuePlaceholder: String
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: $item.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 24)

            Divider().frame(height: 20)

            TextField(keyPlaceholder, text: $item.key)
                .textFieldStyle(.plain)
                .font(DS.Font.bodyMono)
                .foregroundStyle(item.isEnabled ? Color.dsTextPrim : Color.dsTextSec)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)

            Divider().frame(height: 20)

            TextField(valuePlaceholder, text: $item.value)
                .textFieldStyle(.plain)
                .font(DS.Font.bodyMono)
                .foregroundStyle(item.isEnabled ? Color.dsAcc : Color.dsTextSec)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)

            Button { onDelete() } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsError)
            }
            .buttonStyle(.plain)
            .frame(width: 28)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.leading, DS.Spacing.md)
        .background(isHovered ? Color.dsBord.opacity(0.2) : Color.clear)
        .onHover { isHovered = $0 }
        .opacity(item.isEnabled ? 1 : 0.5)
    }
}

// MARK: - Protocol and extensions

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
