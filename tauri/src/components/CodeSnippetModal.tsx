import React, { useState, useEffect } from 'react';
import { clsx } from 'clsx';
import { api } from '../api/tauri';
import type { APIRequest } from '../types';
import CodeMirror from '@uiw/react-codemirror';
import { javascript } from '@codemirror/lang-javascript';
import { oneDark } from '@codemirror/theme-one-dark';

const LANGUAGES = [
  { key: 'curl', label: 'cURL' },
  { key: 'fetch', label: 'JavaScript (fetch)' },
  { key: 'python', label: 'Python (requests)' },
  { key: 'go', label: 'Go (net/http)' },
  { key: 'php', label: 'PHP (cURL)' },
  { key: 'ruby', label: 'Ruby (Net::HTTP)' },
];

interface Props {
  request: APIRequest;
  onClose: () => void;
}

export function CodeSnippetModal({ request, onClose }: Props) {
  const [language, setLanguage] = useState('curl');
  const [snippet, setSnippet] = useState('');
  const [copied, setCopied] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    generateSnippet();
  }, [language]);

  const generateSnippet = async () => {
    setLoading(true);
    try {
      const code = await api.generateSnippet(language, request);
      setSnippet(code);
    } catch (e) {
      setSnippet(`// Error generating snippet: ${e}`);
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(snippet);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-gray-900 border border-gray-700 rounded-lg w-[800px] min-h-[500px] max-h-[80vh] h-[650px] flex flex-col shadow-2xl">
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h2 className="text-sm font-semibold text-white">Code Snippet</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-white">
            <svg className="w-4 h-4" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M2 2l10 10M12 2L2 12" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col flex-1 overflow-hidden">
          {/* Language selector */}
          <div className="flex items-center gap-2 px-4 py-2 border-b border-gray-700 shrink-0">
            <label className="text-xs text-gray-400 shrink-0">Language:</label>
            <select
              className="flex-1 bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
            >
              {LANGUAGES.map(l => (
                <option key={l.key} value={l.key}>{l.label}</option>
              ))}
            </select>
            <button
              onClick={handleCopy}
              className={clsx(
                'px-3 py-1.5 rounded text-sm transition-colors',
                copied
                  ? 'bg-green-700 text-white'
                  : 'bg-gray-800 text-gray-300 hover:bg-gray-700 border border-gray-700'
              )}
            >
              {copied ? 'Copied!' : 'Copy'}
            </button>
          </div>

          {/* Code view */}
          <div className="flex-1 overflow-hidden">
            {loading ? (
              <div className="flex items-center justify-center h-full">
                <div className="text-gray-500 text-sm">Generating...</div>
              </div>
            ) : (
              <CodeMirror
                value={snippet}
                height="500px"
                theme={oneDark}
                extensions={[javascript()]}
                readOnly
                className="text-sm"
                style={{ height: '500px' }}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
