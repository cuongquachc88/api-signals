import SwiftUI
import AppKit
import APISignalsCore

/// Postman-style JSON editor: free text, white bg, line numbers + gutter fold chevrons.
struct JSONEditorView: View {
    @Binding var text: String
    var onChange: (() -> Void)? = nil
    var placeholder: String = "{\n  \n}"

    @State private var validationError: String?
    @State private var errorOffset: Int?
    @State private var flashMessage: String?
    @State private var flashIsError = false
    @State private var isFormatting = false
    @State private var editorAction: JSONEditorAction = .none
    @State private var validateTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            DSDivider()
            PostmanJSONTextView(text: $text, editorAction: $editorAction)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            if let validationError {
                statusBar(message: validationError, isError: true)
            } else if let flashMessage {
                statusBar(message: flashMessage, isError: flashIsError)
            } else if isFormatting {
                statusBar(message: "Formatting…", isError: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { scheduleValidate() }
        .onChange(of: text) { _, _ in
            scheduleValidate()
            onChange?()
        }
        .onDisappear { validateTask?.cancel() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "curlybraces")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dsTextSec)
            Text("JSON")
                .font(DS.Font.labelSm)
                .foregroundStyle(Color.dsTextSec)
            validityBadge
            Spacer()
            iconButton(systemImage: "arrow.up.left.and.arrow.down.right", help: "Expand all") {
                editorAction = .expandAll
            }
            iconButton(systemImage: "arrow.down.right.and.arrow.up.left", help: "Collapse all") {
                editorAction = .collapseAll
            }
            toolbarButton("Beautify") {
                beautify()
            }
            .disabled(isFormatting)
            toolbarButton("Minify") {
                minify()
            }
            .disabled(isFormatting)
            iconButton(systemImage: "doc.on.clipboard", help: "Copy") {
                copyJSON()
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color.dsSurf)
    }

    @ViewBuilder
    private var validityBadge: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else if isFormatting {
            ProgressView().controlSize(.small)
        } else if validationError == nil {
            Label("Valid", systemImage: "checkmark.circle.fill")
                .font(DS.Font.caption)
                .foregroundStyle(Color.dsGET)
        } else {
            Label("Invalid", systemImage: "exclamationmark.triangle.fill")
                .font(DS.Font.caption)
                .foregroundStyle(Color.dsError)
        }
    }

    private func statusBar(message: String, isError: Bool) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            if isFormatting, !isError {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 11))
            }
            Text(message).font(DS.Font.caption).lineLimit(2)
            Spacer()
            if isError, errorOffset != nil {
                Button("Go to error") {
                    if let errorOffset {
                        editorAction = .revealOffset(errorOffset)
                    } else {
                        jumpToCurrentError()
                    }
                }
                .buttonStyle(.plain)
                .font(DS.Font.caption)
                .foregroundStyle(Color.dsAcc)
            }
        }
        .foregroundStyle(isError ? Color.dsError : Color.dsTextSec)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xs)
        .background(isError ? Color.dsError.opacity(0.08) : Color.dsSurf)
    }

    private func toolbarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.caption)
                .foregroundStyle(Color.dsAcc)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func iconButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dsTextSec)
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Actions

    private func scheduleValidate() {
        validateTask?.cancel()
        validateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let snapshot = text
            let result = await Task.detached(priority: .utility) {
                JSONFormatter.validateDetailed(snapshot)
            }.value
            guard !Task.isCancelled else { return }
            applyValidationResult(result, announce: false, reveal: false)
        }
    }

    private func applyValidationResult(_ result: JSONValidationResult, announce: Bool, reveal: Bool) {
        if result.isValid {
            validationError = nil
            errorOffset = nil
            if announce {
                showFlash("Valid JSON")
            }
            return
        }
        if result.error == .empty {
            validationError = announce ? "JSON is empty" : nil
            errorOffset = nil
            if announce { showFlash("JSON is empty", isError: true) }
            return
        }
        validationError = result.message
        errorOffset = result.utf16Offset
        if announce {
            showFlash(result.message ?? "Invalid JSON", isError: true)
        }
        if reveal, let offset = result.utf16Offset {
            editorAction = .revealOffset(offset)
        }
    }

    private func jumpToCurrentError() {
        let result = JSONFormatter.validateDetailed(text)
        if let offset = result.utf16Offset {
            editorAction = .revealOffset(offset)
        } else if let line = result.line {
            editorAction = .revealLine(line: line, column: result.column ?? 1)
        }
    }

    private func beautify() {
        guard !isFormatting else { return }
        isFormatting = true
        editorAction = .expandAll
        let snapshot = text.isEmpty ? "{}" : text
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try JSONFormatter.beautify(snapshot) }
            }.value
            isFormatting = false
            switch result {
            case .success(let pretty):
                text = pretty
                validationError = nil
                showFlash("Beautified")
            case .failure(let error):
                let formatError = error as? JSONFormatError
                validationError = formatError?.message ?? error.localizedDescription
                showFlash(validationError ?? "Invalid JSON", isError: true)
                if let offset = formatError?.utf16Offset {
                    editorAction = .revealOffset(offset)
                }
            }
        }
    }

    private func minify() {
        guard !isFormatting else { return }
        isFormatting = true
        editorAction = .expandAll
        let snapshot = text.isEmpty ? "{}" : text
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try JSONFormatter.minify(snapshot) }
            }.value
            isFormatting = false
            switch result {
            case .success(let mini):
                text = mini
                validationError = nil
                showFlash("Minified")
            case .failure(let error):
                let formatError = error as? JSONFormatError
                validationError = formatError?.message ?? error.localizedDescription
                showFlash(validationError ?? "Invalid JSON", isError: true)
                if let offset = formatError?.utf16Offset {
                    editorAction = .revealOffset(offset)
                }
            }
        }
    }

    private func copyJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showFlash("Copied")
    }

    private func showFlash(_ message: String, isError: Bool = false) {
        flashMessage = message
        flashIsError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if flashMessage == message { flashMessage = nil }
        }
    }
}

enum JSONEditorAction: Equatable {
    case none
    case expandAll
    case collapseAll
    case revealOffset(Int)
    case revealLine(line: Int, column: Int)
}

// Backward-compatible name
typealias JSONFoldAction = JSONEditorAction

// MARK: - Postman-style text view (line # + fold gutter)

struct PostmanJSONTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var editorAction: JSONEditorAction

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let textView = FoldingJSONEditor()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.typingAttributes = FoldingJSONEditor.plainAttrs
        textView.backgroundColor = .white
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.onContentChange = { [weak coordinator = context.coordinator] in
            coordinator?.pushFullText()
        }

        scroll.documentView = textView
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        let ruler = JSONFoldRulerView(scrollView: scroll, textView: textView)
        scroll.verticalRulerView = ruler
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scroll.contentView,
            queue: .main
        ) { [weak ruler] _ in
            MainActor.assumeIsolated {
                ruler?.needsDisplay = true
            }
        }

        textView.setFullText(text, highlight: true)
        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if textView.fullText() != text {
            textView.setFullText(text, highlight: true)
            context.coordinator.ruler?.invalidateFolds()
            context.coordinator.ruler?.needsDisplay = true
        }

        switch editorAction {
        case .none:
            break
        case .expandAll:
            textView.expandAll()
            context.coordinator.pushFullText()
            context.coordinator.ruler?.invalidateFolds()
            context.coordinator.clearAction()
            context.coordinator.ruler?.needsDisplay = true
        case .collapseAll:
            textView.collapseAll()
            context.coordinator.pushFullText()
            context.coordinator.ruler?.invalidateFolds()
            context.coordinator.clearAction()
            context.coordinator.ruler?.needsDisplay = true
        case .revealOffset(let offset):
            textView.expandAll(notify: false)
            textView.reveal(utf16Offset: offset)
            context.coordinator.clearAction()
            context.coordinator.ruler?.needsDisplay = true
        case .revealLine(let line, let column):
            textView.expandAll(notify: false)
            textView.reveal(line: line, column: column)
            context.coordinator.clearAction()
            context.coordinator.ruler?.needsDisplay = true
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PostmanJSONTextView
        weak var textView: FoldingJSONEditor?
        weak var ruler: JSONFoldRulerView?

        init(_ parent: PostmanJSONTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            textView?.expandAll()
            pushFullText()
            textView?.applySyntaxHighlight()
            ruler?.invalidateFolds()
            ruler?.needsDisplay = true
        }

        @MainActor
        func pushFullText() {
            guard let textView else { return }
            let full = textView.fullText()
            if parent.text != full {
                parent.text = full
            }
        }

        @MainActor
        func clearAction() {
            if parent.editorAction != .none {
                parent.editorAction = .none
            }
        }
    }
}

// MARK: - Fold attachment

final class JSONFoldAttachment: NSTextAttachment {
    let foldedString: String

    @MainActor
    init(foldedString: String) {
        self.foldedString = foldedString
        super.init(data: nil, ofType: nil)
        attachmentCell = JSONFoldAttachmentCell()
    }

    required init?(coder: NSCoder) {
        foldedString = ""
        super.init(coder: coder)
    }
}

final class JSONFoldAttachmentCell: NSTextAttachmentCell {
    override func cellSize() -> NSSize {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let size = ("…" as NSString).size(withAttributes: [.font: font])
        return NSSize(width: ceil(size.width) + 2, height: ceil(size.height))
    }

    override func cellBaselineOffset() -> NSPoint { NSPoint(x: 0, y: -2) }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let label = "…" as NSString
        let size = label.size(withAttributes: attrs)
        label.draw(
            at: NSPoint(
                x: cellFrame.minX + (cellFrame.width - size.width) / 2,
                y: cellFrame.minY + (cellFrame.height - size.height) / 2
            ),
            withAttributes: attrs
        )
    }
}

// MARK: - Editor text view

final class FoldingJSONEditor: NSTextView {
    var onContentChange: (() -> Void)?

    static let plainAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor.labelColor
    ]

    private static let keyColor = NSColor(calibratedRed: 0.55, green: 0.22, blue: 0.18, alpha: 1) // Postman-ish brown
    private static let stringColor = NSColor.labelColor
    private static let boolColor = NSColor(calibratedRed: 0.15, green: 0.35, blue: 0.85, alpha: 1)
    private static let numberColor = NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.35, alpha: 1)
    private static let nullColor = NSColor.tertiaryLabelColor

    func fullText() -> String {
        guard let storage = textStorage else { return string }
        let result = NSMutableString()
        storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length)) { attrs, range, _ in
            if let fold = attrs[.attachment] as? JSONFoldAttachment {
                result.append(fold.foldedString)
            } else {
                result.append((storage.string as NSString).substring(with: range))
            }
        }
        return result as String
    }

    func setFullText(_ text: String, highlight: Bool) {
        expandAll(notify: false)
        string = text
        typingAttributes = Self.plainAttrs
        if highlight { applySyntaxHighlight() }
    }

    func reveal(utf16Offset: Int) {
        let length = (string as NSString).length
        guard length > 0 else { return }
        let loc = min(max(utf16Offset, 0), length)
        let range = NSRange(location: loc, length: 0)
        setSelectedRange(range)
        scrollRangeToVisible(NSRange(location: loc, length: min(1, length - loc)))
        window?.makeFirstResponder(self)
    }

    func reveal(line: Int, column: Int) {
        if let offset = JSONFormatter.utf16Offset(in: string, line: line, column: column) {
            reveal(utf16Offset: offset)
        }
    }

    func expandAll(notify: Bool = true) {
        guard let storage = textStorage else { return }
        var replacements: [(NSRange, String)] = []
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if let fold = value as? JSONFoldAttachment {
                replacements.append((range, fold.foldedString))
            }
        }
        guard !replacements.isEmpty else { return }
        storage.beginEditing()
        for (range, content) in replacements.reversed() {
            storage.replaceCharacters(in: range, with: NSAttributedString(string: content, attributes: Self.plainAttrs))
        }
        storage.endEditing()
        if notify {
            applySyntaxHighlight()
            onContentChange?()
        }
    }

    func collapseAll() {
        expandAll(notify: false)
        // Only collapse leaf multi-line containers (Postman-like). Cap work for huge docs.
        let regions = JSONFoldIndex.leafRegions(in: string)
        let limit = string.count > JSONFormatter.largeJSONCharacterThreshold ? 200 : regions.count
        for region in regions.prefix(limit).sorted(by: { $0.open > $1.open }) {
            collapse(open: region.open, close: region.close)
        }
        applySyntaxHighlight()
        onContentChange?()
    }

    func toggleFold(atOpen open: Int) {
        if let (range, fold) = attachmentAfter(open: open) {
            textStorage?.beginEditing()
            textStorage?.replaceCharacters(in: range, with: NSAttributedString(string: fold.foldedString, attributes: Self.plainAttrs))
            textStorage?.endEditing()
            applySyntaxHighlight()
            onContentChange?()
            return
        }
        guard let close = JSONFoldIndex.matchingClose(forOpen: open, in: string) else { return }
        collapse(open: open, close: close)
        applySyntaxHighlight()
        onContentChange?()
    }

    func isCollapsed(open: Int) -> Bool {
        attachmentAfter(open: open) != nil
    }

    private func attachmentAfter(open: Int) -> (NSRange, JSONFoldAttachment)? {
        guard let storage = textStorage else { return nil }
        let after = open + 1
        guard after < storage.length else { return nil }
        if let fold = storage.attribute(.attachment, at: after, effectiveRange: nil) as? JSONFoldAttachment {
            return (NSRange(location: after, length: 1), fold)
        }
        return nil
    }

    private func collapse(open: Int, close: Int) {
        guard let storage = textStorage else { return }
        guard close > open + 1 else { return }
        let inner = NSRange(location: open + 1, length: close - open - 1)
        guard NSMaxRange(inner) <= storage.length else { return }
        if attachmentAfter(open: open) != nil { return }

        let plain = contentExpandingFolds(in: inner)
        guard plain.contains("\n") else { return }

        let fold = JSONFoldAttachment(foldedString: plain)
        storage.beginEditing()
        storage.replaceCharacters(in: inner, with: NSAttributedString(attachment: fold))
        storage.endEditing()
    }

    private func contentExpandingFolds(in range: NSRange) -> String {
        guard let storage = textStorage else { return "" }
        let result = NSMutableString()
        storage.enumerateAttributes(in: range, options: []) { attrs, sub, _ in
            if let fold = attrs[.attachment] as? JSONFoldAttachment {
                result.append(fold.foldedString)
            } else {
                result.append((storage.string as NSString).substring(with: sub))
            }
        }
        return result as String
    }

    func applySyntaxHighlight() {
        guard let storage = textStorage else { return }
        let length = storage.length
        guard length > 0, length < 400_000 else {
            // Skip highlighting on huge buffers to keep UI responsive.
            return
        }
        storage.beginEditing()
        storage.addAttributes(Self.plainAttrs, range: NSRange(location: 0, length: length))

        let ns = storage.string as NSString
        var i = 0
        var inString = false
        var stringStart = 0
        var escaped = false
        var isKeyCandidate = false

        while i < length {
            // Skip fold attachments
            if storage.attribute(.attachment, at: i, effectiveRange: nil) is JSONFoldAttachment {
                i += 1
                continue
            }
            let ch = ns.character(at: i)
            if inString {
                if escaped {
                    escaped = false
                } else if ch == 92 {
                    escaped = true
                } else if ch == 34 {
                    inString = false
                    let range = NSRange(location: stringStart, length: i - stringStart + 1)
                    // Look ahead for : to decide key vs string value
                    var j = i + 1
                    while j < length {
                        let c = ns.character(at: j)
                        if c == 32 || c == 9 || c == 10 || c == 13 { j += 1; continue }
                        isKeyCandidate = (c == 58) // :
                        break
                    }
                    let color = isKeyCandidate ? Self.keyColor : Self.stringColor
                    storage.addAttribute(.foregroundColor, value: color, range: range)
                }
                i += 1
                continue
            }

            if ch == 34 {
                inString = true
                stringStart = i
                i += 1
                continue
            }

            // true / false / null / numbers
            if highlightKeyword("true", at: i, in: ns, storage: storage, color: Self.boolColor) {
                i += 4
                continue
            }
            if highlightKeyword("false", at: i, in: ns, storage: storage, color: Self.boolColor) {
                i += 5
                continue
            }
            if highlightKeyword("null", at: i, in: ns, storage: storage, color: Self.nullColor) {
                i += 4
                continue
            }
            if isNumberStart(ch) {
                let start = i
                i += 1
                while i < length {
                    let c = ns.character(at: i)
                    if (c >= 48 && c <= 57) || c == 46 || c == 45 || c == 43 || c == 101 || c == 69 {
                        i += 1
                    } else { break }
                }
                storage.addAttribute(.foregroundColor, value: Self.numberColor, range: NSRange(location: start, length: i - start))
                continue
            }
            i += 1
        }
        storage.endEditing()
    }

    private func highlightKeyword(
        _ word: String,
        at index: Int,
        in ns: NSString,
        storage: NSTextStorage,
        color: NSColor
    ) -> Bool {
        let w = word as NSString
        let len = w.length
        guard index + len <= ns.length else { return false }
        if ns.substring(with: NSRange(location: index, length: len)) != word { return false }
        let beforeOK = index == 0 || !isIdentChar(ns.character(at: index - 1))
        let afterOK = index + len >= ns.length || !isIdentChar(ns.character(at: index + len))
        guard beforeOK && afterOK else { return false }
        storage.addAttribute(.foregroundColor, value: color, range: NSRange(location: index, length: len))
        return true
    }

    private func isIdentChar(_ c: unichar) -> Bool {
        (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || (c >= 48 && c <= 57) || c == 95
    }

    private func isNumberStart(_ c: unichar) -> Bool {
        (c >= 48 && c <= 57) || c == 45
    }
}

// MARK: - Fold index (cached scans)

enum JSONFoldIndex {
    struct Region: Equatable {
        let open: Int
        let close: Int
    }

    static func regions(in text: String) -> [Region] {
        let ns = text as NSString
        var stack: [(Int, unichar)] = []
        var result: [Region] = []
        var inString = false
        var escaped = false
        let n = ns.length
        // Hard cap scan work
        let limit = min(n, 2_000_000)
        for i in 0..<limit {
            let ch = ns.character(at: i)
            if inString {
                if escaped { escaped = false }
                else if ch == 92 { escaped = true }
                else if ch == 34 { inString = false }
                continue
            }
            switch ch {
            case 34: inString = true
            case 123, 91: stack.append((i, ch))
            case 125, 93:
                guard let last = stack.popLast() else { break }
                let expect: unichar = ch == 125 ? 123 : 91
                guard last.1 == expect else { break }
                let slice = ns.substring(with: NSRange(location: last.0, length: i - last.0 + 1))
                if slice.contains("\n") {
                    result.append(Region(open: last.0, close: i))
                }
            default: break
            }
        }
        return result
    }

    static func leafRegions(in text: String) -> [Region] {
        let all = regions(in: text)
        return all.filter { region in
            !all.contains { other in
                other.open > region.open && other.close < region.close
            }
        }
    }

    static func matchingClose(forOpen open: Int, in text: String) -> Int? {
        if let r = regions(in: text).first(where: { $0.open == open }) {
            return r.close
        }
        let ns = text as NSString
        guard open < ns.length else { return nil }
        let openCh = ns.character(at: open)
        guard openCh == 123 || openCh == 91 else { return nil }
        let closeCh: unichar = openCh == 123 ? 125 : 93
        var depth = 0
        var inString = false
        var escaped = false
        for i in open..<ns.length {
            let ch = ns.character(at: i)
            if inString {
                if escaped { escaped = false }
                else if ch == 92 { escaped = true }
                else if ch == 34 { inString = false }
                continue
            }
            if ch == 34 { inString = true; continue }
            if ch == openCh { depth += 1 }
            else if ch == closeCh {
                depth -= 1
                if depth == 0 { return i }
            }
        }
        return nil
    }

    /// Map open indices that should show a fold chevron (multi-line containers + already collapsed).
    @MainActor
    static func foldableOpens(in displayed: String, textView: FoldingJSONEditor) -> Set<Int> {
        var opens = Set(regions(in: displayed).map(\.open))
        let ns = displayed as NSString
        for i in 0..<ns.length {
            let ch = ns.character(at: i)
            if (ch == 123 || ch == 91), textView.isCollapsed(open: i) {
                opens.insert(i)
            }
        }
        return opens
    }
}

// MARK: - Ruler: line numbers + fold chevrons (Postman layout)

final class JSONFoldRulerView: NSRulerView {
    private weak var textView: FoldingJSONEditor?
    private var cachedOpens: Set<Int> = []
    private var cacheToken: Int = 0
    private var lastStringLength: Int = -1

    private let numberWidth: CGFloat = 36
    private let foldWidth: CGFloat = 16

    init(scrollView: NSScrollView, textView: FoldingJSONEditor) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = numberWidth + foldWidth
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var requiredThickness: CGFloat { numberWidth + foldWidth }

    func invalidateFolds() {
        cacheToken &+= 1
        lastStringLength = -1
        cachedOpens = []
    }

    private func refreshCacheIfNeeded() {
        guard let textView else { return }
        let len = textView.string.count
        if len != lastStringLength || cachedOpens.isEmpty && len > 0 {
            lastStringLength = len
            // Skip fold index on extremely large buffers until beautified/smaller
            if len > 1_500_000 {
                cachedOpens = []
            } else {
                cachedOpens = JSONFoldIndex.foldableOpens(in: textView.string, textView: textView)
            }
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        refreshCacheIfNeeded()

        let numberAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let foldAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let visible = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        let ns = textView.string as NSString

        var lineNumber = 1
        if glyphRange.location > 0 {
            ns.enumerateSubstrings(
                in: NSRange(location: 0, length: min(glyphRange.location, ns.length)),
                options: [.byLines, .substringNotRequired]
            ) { _, _, _, _ in
                lineNumber += 1
            }
        }

        var glyphIndex = glyphRange.location
        let end = NSMaxRange(glyphRange)
        while glyphIndex < end {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let y = lineRect.minY - visible.minY + textView.textContainerInset.height

            // Line number
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: numberAttrs)
            label.draw(
                at: NSPoint(x: numberWidth - size.width - 4, y: y + (lineRect.height - size.height) / 2),
                withAttributes: numberAttrs
            )

            // Fold chevron (Postman: ▼ when expanded, ▶ when collapsed)
            if let open = openOnLine(charRange) {
                let collapsed = textView.isCollapsed(open: open)
                let chevron = (collapsed ? "▶" : "▼") as NSString
                let cSize = chevron.size(withAttributes: foldAttrs)
                chevron.draw(
                    at: NSPoint(
                        x: numberWidth + (foldWidth - cSize.width) / 2,
                        y: y + (lineRect.height - cSize.height) / 2
                    ),
                    withAttributes: foldAttrs
                )
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
            lineNumber += 1
        }

        if ns.length == 0 {
            let label = "1" as NSString
            let size = label.size(withAttributes: numberAttrs)
            label.draw(at: NSPoint(x: numberWidth - size.width - 4, y: 8), withAttributes: numberAttrs)
        }

        // Divider
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: ruleThickness - 0.5, y: 0))
        path.line(to: NSPoint(x: ruleThickness - 0.5, y: bounds.height))
        path.lineWidth = 1
        path.stroke()
    }

    private func openOnLine(_ charRange: NSRange) -> Int? {
        guard let textView else { return nil }
        let ns = textView.string as NSString
        let end = NSMaxRange(charRange)
        var last: Int?
        var i = charRange.location
        while i < end {
            let ch = ns.character(at: i)
            if ch == 10 || ch == 13 { break }
            if (ch == 123 || ch == 91), cachedOpens.contains(i) {
                last = i
            }
            i += 1
        }
        return last
    }

    override func mouseDown(with event: NSEvent) {
        guard let textView else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        // Only fold column is clickable for folding
        guard point.x >= numberWidth else {
            super.mouseDown(with: event)
            return
        }

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        refreshCacheIfNeeded()
        let visible = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        var glyphIndex = glyphRange.location
        let end = NSMaxRange(glyphRange)
        while glyphIndex < end {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let y = lineRect.minY - visible.minY + textView.textContainerInset.height
            if point.y >= y && point.y < y + lineRect.height {
                let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
                if let open = openOnLine(charRange) {
                    textView.toggleFold(atOpen: open)
                    invalidateFolds()
                    needsDisplay = true
                    enclosingScrollView?.documentView?.needsDisplay = true
                    return
                }
                break
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }
}

// Backward-compatible alias used elsewhere
typealias LineNumberedTextView = PostmanJSONTextView
