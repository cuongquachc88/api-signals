import SwiftUI
import WebKit
import APISignalsCore

struct CollectionDocView: View {
    let collection: Collection
    let onSave: (Collection) async -> Void

    @State private var markdown: String
    @State private var isSaving = false
    @State private var savedBanner = false
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(collection: Collection, onSave: @escaping (Collection) async -> Void) {
        self.collection = collection
        self.onSave = onSave
        _markdown = State(initialValue: collection.documentation ?? "# \(collection.name)\n\nDocument your API collection here.\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(collection.name) — Documentation")
                        .font(DS.Font.title)
                        .foregroundStyle(Color.dsTextPrim)
                    Text("Write markdown on the left, preview on the right. ⌘S to save.")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextSec)
                }
                Spacer()
                if savedBanner {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsSuccess)
                }
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isSaving)
            }
            .padding(DS.Spacing.lg)

            DSDivider()

            HSplitView {
                // Editor pane
                TextEditor(text: $markdown)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextPrim)
                    .scrollContentBackground(.hidden)
                    .background(Color.dsBg)
                    .frame(minWidth: 280)

                DSDivider(.vertical)

                // Preview pane
                MarkdownPreviewView(markdown: markdown)
                    .frame(minWidth: 280)
            }
        }
        .background(Color.dsSurf)
        .frame(minWidth: 760, minHeight: 520)
        .onKeyPress(.init("s"), phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            save()
            return .handled
        }
    }

    private func save() {
        isSaving = true
        var updated = collection
        updated.documentation = markdown.isEmpty ? nil : markdown
        Task {
            await onSave(updated)
            await MainActor.run {
                isSaving = false
                savedBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedBanner = false }
            }
        }
    }
}

// Simple WKWebView-backed markdown preview
struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, sans-serif; font-size: 14px; line-height: 1.6;
                 padding: 16px; color: #cdd6f4; background: #1e1e2e; }
          code { background: #313244; padding: 2px 4px; border-radius: 4px;
                 font-family: 'SF Mono', monospace; font-size: 12px; }
          pre  { background: #313244; padding: 12px; border-radius: 6px; overflow-x: auto; }
          pre code { background: none; padding: 0; }
          h1, h2, h3 { color: #cba6f7; }
          a { color: #89b4fa; }
          blockquote { border-left: 3px solid #585b70; margin: 0; padding-left: 12px; color: #a6adc8; }
          table { border-collapse: collapse; width: 100%; }
          th, td { border: 1px solid #45475a; padding: 6px 10px; }
          th { background: #313244; }
          @media (prefers-color-scheme: light) {
            body { color: #24273a; background: #eff1f5; }
            code { background: #ccd0da; }
            pre  { background: #ccd0da; }
            h1, h2, h3 { color: #8839ef; }
            a { color: #1e66f5; }
            blockquote { border-left-color: #acb0be; color: #6c6f85; }
            th, td { border-color: #acb0be; }
            th { background: #ccd0da; }
          }
        </style>
        </head>
        <body id="body"></body>
        <script>
        // Very minimal markdown renderer (headings, bold, italic, code, lists, links)
        function render(md) {
          let html = md
            .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
            .replace(/^######\\s+(.+)$/gm,'<h6>$1</h6>')
            .replace(/^#####\\s+(.+)$/gm,'<h5>$1</h5>')
            .replace(/^####\\s+(.+)$/gm,'<h4>$1</h4>')
            .replace(/^###\\s+(.+)$/gm,'<h3>$1</h3>')
            .replace(/^##\\s+(.+)$/gm,'<h2>$1</h2>')
            .replace(/^#\\s+(.+)$/gm,'<h1>$1</h1>')
            .replace(/```([\\s\\S]*?)```/g,'<pre><code>$1</code></pre>')
            .replace(/`([^`]+)`/g,'<code>$1</code>')
            .replace(/\\*\\*(.+?)\\*\\*/g,'<strong>$1</strong>')
            .replace(/\\*(.+?)\\*/g,'<em>$1</em>')
            .replace(/^[-*]\\s+(.+)$/gm,'<li>$1</li>')
            .replace(/(<li>.*<\\/li>)/gs,'<ul>$1</ul>')
            .replace(/^\\d+\\.\\s+(.+)$/gm,'<li>$1</li>')
            .replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g,'<a href="$2">$1</a>')
            .replace(/^>\\s?(.+)$/gm,'<blockquote>$1</blockquote>')
            .replace(/\\n{2,}/g,'</p><p>')
            .replace(/\\n/g,'<br>');
          return '<p>' + html + '</p>';
        }
        document.getElementById('body').innerHTML = render(`\(escaped)`);
        </script>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
