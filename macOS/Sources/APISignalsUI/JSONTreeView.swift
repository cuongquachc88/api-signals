import SwiftUI
import AppKit

// Recursive JSON tree with click-to-copy JSON paths
struct JSONTreeView: View {
    let data: Data
    @State private var copiedPath: String?

    var body: some View {
        if let value = try? JSONSerialization.jsonObject(with: data) {
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    JSONNodeView(value: value, path: "$", depth: 0, copiedPath: $copiedPath)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Unable to parse JSON")
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// Individual JSON node row (key: value, collapsible for objects/arrays)
private struct JSONNodeView: View {
    let value: Any
    let path: String
    let depth: Int
    @Binding var copiedPath: String?
    @State private var isExpanded = true

    private var indent: CGFloat { CGFloat(depth) * 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            if isExpanded {
                children
            }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if let dict = value as? [String: Any] {
            collapsibleRow(preview: isExpanded ? "{" : "{\u{2026}}", count: dict.count, symbol: "curlybraces")
        } else if let arr = value as? [Any] {
            collapsibleRow(preview: isExpanded ? "[" : "[\u{2026}]", count: arr.count, symbol: "square.stack")
        } else {
            leafRow
        }
    }

    private func collapsibleRow(preview: String, count: Int, symbol: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            leadingPadding
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            Text(preview)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
            if !isExpanded {
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(DS.Font.captionMono)
                    .foregroundStyle(Color.dsTextTertiary)
            }
            Spacer()
            copyButton
        }
        .padding(.vertical, 1)
    }

    private var leafRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            leadingPadding
            Color.clear.frame(width: 12)
            valueText(for: value)
                .font(DS.Font.bodyMono)
                .lineLimit(1)
            Spacer()
            copyButton
        }
        .padding(.vertical, 1)
    }

    private var leadingPadding: some View {
        Color.clear.frame(width: indent)
    }

    private var copyButton: some View {
        let isCopied = copiedPath == path
        return Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
            copiedPath = path
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedPath == path { copiedPath = nil }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                if isCopied {
                    Text("Copied")
                        .font(DS.Font.captionMono)
                }
            }
            .foregroundStyle(isCopied ? Color.dsSuccess : Color.dsTextTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.dsBord.opacity(isCopied ? 0.6 : 0.0))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .opacity(isCopied ? 1 : 0)
        .onHover { _ in } // makes button visible on hover via parent
        .help("Copy JSON path: \(path)")
    }

    @ViewBuilder
    private func valueText(for val: Any) -> some View {
        if let str = val as? String {
            Text("\"\(str)\"").foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.3))
        } else if let num = val as? NSNumber {
            Text(num.stringValue).foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.9))
        } else if val is NSNull {
            Text("null").foregroundStyle(Color.dsTextTertiary).italic()
        } else {
            Text("\(val)").foregroundStyle(Color.dsTextPrim)
        }
    }

    @ViewBuilder
    private var children: some View {
        if let dict = value as? [String: Any] {
            ForEach(dict.keys.sorted(), id: \.self) { key in
                let childPath = "\(path).\(key)"
                HStack(spacing: DS.Spacing.xs) {
                    Color.clear.frame(width: indent + 16)
                    Text("\(key):")
                        .font(DS.Font.bodyMono)
                        .foregroundStyle(Color.dsTextSec)
                        .lineLimit(1)
                    JSONNodeView(value: dict[key] ?? NSNull(), path: childPath, depth: depth + 1, copiedPath: $copiedPath)
                }
            }
            HStack(spacing: DS.Spacing.xs) {
                Color.clear.frame(width: indent)
                Color.clear.frame(width: 12)
                Text("}").font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
                Spacer()
            }
        } else if let arr = value as? [Any] {
            ForEach(Array(arr.enumerated()), id: \.offset) { i, item in
                let childPath = "\(path)[\(i)]"
                HStack(spacing: DS.Spacing.xs) {
                    Color.clear.frame(width: indent + 16)
                    Text("\(i):")
                        .font(DS.Font.captionMono)
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(width: 28, alignment: .leading)
                    JSONNodeView(value: item, path: childPath, depth: depth + 1, copiedPath: $copiedPath)
                }
            }
            HStack(spacing: DS.Spacing.xs) {
                Color.clear.frame(width: indent)
                Color.clear.frame(width: 12)
                Text("]").font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
                Spacer()
            }
        }
    }
}
