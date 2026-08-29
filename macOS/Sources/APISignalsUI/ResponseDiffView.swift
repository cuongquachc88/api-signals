import SwiftUI
import APISignalsCore

struct ResponseDiffView: View {
    let currentResponse: APIResponse
    let history: [HistoryEntry]
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var selectedHistoryId: UUID?

    private var selectedEntry: HistoryEntry? {
        guard let id = selectedHistoryId else { return nil }
        return history.first { $0.id == id }
    }

    private var diffLines: [DiffLine]? {
        guard let entry = selectedEntry,
              let oldBody = entry.response?.body,
              let newBody = currentResponse.body else { return nil }
        let old = String(data: oldBody, encoding: .utf8) ?? ""
        let new = String(data: newBody, encoding: .utf8) ?? ""
        return LineDiff.diff(old: old, new: new)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Response Diff")
                    .font(DS.Font.title)
                    .foregroundStyle(Color.dsTextPrim)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(DS.Spacing.lg)

            DSDivider()

            // History picker
            HStack(spacing: DS.Spacing.md) {
                Text("Compare with:")
                    .font(DS.Font.label)
                    .foregroundStyle(Color.dsTextSec)

                Picker("", selection: $selectedHistoryId) {
                    Text("Select history entry…").tag(nil as UUID?)
                    ForEach(history) { entry in
                        Text(historyLabel(entry)).tag(entry.id as UUID?)
                    }
                }
                .frame(maxWidth: 360)

                Spacer()

                if let lines = diffLines {
                    let added = lines.filter { if case .added = $0 { return true }; return false }.count
                    let removed = lines.filter { if case .removed = $0 { return true }; return false }.count
                    HStack(spacing: DS.Spacing.sm) {
                        Label("\(added)", systemImage: "plus")
                            .font(DS.Font.captionMono)
                            .foregroundStyle(Color.dsSuccess)
                        Label("\(removed)", systemImage: "minus")
                            .font(DS.Font.captionMono)
                            .foregroundStyle(Color.dsError)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            // Diff content
            if let lines = diffLines {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            diffLineRow(line: line, number: i + 1)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .background(Color.dsBg)
            } else if selectedHistoryId != nil {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("Cannot diff — non-text response bodies")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("Select a history entry to compare")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.dsSurf)
        .frame(minWidth: 700, minHeight: 500)
    }

    @ViewBuilder
    private func diffLineRow(line: DiffLine, number: Int) -> some View {
        let (prefix, text, bg, fg): (String, String, Color, Color) = {
            switch line {
            case .unchanged(let s): return (" ", s, Color.clear, Color.dsTextPrim)
            case .added(let s): return ("+", s, Color.dsSuccess.opacity(0.12), Color.dsSuccess)
            case .removed(let s): return ("-", s, Color.dsError.opacity(0.12), Color.dsError)
            }
        }()

        HStack(spacing: 0) {
            Text(String(format: "%4d", number))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, DS.Spacing.sm)

            Text(prefix)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(fg)
                .frame(width: 14)

            Text(text)
                .font(DS.Font.bodyMono)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, DS.Spacing.md)
        }
        .padding(.vertical, 1)
        .background(bg)
    }

    private func historyLabel(_ entry: HistoryEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let method = entry.request.method.rawValue
        let url = entry.request.url.url?.host ?? ""
        return "\(method) \(url) — \(formatter.string(from: entry.timestamp))"
    }
}
