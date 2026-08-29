import SwiftUI
import AppKit
import APISignalsCore

// NSTextField subclass that renders URL components with color coding:
//   host       → primary text color
//   path       → secondary text color
//   query      → accent blue
//   {{vars}}   → orange
struct HighlightedURLField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var variables: [Variable]
    var onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = URLTextField()
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.font = font
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commit(_:))
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        let attributed = URLHighlighter.attributedString(
            for: nsView.stringValue == text ? nsView.stringValue : text,
            variables: variables,
            font: font
        )
        // Only update if not currently editing to avoid caret jump
        if nsView.currentEditor() == nil {
            nsView.attributedStringValue = attributed
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: HighlightedURLField

        init(_ parent: HighlightedURLField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            // Recolor while typing
            let attributed = URLHighlighter.attributedString(
                for: field.stringValue,
                variables: parent.variables,
                font: parent.font
            )
            if let editor = field.currentEditor() as? NSTextView {
                let selection = editor.selectedRange()
                editor.textStorage?.setAttributedString(attributed)
                if selection.location <= attributed.length {
                    editor.setSelectedRange(selection)
                }
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit(control.stringValue)
                return true
            }
            return false
        }

        @objc func commit(_ sender: NSTextField) {
            parent.onCommit(sender.stringValue)
        }
    }
}

// Custom NSTextField that always applies URL highlighting after losing focus
private final class URLTextField: NSTextField {
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
    }
}

// MARK: - URL Highlighter

enum URLHighlighter {
    static func attributedString(for text: String, variables: [Variable], font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        guard !text.isEmpty else { return result }

        let fullRange = NSRange(text.startIndex..., in: text)
        let baseAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        // Detect {{variable}} spans first
        let varPattern = try? NSRegularExpression(pattern: #"\{\{[^}]+\}\}"#)
        var varRanges: [NSRange] = []
        varPattern?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            if let r = match?.range { varRanges.append(r) }
        }

        // Try to parse URL components
        guard let components = URLComponents(string: text) else {
            // Fallback: just highlight variables
            return highlight(text: text, varRanges: varRanges, baseAttr: baseAttr, font: font)
        }

        // Build spans: [host][path][?query]
        let hostStr = (components.host ?? "")
        let scheme = components.scheme.map { $0 + "://" } ?? ""
        let port = components.port.map { ":\($0)" } ?? ""
        let path = components.path
        let query = components.query.map { "?\($0)" } ?? ""
        let fragment = components.fragment.map { "#\($0)" } ?? ""

        let secColor = NSColor.secondaryLabelColor
        let accColor = NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1.0)
        let varColor = NSColor(red: 0.9, green: 0.50, blue: 0.23, alpha: 1.0)

        func append(_ part: String, color: NSColor) {
            guard !part.isEmpty else { return }
            let attr = NSMutableAttributedString(string: part, attributes: baseAttr)
            // Mark variable spans in this part
            let partRange = NSRange(part.startIndex..., in: part)
            let partOffset = result.length
            varPattern?.enumerateMatches(in: part, range: partRange) { match, _, _ in
                if let r = match?.range {
                    attr.addAttribute(.foregroundColor, value: varColor, range: r)
                }
            }
            // If no var overrides exist in entire part, apply base color
            let hasVars = varPattern?.firstMatch(in: part, range: partRange) != nil
            if !hasVars {
                attr.addAttribute(.foregroundColor, value: color, range: partRange)
            } else {
                // Color non-var portions with base color
                var cursor = partRange.location
                varPattern?.enumerateMatches(in: part, range: partRange) { match, _, _ in
                    guard let r = match?.range else { return }
                    if r.location > cursor {
                        let beforeRange = NSRange(location: cursor, length: r.location - cursor)
                        attr.addAttribute(.foregroundColor, value: color, range: beforeRange)
                    }
                    attr.addAttribute(.foregroundColor, value: varColor, range: r)
                    cursor = r.location + r.length
                }
                if cursor < partRange.location + partRange.length {
                    let afterRange = NSRange(location: cursor, length: partRange.location + partRange.length - cursor)
                    attr.addAttribute(.foregroundColor, value: color, range: afterRange)
                }
            }
            result.append(attr)
        }

        append(scheme, color: NSColor.tertiaryLabelColor)
        append(hostStr + port, color: NSColor.labelColor)
        append(path, color: secColor)
        append(query, color: accColor)
        append(fragment, color: secColor)
        return result
    }

    private static func highlight(text: String, varRanges: [NSRange], baseAttr: [NSAttributedString.Key: Any], font: NSFont) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: text, attributes: baseAttr)
        let varColor = NSColor(red: 0.9, green: 0.50, blue: 0.23, alpha: 1.0)
        for r in varRanges {
            attr.addAttribute(.foregroundColor, value: varColor, range: r)
        }
        return attr
    }
}
