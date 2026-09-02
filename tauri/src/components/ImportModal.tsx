import React, { useState, useRef } from 'react';
import { clsx } from 'clsx';
import { api } from '../api/tauri';
import { useAppStore } from '../store/appStore';

type ImportTab = 'curl' | 'postman' | 'openapi' | 'har';

interface Props {
  onClose: () => void;
  preselectedCollectionId?: string;
}

function downloadJson(filename: string, data: string) {
  const blob = new Blob([data], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export { downloadJson };

export function ImportModal({ onClose, preselectedCollectionId }: Props) {
  const { collections, selectedWorkspaceId, requestsByCollection, loadRequests, openTab } = useAppStore();
  const [activeTab, setActiveTab] = useState<ImportTab>('curl');
  const [curlText, setCurlText] = useState('');
  const [fileText, setFileText] = useState('');
  const [fileName, setFileName] = useState('');
  const [targetCollectionId, setTargetCollectionId] = useState(preselectedCollectionId ?? collections[0]?.id ?? '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setFileName(file.name);
    const reader = new FileReader();
    reader.onload = (ev) => {
      setFileText(ev.target?.result as string ?? '');
    };
    reader.readAsText(file);
  };

  const handleImportCurl = async () => {
    if (!curlText.trim()) { setError('Paste a cURL command first.'); return; }
    setLoading(true);
    setError('');
    setSuccess('');
    try {
      const req = await api.importCurl(curlText.trim());
      openTab(req);
      setSuccess('Imported! The request was opened in a new tab.');
    } catch (e: any) {
      setError(`Failed to parse cURL: ${e?.message ?? e}`);
    } finally {
      setLoading(false);
    }
  };

  const handleImportFile = async () => {
    if (!fileText.trim()) { setError('Select a file first.'); return; }
    if (!selectedWorkspaceId) { setError('No workspace selected.'); return; }
    if (!targetCollectionId) { setError('Select a target collection.'); return; }
    setLoading(true);
    setError('');
    setSuccess('');
    try {
      if (activeTab === 'postman') {
        const result = await api.importPostman(fileText, selectedWorkspaceId, targetCollectionId);
        setSuccess(`Imported "${result.collectionName}" — ${result.requests.length} requests.`);
      } else if (activeTab === 'openapi') {
        const requests = await api.importOpenapi(fileText, selectedWorkspaceId, targetCollectionId);
        setSuccess(`Imported ${requests.length} requests from OpenAPI spec.`);
      } else if (activeTab === 'har') {
        const requests = await api.importHar(fileText, selectedWorkspaceId, targetCollectionId);
        setSuccess(`Imported ${requests.length} requests from HAR file.`);
      }
      // Reload the target collection's requests
      await loadRequests(targetCollectionId);
    } catch (e: any) {
      setError(`Import failed: ${e?.message ?? e}`);
    } finally {
      setLoading(false);
    }
  };

  const TABS: { key: ImportTab; label: string; desc: string }[] = [
    { key: 'curl', label: 'cURL', desc: 'Paste a cURL command' },
    { key: 'postman', label: 'Postman', desc: 'Import Postman Collection v2.1' },
    { key: 'openapi', label: 'OpenAPI', desc: 'Import OpenAPI / Swagger spec' },
    { key: 'har', label: 'HAR', desc: 'Import HTTP Archive' },
  ];

  const needsFile = activeTab !== 'curl';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-gray-900 border border-gray-700 rounded-lg w-[560px] flex flex-col shadow-2xl max-h-[85vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700 shrink-0">
          <h2 className="text-sm font-semibold text-white">Import</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-white">
            <svg className="w-4 h-4" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M2 2l10 10M12 2L2 12" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        {/* Tab selector */}
        <div className="flex border-b border-gray-700 shrink-0">
          {TABS.map(t => (
            <button
              key={t.key}
              onClick={() => { setActiveTab(t.key); setError(''); setSuccess(''); }}
              className={clsx(
                'px-4 py-2 text-xs font-medium transition-colors',
                activeTab === t.key
                  ? 'text-blue-400 border-b-2 border-blue-400'
                  : 'text-gray-500 hover:text-gray-300'
              )}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-auto p-4 flex flex-col gap-3">
          <p className="text-xs text-gray-400">{TABS.find(t => t.key === activeTab)?.desc}</p>

          {activeTab === 'curl' ? (
            <textarea
              className="w-full h-40 bg-gray-800 text-gray-200 rounded px-3 py-2 text-xs font-mono border border-gray-700 outline-none focus:border-blue-500 resize-none placeholder-gray-600"
              placeholder={"curl -X POST 'https://api.example.com/data' \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"key\":\"value\"}'"}
              value={curlText}
              onChange={(e) => setCurlText(e.target.value)}
              spellCheck={false}
            />
          ) : (
            <>
              {/* File picker */}
              <div
                className="flex flex-col items-center justify-center h-28 border-2 border-dashed border-gray-700 rounded-lg cursor-pointer hover:border-gray-500 transition-colors"
                onClick={() => fileInputRef.current?.click()}
              >
                <svg className="w-6 h-6 text-gray-500 mb-2" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M12 15V3m0 0l-4 4m4-4l4 4" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M2 17l.621 2.485A2 2 0 004.561 21h14.878a2 2 0 001.94-1.515L22 17" strokeLinecap="round" />
                </svg>
                {fileName ? (
                  <p className="text-xs text-green-400">{fileName}</p>
                ) : (
                  <p className="text-xs text-gray-500">Click to select file, or drag and drop</p>
                )}
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".json,.yaml,.yml,.har"
                  className="hidden"
                  onChange={handleFileChange}
                />
              </div>

              {/* Target collection selector */}
              <div>
                <label className="text-xs text-gray-400 font-medium block mb-1">Import into collection</label>
                <select
                  className="w-full bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
                  value={targetCollectionId}
                  onChange={(e) => setTargetCollectionId(e.target.value)}
                >
                  {collections.filter(c => c.parentId === null).map(col => (
                    <option key={col.id} value={col.id}>{col.name}</option>
                  ))}
                </select>
              </div>
            </>
          )}

          {error && (
            <p className="text-xs text-red-400 bg-red-900/20 border border-red-900/40 rounded px-3 py-2">{error}</p>
          )}
          {success && (
            <p className="text-xs text-green-400 bg-green-900/20 border border-green-900/40 rounded px-3 py-2">{success}</p>
          )}
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2 px-4 py-3 border-t border-gray-700 shrink-0">
          <button
            onClick={onClose}
            className="px-3 py-1.5 text-sm text-gray-400 hover:text-white rounded border border-gray-700 hover:border-gray-500"
          >
            Cancel
          </button>
          <button
            onClick={needsFile ? handleImportFile : handleImportCurl}
            disabled={loading}
            className={clsx(
              'px-4 py-1.5 text-sm rounded font-medium transition-colors',
              loading ? 'bg-blue-800 text-blue-200 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 text-white'
            )}
          >
            {loading ? 'Importing...' : 'Import'}
          </button>
        </div>
      </div>
    </div>
  );
}
