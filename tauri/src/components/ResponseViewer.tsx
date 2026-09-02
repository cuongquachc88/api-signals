import React, { useState, useMemo } from 'react';
import { clsx } from 'clsx';
import type { APIResponse } from '../types';
import { JsonTreeView } from './JsonTreeView';
import { TimingWaterfall } from './TimingWaterfall';
import CodeMirror from '@uiw/react-codemirror';
import { json } from '@codemirror/lang-json';
import { oneDark } from '@codemirror/theme-one-dark';

interface Props {
  response: APIResponse;
  isLoading?: boolean;
}

type ResponseTab = 'Body' | 'Headers' | 'Cookies' | 'Timing';
type BodyMode = 'pretty' | 'raw' | 'preview';

function statusColor(status: number): string {
  if (status === 0) return 'bg-gray-700 text-gray-300';
  if (status < 200) return 'bg-gray-600 text-white';
  if (status < 300) return 'bg-green-700 text-white';
  if (status < 400) return 'bg-yellow-600 text-white';
  if (status < 500) return 'bg-orange-600 text-white';
  return 'bg-red-700 text-white';
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function isJson(body: string): boolean {
  try { JSON.parse(body); return true; } catch { return false; }
}

export function ResponseViewer({ response, isLoading }: Props) {
  const [tab, setTab] = useState<ResponseTab>('Body');
  const [bodyMode, setBodyMode] = useState<BodyMode>('pretty');

  const TABS: ResponseTab[] = ['Body', 'Headers', 'Cookies', 'Timing'];

  const looksLikeJson = useMemo(() => isJson(response.body), [response.body]);
  const formattedBody = useMemo(() => {
    if (looksLikeJson) {
      try {
        return JSON.stringify(JSON.parse(response.body), null, 2);
      } catch {
        return response.body;
      }
    }
    return response.body;
  }, [response.body, looksLikeJson]);

  const contentType = response.headers.find(h =>
    h.key.toLowerCase() === 'content-type'
  )?.value ?? '';

  return (
    <div className="flex flex-col h-full bg-gray-900">
      {/* Status bar */}
      <div className="flex items-center gap-3 px-3 py-1.5 border-b border-gray-700 shrink-0">
        <span className={clsx('px-2 py-0.5 rounded text-xs font-bold', statusColor(response.status))}>
          {response.status || 'ERR'} {response.statusText}
        </span>
        <span className="text-xs text-gray-400">
          {response.timing.totalMs.toFixed(0)} ms
        </span>
        <span className="text-xs text-gray-400">
          {formatBytes(response.bodySize)}
        </span>
        <div className="flex-1" />
        <button
          onClick={() => navigator.clipboard.writeText(response.body)}
          className="text-xs text-gray-500 hover:text-gray-300 px-2 py-0.5 rounded hover:bg-gray-800"
        >
          Copy
        </button>
      </div>

      {/* Tabs */}
      <div className="flex items-center border-b border-gray-700 shrink-0">
        {TABS.map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={clsx(
              'px-3 py-1.5 text-xs relative transition-colors',
              tab === t
                ? 'text-blue-400 after:absolute after:bottom-0 after:left-0 after:right-0 after:h-0.5 after:bg-blue-400'
                : 'text-gray-500 hover:text-gray-300'
            )}
          >
            {t}
            {t === 'Headers' && response.headers.length > 0 && (
              <span className="ml-1 text-[9px] bg-gray-700 text-gray-300 px-1 rounded-full">
                {response.headers.length}
              </span>
            )}
            {t === 'Cookies' && response.cookies.length > 0 && (
              <span className="ml-1 text-[9px] bg-gray-700 text-gray-300 px-1 rounded-full">
                {response.cookies.length}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {tab === 'Body' && (
          <div className="flex flex-col h-full">
            {/* Body mode selector */}
            <div className="flex items-center gap-1 px-2 py-1 border-b border-gray-800 shrink-0">
              {(['pretty', 'raw'] as BodyMode[]).map(m => (
                <button
                  key={m}
                  onClick={() => setBodyMode(m)}
                  className={clsx(
                    'px-2 py-0.5 text-xs rounded',
                    bodyMode === m ? 'bg-gray-700 text-white' : 'text-gray-500 hover:text-gray-300'
                  )}
                >
                  {m.charAt(0).toUpperCase() + m.slice(1)}
                </button>
              ))}
              {looksLikeJson && (
                <button
                  onClick={() => setBodyMode('preview')}
                  className={clsx(
                    'px-2 py-0.5 text-xs rounded',
                    bodyMode === 'preview' ? 'bg-gray-700 text-white' : 'text-gray-500 hover:text-gray-300'
                  )}
                >
                  Tree
                </button>
              )}
              {response.status === 0 && (
                <span className="ml-2 text-red-400 text-xs">Request failed</span>
              )}
            </div>

            {/* Body content */}
            <div className="flex-1 overflow-hidden">
              {bodyMode === 'preview' && looksLikeJson ? (
                <JsonTreeView json={response.body} />
              ) : bodyMode === 'pretty' && looksLikeJson ? (
                <CodeMirror
                  value={formattedBody}
                  height="100%"
                  theme={oneDark}
                  extensions={[json()]}
                  readOnly
                  className="h-full text-sm"
                />
              ) : (
                <div className="h-full overflow-auto p-3">
                  <pre className="text-xs text-gray-300 font-mono whitespace-pre-wrap break-all">
                    {response.body || '(empty response)'}
                  </pre>
                </div>
              )}
            </div>
          </div>
        )}

        {tab === 'Headers' && (
          <div className="overflow-auto h-full">
            <table className="w-full text-xs">
              <thead className="sticky top-0 bg-gray-900 text-gray-400">
                <tr className="border-b border-gray-700">
                  <th className="text-left py-1.5 px-3">Name</th>
                  <th className="text-left py-1.5 px-3">Value</th>
                </tr>
              </thead>
              <tbody>
                {response.headers.map((h, i) => (
                  <tr key={i} className="border-b border-gray-800 hover:bg-gray-800/40">
                    <td className="py-1.5 px-3 text-purple-300 font-medium">{h.key}</td>
                    <td className="py-1.5 px-3 text-gray-300 font-mono break-all">{h.value}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {tab === 'Cookies' && (
          <div className="overflow-auto h-full">
            {response.cookies.length === 0 ? (
              <div className="flex items-center justify-center h-full">
                <p className="text-gray-600 text-sm">No cookies</p>
              </div>
            ) : (
              <table className="w-full text-xs">
                <thead className="sticky top-0 bg-gray-900 text-gray-400">
                  <tr className="border-b border-gray-700">
                    <th className="text-left py-1.5 px-3">Name</th>
                    <th className="text-left py-1.5 px-3">Value</th>
                    <th className="text-left py-1.5 px-3">Domain</th>
                    <th className="text-left py-1.5 px-3">Path</th>
                    <th className="text-left py-1.5 px-3">Flags</th>
                  </tr>
                </thead>
                <tbody>
                  {response.cookies.map((c, i) => (
                    <tr key={i} className="border-b border-gray-800 hover:bg-gray-800/40">
                      <td className="py-1.5 px-3 text-amber-300">{c.name}</td>
                      <td className="py-1.5 px-3 text-gray-300 font-mono break-all max-w-xs">{c.value}</td>
                      <td className="py-1.5 px-3 text-gray-400">{c.domain ?? '-'}</td>
                      <td className="py-1.5 px-3 text-gray-400">{c.path ?? '-'}</td>
                      <td className="py-1.5 px-3">
                        {c.httpOnly && <span className="bg-blue-900 text-blue-300 rounded px-1 mr-1">HttpOnly</span>}
                        {c.secure && <span className="bg-green-900 text-green-300 rounded px-1">Secure</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        {tab === 'Timing' && (
          <div className="overflow-auto h-full">
            <TimingWaterfall timing={response.timing} />
          </div>
        )}
      </div>
    </div>
  );
}
