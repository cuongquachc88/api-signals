import React, { useState, useCallback } from 'react';
import { clsx } from 'clsx';
import { useAppStore } from '../store/appStore';
import { useRequest } from '../hooks/useRequest';
import { HTTP_METHODS } from '../types';
import { ParamsHeadersEditor } from './ParamsHeadersEditor';
import { BodyEditor } from './BodyEditor';
import { AuthEditor } from './AuthEditor';
import { api } from '../api/tauri';
import CodeMirror from '@uiw/react-codemirror';
import { javascript } from '@codemirror/lang-javascript';
import { oneDark } from '@codemirror/theme-one-dark';
import type { APIRequest } from '../types';

export const METHOD_COLORS: Record<string, string> = {
  GET: 'text-emerald-400',
  POST: 'text-amber-400',
  PUT: 'text-blue-400',
  PATCH: 'text-purple-400',
  DELETE: 'text-red-400',
  HEAD: 'text-cyan-400',
  OPTIONS: 'text-pink-400',
  TRACE: 'text-gray-400',
  CONNECT: 'text-gray-400',
};

function HighlightedURLInput({ value, onChange, onSend }: { value: string; onChange: (v: string) => void; onSend: () => void }) {
  const highlighted = value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\{\{([^}]+)\}\}/g, '<span style="color:#2dd4bf;background:rgba(45,212,191,0.12);border-radius:3px;padding:0 2px">{{$1}}</span>');

  return (
    <div className="flex-1 relative bg-gray-800 rounded border border-gray-700 focus-within:border-blue-500 h-8">
      {/* visible highlight layer */}
      <div
        className="absolute inset-0 px-3 py-1 text-sm font-mono pointer-events-none overflow-hidden whitespace-pre select-none leading-6"
        aria-hidden="true"
        dangerouslySetInnerHTML={{ __html: highlighted || '<span style="color:#4b5563">https://api.example.com/endpoint</span>' }}
      />
      {/* transparent-text input on top */}
      <input
        className="relative w-full h-full bg-transparent rounded px-3 py-1 text-sm font-mono outline-none leading-6"
        style={{ color: 'transparent', caretColor: '#e5e7eb', zIndex: 1 }}
        value={value}
        placeholder=""
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) onSend(); }}
        spellCheck={false}
        autoComplete="off"
      />
    </div>
  );
}

function CurlPasteButton({ onImport }: { onImport: (req: Partial<APIRequest>) => void }) {
  const [open, setOpen] = useState(false);
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleConfirm = async () => {
    if (!text.trim()) { setError('Paste a cURL command.'); return; }
    setLoading(true);
    setError('');
    try {
      const req = await api.importCurl(text.trim());
      onImport(req);
      setOpen(false);
      setText('');
    } catch (e: any) {
      setError(`Parse error: ${e?.message ?? e}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <button
        title="Paste cURL"
        onClick={() => setOpen(true)}
        className="h-8 px-2 rounded text-xs text-gray-500 hover:text-gray-300 hover:bg-gray-800 border border-gray-700 shrink-0 font-mono"
      >
        cURL
      </button>
      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
          <div className="bg-gray-900 border border-gray-700 rounded-lg w-[520px] flex flex-col shadow-2xl">
            <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
              <h2 className="text-sm font-semibold text-white">Paste cURL</h2>
              <button onClick={() => { setOpen(false); setText(''); setError(''); }} className="text-gray-500 hover:text-white">
                <svg className="w-4 h-4" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M2 2l10 10M12 2L2 12" strokeLinecap="round" />
                </svg>
              </button>
            </div>
            <div className="p-4 flex flex-col gap-3">
              <textarea
                autoFocus
                className="w-full h-36 bg-gray-800 text-gray-200 rounded px-3 py-2 text-xs font-mono border border-gray-700 outline-none focus:border-blue-500 resize-none placeholder-gray-600"
                placeholder={"curl -X POST 'https://api.example.com' \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"key\":\"value\"}'"}
                value={text}
                onChange={(e) => setText(e.target.value)}
                spellCheck={false}
              />
              {error && <p className="text-xs text-red-400">{error}</p>}
            </div>
            <div className="flex justify-end gap-2 px-4 py-3 border-t border-gray-700">
              <button
                onClick={() => { setOpen(false); setText(''); setError(''); }}
                className="px-3 py-1.5 text-sm text-gray-400 hover:text-white rounded border border-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirm}
                disabled={loading}
                className={clsx(
                  'px-4 py-1.5 text-sm rounded font-medium',
                  loading ? 'bg-blue-800 text-blue-200 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 text-white'
                )}
              >
                {loading ? 'Parsing...' : 'Import'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

const TABS = ['Params', 'Headers', 'Body', 'Auth', 'Scripts', 'Description'] as const;
type EditorTab = typeof TABS[number];

interface Props {
  tabId: string;
  request: APIRequest;
}

export function RequestEditor({ tabId, request }: Props) {
  const { updateTabRequest, saveRequest, tabs } = useAppStore();
  const { sendRequest } = useRequest();
  const [activeTab, setActiveTab] = useState<EditorTab>('Params');

  const tab = tabs.find(t => t.id === tabId);

  const update = useCallback((partial: Partial<APIRequest>) => {
    updateTabRequest(tabId, partial);
  }, [tabId, updateTabRequest]);

  const handleSend = async () => {
    await sendRequest(tabId);
  };

  const handleSave = async () => {
    if (tab) {
      await saveRequest(tab.request);
    }
  };

  const badgeCount = (tab: typeof TABS[number]) => {
    switch (tab) {
      case 'Params': return request.params.filter(p => p.enabled && p.key).length || null;
      case 'Headers': return request.headers.filter(h => h.enabled && h.key).length || null;
      case 'Body': return request.body.type !== 'None' ? '●' : null;
      case 'Auth': return request.auth.type !== 'None' ? '●' : null;
      case 'Scripts':
        return (request.preRequestScript || request.postResponseScript) ? '●' : null;
      default: return null;
    }
  };

  return (
    <div className="flex flex-col h-full bg-gray-900">
      {/* URL Bar */}
      <div className="flex items-center gap-2 p-2 border-b border-gray-700 shrink-0">
        {/* Method selector */}
        <select
          className={clsx(
            'h-8 bg-gray-800 rounded px-2 text-sm font-bold border border-gray-700 outline-none cursor-pointer shrink-0',
            METHOD_COLORS[request.method] ?? 'text-gray-400'
          )}
          value={request.method}
          onChange={(e) => update({ method: e.target.value as any })}
        >
          {HTTP_METHODS.map(m => (
            <option key={m} value={m} className={METHOD_COLORS[m]}>
              {m}
            </option>
          ))}
        </select>

        {/* cURL paste button */}
        <CurlPasteButton onImport={(req) => update(req)} />

        {/* URL input with variable highlighting */}
        <HighlightedURLInput
          value={request.url}
          onChange={(url) => update({ url })}
          onSend={handleSend}
        />

        {/* Send button */}
        <button
          className={clsx(
            'h-8 px-4 rounded text-sm font-medium transition-colors shrink-0',
            tab?.isLoading
              ? 'bg-red-700 hover:bg-red-600 text-white'
              : 'bg-blue-600 hover:bg-blue-700 text-white'
          )}
          onClick={tab?.isLoading ? undefined : handleSend}
        >
          {tab?.isLoading ? (
            <span className="flex items-center gap-1.5">
              <svg className="w-3 h-3 animate-spin" viewBox="0 0 12 12" fill="none">
                <circle cx="6" cy="6" r="5" stroke="currentColor" strokeWidth="2" strokeDasharray="20" strokeDashoffset="5"/>
              </svg>
              Cancel
            </span>
          ) : 'Send'}
        </button>

        {/* Save */}
        {tab?.isDirty && request.collectionId && (
          <button
            className="h-8 px-2 rounded text-xs text-gray-400 hover:text-white border border-gray-700 hover:border-gray-500 shrink-0"
            onClick={handleSave}
            title="Save (Cmd+S)"
          >
            Save
          </button>
        )}
      </div>

      {/* Sub-tabs */}
      <div className="flex items-center border-b border-gray-700 bg-gray-900 shrink-0">
        {TABS.map((t) => {
          const badge = badgeCount(t);
          return (
            <button
              key={t}
              onClick={() => setActiveTab(t)}
              className={clsx(
                'px-3 py-2 text-xs flex items-center gap-1 relative transition-colors',
                activeTab === t
                  ? 'text-blue-400 after:absolute after:bottom-0 after:left-0 after:right-0 after:h-0.5 after:bg-blue-400'
                  : 'text-gray-500 hover:text-gray-300'
              )}
            >
              {t}
              {badge !== null && (
                <span className={clsx(
                  'text-[9px] rounded-full px-1 min-w-[14px] text-center',
                  typeof badge === 'number' ? 'bg-gray-700 text-gray-300' : 'text-blue-400'
                )}>
                  {badge}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Tab content */}
      <div className="flex-1 overflow-hidden">
        {activeTab === 'Params' && (
          <ParamsHeadersEditor
            items={request.params}
            onChange={(params) => update({ params })}
            keyPlaceholder="Parameter"
            valuePlaceholder="Value"
          />
        )}

        {activeTab === 'Headers' && (
          <ParamsHeadersEditor
            items={request.headers}
            onChange={(headers) => update({ headers })}
            keyPlaceholder="Header"
            valuePlaceholder="Value"
          />
        )}

        {activeTab === 'Body' && (
          <BodyEditor
            body={request.body}
            onChange={(body) => update({ body })}
          />
        )}

        {activeTab === 'Auth' && (
          <AuthEditor
            auth={request.auth}
            onChange={(auth) => update({ auth })}
          />
        )}

        {activeTab === 'Scripts' && (
          <div className="flex flex-col h-full">
            <div className="flex-1 flex flex-col min-h-0">
              <div className="px-3 py-1.5 text-xs text-gray-400 border-b border-gray-700 bg-gray-850 font-medium shrink-0">
                Pre-request Script
                <span className="ml-2 text-gray-600 font-normal">Runs before the request is sent</span>
              </div>
              <div className="flex-1 min-h-0" style={{ maxHeight: '50%' }}>
                <CodeMirror
                  value={request.preRequestScript}
                  height="100%"
                  theme={oneDark}
                  extensions={[javascript()]}
                  onChange={(value) => update({ preRequestScript: value })}
                  className="h-full text-sm"
                />
              </div>
              <div className="px-3 py-1.5 text-xs text-gray-400 border-y border-gray-700 bg-gray-850 font-medium shrink-0">
                Post-response Script
                <span className="ml-2 text-gray-600 font-normal">Runs after the response is received</span>
              </div>
              <div className="flex-1 min-h-0" style={{ maxHeight: '50%' }}>
                <CodeMirror
                  value={request.postResponseScript}
                  height="100%"
                  theme={oneDark}
                  extensions={[javascript()]}
                  onChange={(value) => update({ postResponseScript: value })}
                  className="h-full text-sm"
                />
              </div>
            </div>
          </div>
        )}

        {activeTab === 'Description' && (
          <div className="p-3 h-full">
            <textarea
              className="w-full h-full bg-transparent text-gray-300 text-sm resize-none outline-none placeholder-gray-600"
              value={request.description}
              placeholder="Describe this request..."
              onChange={(e) => update({ description: e.target.value })}
            />
          </div>
        )}
      </div>
    </div>
  );
}
