import SwiftUI
import AppKit
import APISignalsCore

// MARK: - SwiftUI wrapper

struct GraphQLQueryEditor: NSViewRepresentable {
    @Binding var text: String
    var schema: GraphQLSchema?
    var hint: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, schema: schema)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        context.coordinator.schema = schema

        if textView.string != text {
            let sel = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(sel.location, text.count), length: 0))
        }

        // Apply syntax highlighting
        context.coordinator.highlight(textView)
    }
}

// MARK: - Coordinator (delegate + autocomplete)

final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>
    var schema: GraphQLSchema?
    weak var textView: NSTextView?

    // Tracks the word being typed for completion filtering
    private var completionWordRange: NSRange?

    init(text: Binding<String>, schema: GraphQLSchema?) {
        self.text = text
        self.schema = schema
    }

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        text.wrappedValue = tv.string
        highlight(tv)
    }

    // MARK: Autocomplete

    func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
        guard let schema else { return [] }
        completionWordRange = charRange

        let partial = (textView.string as NSString).substring(with: charRange).lowercased()
        let context = completionContext(in: textView.string, at: charRange.location)
        let candidates = completionCandidates(for: context, schema: schema)

        let filtered = candidates.filter { partial.isEmpty || $0.lowercased().hasPrefix(partial) }
        index?.pointee = -1
        return filtered
    }

    // MARK: Context detection

    private enum CompletionContext {
        case rootKeyword          // query / mutation / subscription
        case fieldOnType(String)  // inside a selection set for a known type
        case argument(String, String) // arg on field
        case unknown
    }

    private func completionContext(in text: String, at location: Int) -> CompletionContext {
        guard let schema else { return .unknown }
        let prefix = String(text.prefix(location))

        // Determine if we're at the root level
        let braceDepth = prefix.filter { $0 == "{" }.count - prefix.filter { $0 == "}" }.count
        if braceDepth == 0 { return .rootKeyword }

        // Try to find the enclosing type by matching the nearest opening brace
        // Walk backwards to find the field name that opened the last {
        let nsPrefix = prefix as NSString
        var depth = 0
        var i = nsPrefix.length - 1
        while i >= 0 {
            let ch = nsPrefix.character(at: i)
            if ch == UInt16(("{" as Character).asciiValue!) {
                if depth == 0 {
                    // Found enclosing brace — look backwards for the field name
                    let before = nsPrefix.substring(to: i).trimmingCharacters(in: .whitespacesAndNewlines)
                    if let fieldName = lastWord(in: before) {
                        // Search all types for a field with this name
                        for typeDef in schema.types where !typeDef.isBuiltin {
                            if let field = typeDef.fields.first(where: { $0.name == fieldName }) {
                                return .fieldOnType(field.typeName)
                            }
                        }
                        // Root query/mutation top-level
                        if let qt = schema.rootQueryType, qt.name == fieldName { return .fieldOnType(qt.name) }
                        return .fieldOnType(fieldName)
                    }
                    break
                }
                depth -= 1
            } else if ch == UInt16(("}" as Character).asciiValue!) {
                depth += 1
            }
            i -= 1
        }

        // Fallback: offer root query fields
        if let qt = schema.rootQueryType { return .fieldOnType(qt.name) }
        return .unknown
    }

    private func lastWord(in text: String) -> String? {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
        return words.last(where: { !$0.isEmpty })
    }

    private func completionCandidates(for context: CompletionContext, schema: GraphQLSchema) -> [String] {
        switch context {
        case .rootKeyword:
            var kws = ["query", "mutation", "subscription", "fragment"]
            if let qt = schema.rootQueryType { kws.append(contentsOf: qt.fields.map { $0.name }) }
            if let mt = schema.rootMutationType { kws.append(contentsOf: mt.fields.map { $0.name }) }
            return kws
        case .fieldOnType(let typeName):
            guard let typeDef = schema.type(named: typeName) else {
                // Try root query as fallback
                return schema.rootQueryType?.fields.map { $0.name } ?? []
            }
            var candidates = typeDef.fields.map { $0.name }
            candidates += typeDef.inputFields.map { $0.name }
            candidates += typeDef.enumValues
            candidates += ["__typename"]
            return candidates
        case .argument(_, let fieldName):
            for typeDef in schema.types where !typeDef.isBuiltin {
                if let field = typeDef.fields.first(where: { $0.name == fieldName }) {
                    return field.args.map { "\($0.name): " }
                }
            }
            return []
        case .unknown:
            return schema.rootQueryType?.fields.map { $0.name } ?? []
        }
    }

    // MARK: Syntax highlighting

    func highlight(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let str = storage.string
        let fullRange = NSRange(location: 0, length: (str as NSString).length)

        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)

        // Keywords
        applyColor(.systemPurple, pattern: #"\b(query|mutation|subscription|fragment|on)\b"#, to: storage, in: str)
        // Directives
        applyColor(.systemTeal, pattern: #"@\w+"#, to: storage, in: str)
        // Field names (word before colon or brace)
        applyColor(.systemBlue, pattern: #"\b([a-z_][a-zA-Z0-9_]*)\s*(?=\(|{|\s*{)"#, to: storage, in: str)
        // Arguments / variables
        applyColor(.systemOrange, pattern: #"\$[a-zA-Z_]\w*"#, to: storage, in: str)
        // Strings
        applyColor(.systemRed, pattern: #""[^"]*""#, to: storage, in: str)
        // Comments
        applyColor(.secondaryLabelColor, pattern: #"#[^\n]*"#, to: storage, in: str)
        // Type names (capitalized)
        applyColor(.systemGreen, pattern: #"\b[A-Z][a-zA-Z0-9_]*\b"#, to: storage, in: str)

        storage.endEditing()
    }

    private func applyColor(_ color: NSColor, pattern: String, to storage: NSTextStorage, in str: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsStr = str as NSString
        let matches = regex.matches(in: str, range: NSRange(location: 0, length: nsStr.length))
        for match in matches {
            let range = match.range(at: match.numberOfRanges > 1 ? 1 : 0)
            if range.location != NSNotFound {
                storage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
    }
}
