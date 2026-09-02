import React from 'react';
import CodeMirror from '@uiw/react-codemirror';
import { json } from '@codemirror/lang-json';
import { javascript } from '@codemirror/lang-javascript';
import { oneDark } from '@codemirror/theme-one-dark';
import { clsx } from 'clsx';
import type { RequestBody, KeyValue } from '../types';
import { ParamsHeadersEditor } from './ParamsHeadersEditor';
import { uuid } from '../utils/uuid';

interface Props {
  body: RequestBody;
  onChange: (body: RequestBody) => void;
}

const BODY_TABS = [
  { key: 'None', label: 'None' },
  { key: 'Json', label: 'JSON' },
  { key: 'Raw', label: 'Raw' },
  { key: 'FormData', label: 'Form Data' },
  { key: 'UrlEncoded', label: 'URL Encoded' },
  { key: 'GraphQL', label: 'GraphQL' },
  { key: 'Binary', label: 'Binary' },
] as const;

export function BodyEditor({ body, onChange }: Props) {
  const activeType = body.type;

  const setType = (type: RequestBody['type']) => {
    if (type === 'None') onChange({ type: 'None' });
    else if (type === 'Json') onChange({ type: 'Json', content: '' });
    else if (type === 'Raw') onChange({ type: 'Raw', content: '', contentType: 'text/plain' });
    else if (type === 'FormData') onChange({ type: 'FormData', fields: [] });
    else if (type === 'UrlEncoded') onChange({ type: 'UrlEncoded', fields: [] });
    else if (type === 'GraphQL') onChange({ type: 'GraphQL', query: '', variables: '{}' });
    else if (type === 'Binary') onChange({ type: 'Binary', filePath: '' });
  };

  return (
    <div className="flex flex-col h-full">
      {/* Type tabs */}
      <div className="flex items-center gap-0 border-b border-gray-700 px-2 shrink-0">
        {BODY_TABS.map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setType(key)}
            className={clsx(
              'px-3 py-1.5 text-xs transition-colors relative',
              activeType === key
                ? 'text-blue-400 after:absolute after:bottom-0 after:left-0 after:right-0 after:h-0.5 after:bg-blue-400'
                : 'text-gray-500 hover:text-gray-300'
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {body.type === 'None' && (
          <div className="flex items-center justify-center h-full">
            <p className="text-gray-600 text-sm">No body content</p>
          </div>
        )}

        {body.type === 'Json' && (
          <CodeMirror
            value={body.content}
            height="100%"
            theme={oneDark}
            extensions={[json()]}
            onChange={(value) => onChange({ ...body, content: value })}
            className="h-full text-sm"
          />
        )}

        {body.type === 'Raw' && (
          <div className="flex flex-col h-full">
            <div className="flex items-center gap-2 px-2 py-1 border-b border-gray-700 shrink-0">
              <label className="text-xs text-gray-400">Content-Type:</label>
              <input
                className="bg-gray-800 text-gray-200 rounded px-2 py-0.5 text-xs outline-none border border-gray-700"
                value={body.contentType}
                onChange={(e) => onChange({ ...body, contentType: e.target.value })}
                placeholder="text/plain"
              />
            </div>
            <CodeMirror
              value={body.content}
              height="100%"
              theme={oneDark}
              onChange={(value) => onChange({ ...body, content: value })}
              className="flex-1 text-sm"
            />
          </div>
        )}

        {(body.type === 'FormData' || body.type === 'UrlEncoded') && (
          <ParamsHeadersEditor
            items={body.fields}
            onChange={(fields) => onChange({ ...body, fields } as RequestBody)}
            keyPlaceholder="Field name"
            valuePlaceholder="Value"
          />
        )}

        {body.type === 'GraphQL' && (
          <div className="flex flex-col h-full">
            <div className="flex-1 flex flex-col min-h-0">
              <div className="px-2 py-1 text-xs text-gray-500 border-b border-gray-700 shrink-0">Query</div>
              <div className="flex-1 min-h-0" style={{ maxHeight: '60%' }}>
                <CodeMirror
                  value={body.query}
                  height="100%"
                  theme={oneDark}
                  extensions={[javascript()]}
                  onChange={(value) => onChange({ ...body, query: value })}
                  className="h-full text-sm"
                />
              </div>
              <div className="px-2 py-1 text-xs text-gray-500 border-y border-gray-700 shrink-0">Variables (JSON)</div>
              <div className="flex-1 min-h-0" style={{ maxHeight: '40%' }}>
                <CodeMirror
                  value={body.variables}
                  height="100%"
                  theme={oneDark}
                  extensions={[json()]}
                  onChange={(value) => onChange({ ...body, variables: value })}
                  className="h-full text-sm"
                />
              </div>
            </div>
          </div>
        )}

        {body.type === 'Binary' && (
          <div className="flex flex-col items-center justify-center h-full gap-3">
            {body.filePath ? (
              <div className="bg-gray-800 rounded px-3 py-2 text-sm text-gray-300">
                {body.filePath}
              </div>
            ) : (
              <p className="text-gray-500 text-sm">No file selected</p>
            )}
            <button
              className="bg-blue-600 hover:bg-blue-700 text-white text-sm rounded px-4 py-2"
              onClick={async () => {
                try {
                  const { open } = await import('@tauri-apps/plugin-dialog');
                  const path = await open({ multiple: false });
                  if (path && typeof path === 'string') {
                    onChange({ type: 'Binary', filePath: path });
                  }
                } catch {
                  console.error('File dialog not available');
                }
              }}
            >
              Choose File
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
