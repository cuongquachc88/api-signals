import React, { useState } from 'react';
import { clsx } from 'clsx';
import { useAppStore } from '../store/appStore';
import { api } from '../api/tauri';
import { METHOD_COLORS } from './RequestEditor';
import type { APIRequest, APIResponse } from '../types';

interface RunResult {
  request: APIRequest;
  response: APIResponse | null;
  error: string | null;
  durationMs: number;
}

export function CollectionRunner() {
  const { collections, requestsByCollection, loadRequests, settings, environments, activeEnvironmentId } = useAppStore();
  const [selectedCollectionId, setSelectedCollectionId] = useState('');
  const [results, setResults] = useState<RunResult[]>([]);
  const [isRunning, setIsRunning] = useState(false);
  const [delay, setDelay] = useState(200);
  const [progress, setProgress] = useState(0);

  const activeEnv = environments.find(e => e.id === activeEnvironmentId);
  const variables: Record<string, string> = {};
  if (activeEnv) {
    for (const v of activeEnv.variables) {
      if (v.enabled) variables[v.key] = v.value;
    }
  }

  const selectedCollection = collections.find(c => c.id === selectedCollectionId);
  const requests = selectedCollectionId ? (requestsByCollection[selectedCollectionId] ?? []) : [];

  const handleRun = async () => {
    if (!selectedCollectionId || requests.length === 0) return;

    // Load requests if not already loaded
    if (requests.length === 0) {
      await loadRequests(selectedCollectionId);
    }

    const allRequests = requestsByCollection[selectedCollectionId] ?? [];
    setIsRunning(true);
    setResults([]);
    setProgress(0);

    const newResults: RunResult[] = [];

    for (let i = 0; i < allRequests.length; i++) {
      const req = allRequests[i];
      const start = performance.now();
      try {
        const response = await api.executeRequest(req, {
          timeoutMs: settings.timeoutMs,
          sslVerify: settings.sslVerify,
          followRedirects: settings.followRedirects,
          variables,
        });
        const durationMs = performance.now() - start;
        newResults.push({ request: req, response, error: null, durationMs });
      } catch (err) {
        const durationMs = performance.now() - start;
        newResults.push({ request: req, response: null, error: String(err), durationMs });
      }
      setResults([...newResults]);
      setProgress(Math.round(((i + 1) / allRequests.length) * 100));

      if (i < allRequests.length - 1 && delay > 0) {
        await new Promise(r => setTimeout(r, delay));
      }
    }

    setIsRunning(false);
  };

  const passed = results.filter(r => r.response && r.response.status >= 200 && r.response.status < 300).length;
  const failed = results.filter(r => !r.response || r.response.status >= 400 || r.error).length;

  return (
    <div className="flex flex-col h-full">
      {/* Controls */}
      <div className="flex items-center gap-3 px-3 py-2.5 border-b border-gray-700 shrink-0">
        <select
          className="flex-1 bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
          value={selectedCollectionId}
          onChange={(e) => {
            setSelectedCollectionId(e.target.value);
            setResults([]);
            if (e.target.value) loadRequests(e.target.value);
          }}
        >
          <option value="">Select a collection...</option>
          {collections.filter(c => !c.parentId).map(c => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>

        <div className="flex items-center gap-2 shrink-0">
          <label className="text-xs text-gray-500">Delay (ms):</label>
          <input
            type="number"
            className="w-20 bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
            value={delay}
            min={0}
            max={10000}
            onChange={(e) => setDelay(Number(e.target.value))}
          />
        </div>

        <button
          onClick={handleRun}
          disabled={!selectedCollectionId || isRunning || requests.length === 0}
          className={clsx(
            'px-4 py-1.5 rounded text-sm font-medium transition-colors shrink-0',
            isRunning
              ? 'bg-red-700 text-white cursor-not-allowed'
              : 'bg-green-600 hover:bg-green-700 text-white disabled:opacity-50 disabled:cursor-not-allowed'
          )}
        >
          {isRunning ? `Running... ${progress}%` : 'Run Collection'}
        </button>
      </div>

      {/* Progress bar */}
      {isRunning && (
        <div className="h-1 bg-gray-800 shrink-0">
          <div
            className="h-full bg-blue-500 transition-all"
            style={{ width: `${progress}%` }}
          />
        </div>
      )}

      {/* Summary */}
      {results.length > 0 && (
        <div className="flex items-center gap-4 px-3 py-2 border-b border-gray-700 shrink-0 text-sm">
          <span className="text-gray-400">{results.length} requests</span>
          <span className="text-green-400">{passed} passed</span>
          <span className="text-red-400">{failed} failed</span>
          <span className="text-gray-500 ml-auto">
            Total: {results.reduce((sum, r) => sum + r.durationMs, 0).toFixed(0)}ms
          </span>
        </div>
      )}

      {/* Results */}
      <div className="flex-1 overflow-y-auto">
        {results.length === 0 && !isRunning && (
          <div className="flex flex-col items-center justify-center h-full text-gray-600">
            {selectedCollectionId ? (
              <>
                <p className="text-sm">{requests.length} requests ready to run</p>
                <p className="text-xs mt-1">Click "Run Collection" to execute all requests</p>
              </>
            ) : (
              <p className="text-sm">Select a collection to run</p>
            )}
          </div>
        )}

        {results.map((result, idx) => {
          const status = result.response?.status ?? 0;
          const isSuccess = status >= 200 && status < 300;
          const isError = !!result.error || (status >= 400 || status === 0);

          return (
            <div
              key={idx}
              className={clsx(
                'flex items-center gap-3 px-3 py-2.5 border-b border-gray-800',
                isError ? 'bg-red-900/10' : isSuccess ? 'bg-green-900/5' : ''
              )}
            >
              {/* Status icon */}
              <div className={clsx('w-5 h-5 rounded-full flex items-center justify-center shrink-0', {
                'bg-green-700': isSuccess,
                'bg-red-700': isError,
                'bg-yellow-700': !isSuccess && !isError && status > 0,
              })}>
                {isSuccess ? (
                  <svg className="w-3 h-3 text-white" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M2 6l3 3 5-5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                ) : (
                  <svg className="w-3 h-3 text-white" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M3 3L9 9M9 3L3 9" strokeLinecap="round" />
                  </svg>
                )}
              </div>

              <span className={clsx('text-xs font-bold w-14 text-right shrink-0', METHOD_COLORS[result.request.method] ?? 'text-gray-400')}>
                {result.request.method}
              </span>

              <div className="flex-1 min-w-0">
                <p className="text-sm text-gray-200 truncate">{result.request.name}</p>
                <p className="text-xs text-gray-500 truncate font-mono">{result.request.url}</p>
                {result.error && (
                  <p className="text-xs text-red-400 mt-0.5">{result.error}</p>
                )}
              </div>

              <div className="text-right shrink-0">
                <div className={clsx('text-sm font-medium', {
                  'text-green-400': isSuccess,
                  'text-red-400': isError,
                  'text-yellow-400': !isSuccess && !isError,
                })}>
                  {result.response?.status ?? 'ERR'}
                </div>
                <div className="text-xs text-gray-500">{result.durationMs.toFixed(0)}ms</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
