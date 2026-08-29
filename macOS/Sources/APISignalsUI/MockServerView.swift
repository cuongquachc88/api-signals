import SwiftUI
import APISignalsCore
import APISignalsNetwork

struct MockServerView: View {
    @StateObject private var server = MockServer()
    @State private var portText = "8788"
    @State private var editingRoute: MockRoute?
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mock Server")
                        .font(DS.Font.title)
                        .foregroundStyle(Color.dsTextPrim)
                    if server.isRunning {
                        Text("Listening on http://localhost:\(server.port)")
                            .font(DS.Font.captionMono)
                            .foregroundStyle(Color.dsSuccess)
                    } else {
                        Text("Not running")
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(DS.Spacing.lg)

            DSDivider()

            // Controls
            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Port:")
                        .font(DS.Font.label)
                        .foregroundStyle(Color.dsTextSec)
                    TextField("8788", text: $portText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .font(DS.Font.bodyMono)
                        .disabled(server.isRunning)
                }

                if server.isRunning {
                    Button {
                        server.stop()
                    } label: {
                        Label("Stop Server", systemImage: "stop.fill")
                            .font(DS.Font.label)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.dsError)
                    .controlSize(.small)
                } else {
                    Button {
                        let p = UInt16(portText) ?? 8788
                        portText = "\(p)"
                        server.start(port: p)
                    } label: {
                        Label("Start Server", systemImage: "play.fill")
                            .font(DS.Font.label)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.dsSuccess)
                    .controlSize(.small)
                }

                if let err = server.lastError {
                    Text(err)
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsError)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    let route = MockRoute()
                    server.routes.append(route)
                    editingRoute = route
                } label: {
                    Label("Add Route", systemImage: "plus")
                        .font(DS.Font.label)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            // Routes list
            if server.routes.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("No mock routes yet")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                    Text("Add routes to stub API responses locally.")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.dsBg)
            } else {
                List {
                    ForEach($server.routes) { $route in
                        routeRow(route: $route)
                    }
                    .onDelete { offsets in
                        server.routes.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
                .background(Color.dsBg)
            }
        }
        .background(Color.dsSurf)
        .frame(minWidth: 680, minHeight: 460)
        .sheet(item: $editingRoute) { route in
            MockRouteEditor(route: route) { updated in
                if let i = server.routes.firstIndex(where: { $0.id == updated.id }) {
                    server.routes[i] = updated
                }
            }
        }
    }

    @ViewBuilder
    private func routeRow(route: Binding<MockRoute>) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Toggle("", isOn: route.isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()

            Text(route.wrappedValue.method.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(route.wrappedValue.method.color)
                .frame(width: 50, alignment: .center)
                .padding(.vertical, 2)
                .background(route.wrappedValue.method.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(route.wrappedValue.path)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
                .lineLimit(1)

            Spacer()

            Text("\(route.wrappedValue.statusCode)")
                .font(DS.Font.captionMono)
                .foregroundStyle(route.wrappedValue.statusCode < 400 ? Color.dsSuccess : Color.dsError)
                .frame(width: 36, alignment: .trailing)

            Button {
                editingRoute = route.wrappedValue
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextSec)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Route Editor Sheet

struct MockRouteEditor: View {
    let route: MockRoute
    let onSave: (MockRoute) -> Void

    @State private var edited: MockRoute
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(route: MockRoute, onSave: @escaping (MockRoute) -> Void) {
        self.route = route
        self.onSave = onSave
        _edited = State(initialValue: route)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Mock Route")
                    .font(DS.Font.title)
                    .foregroundStyle(Color.dsTextPrim)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Save") { onSave(edited); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(DS.Spacing.lg)

            DSDivider()

            Form {
                Section("Request Matching") {
                    Picker("Method", selection: $edited.method) {
                        ForEach(HTTPMethod.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .frame(width: 220)

                    TextField("Path (e.g. /api/users)", text: $edited.path)
                        .font(DS.Font.bodyMono)
                }

                Section("Response") {
                    Stepper("Status: \(edited.statusCode)", value: $edited.statusCode, in: 100...599, step: 1)
                    TextField("Content-Type", text: $edited.responseContentType)
                        .font(DS.Font.bodyMono)
                    TextEditor(text: $edited.responseBody)
                        .font(DS.Font.bodyMono)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color.dsSurf)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(Color.dsBord, lineWidth: 1)
                        )
                }
            }
            .formStyle(.grouped)
            .padding(DS.Spacing.md)
        }
        .background(Color.dsSurf)
        .frame(minWidth: 480, minHeight: 420)
    }
}
