import { EditorView } from '@codemirror/view';
import { oneDark } from '@codemirror/theme-one-dark';

const fontOverride = EditorView.theme({
  '&': {
    fontFamily: "'JetBrains Mono', 'SF Mono', 'Fira Code', monospace",
    fontSize: '13px',
  },
  '.cm-scroller': {
    fontFamily: "'JetBrains Mono', 'SF Mono', 'Fira Code', monospace !important",
    fontSize: '13px !important',
    lineHeight: '1.6 !important',
    fontFeatureSettings: "'liga' 1, 'calt' 1",
  },
  '.cm-content': {
    fontFamily: "'JetBrains Mono', 'SF Mono', 'Fira Code', monospace",
  },
});

export const editorExtensions = [oneDark, fontOverride];
export { oneDark as editorTheme };
