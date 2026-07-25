import SwiftUI
import APISignalsCore

public struct QuickOpenView: View {
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedIndex: Int = 0

    private var filteredRequests: [APIRequest] {
        if searchText.isEmpty {
            return appState.requests
        }
        let query = searchText.lowercased()
        return appState.requests.filter {
            $0.name.lowercased().contains(query) ||
            ($0.url.url?.absoluteString ?? "").lowercased().contains(query) ||
            $0.method.rawValue.lowercased().contains(query)
        }
    }

    private func collectionName(for request: APIRequest) -> String {
        appState.collections.first { $0.id == request.collectionId }?.name ?? ""
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search requests...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Divider()

            if filteredRequests.isEmpty {
                VStack {
                    Spacer()
                    Text("No requests found")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 200)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredRequests.enumerated()), id: \.element.id, selection: .constant(nil as APIRequest?)) { index, request in
                        Button {
                            appState.openTab(request)
                            onDismiss()
                        } label: {
                            HStack {
                                Text(request.method.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(methodColor(request.method))
                                    .frame(width: 50, alignment: .leading)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(request.name)
                                        .font(.body)
                                    Text(collectionName(for: request))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(request.url.url?.host ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                        .id(index)
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 560, height: 380)
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, filteredRequests.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < filteredRequests.count {
                appState.openTab(filteredRequests[selectedIndex])
                onDismiss()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .orange
        case .put: return .blue
        case .patch: return .purple
        case .delete: return .red
        default: return .secondary
        }
    }
}
