import React, { useState, useEffect, useMemo } from 'react';
import { clsx } from 'clsx';
import { useAppStore } from '../store/appStore';
import { METHOD_COLORS } from './RequestEditor';

export function QuickOpen() {
  const { isQuickOpenOpen, setQuickOpen, collections, requestsByCollection, openTab } = useAppStore();
  const [query, setQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);

  // Flatten all requests
  const allRequests = useMemo(() => {
    return Object.values(requestsByCollection).flat();
  }, [requestsByCollection]);

  // Filter results
  const results = useMemo(() => {
    if (!query.trim()) {
      return allRequests.slice(0, 20);
    }
    const q = query.toLowerCase();
    return allRequests.filter(r =>
      r.name.toLowerCase().includes(q) ||
      r.url.toLowerCase().includes(q) ||
      r.method.toLowerCase().includes(q)
    ).slice(0, 20);
  }, [query, allRequests]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  useEffect(() => {
    if (!isQuickOpenOpen) {
      setQuery('');
      setSelectedIndex(0);
    }
  }, [isQuickOpenOpen]);

  if (!isQuickOpenOpen) return null;

  const handleSelect = (idx: number) => {
    const req = results[idx];
    if (req) {
      openTab(req);
      setQuickOpen(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIndex(i => Math.min(i + 1, results.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIndex(i => Math.max(i - 1, 0));
    } else if (e.key === 'Enter') {
      handleSelect(selectedIndex);
    } else if (e.key === 'Escape') {
      setQuickOpen(false);
    }
  };

  const getCollection = (collectionId: string) =>
    collections.find(c => c.id === collectionId);

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-24 bg-black/60">
      <div className="bg-gray-900 border border-gray-700 rounded-xl shadow-2xl w-[600px] max-h-[500px] flex flex-col overflow-hidden">
        {/* Search input */}
        <div className="flex items-center gap-2 px-3 py-2.5 border-b border-gray-700">
          <svg className="w-4 h-4 text-gray-400 shrink-0" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="7" cy="7" r="5" />
            <path d="M11 11l3 3" strokeLinecap="round" />
          </svg>
          <input
            autoFocus
            className="flex-1 bg-transparent text-gray-200 text-sm outline-none placeholder-gray-600"
            placeholder="Search requests... (name, URL, method)"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
          />
          <kbd className="text-[10px] text-gray-500 bg-gray-800 px-1.5 py-0.5 rounded border border-gray-700">ESC</kbd>
        </div>

        {/* Results */}
        <div className="overflow-y-auto flex-1">
          {results.length === 0 ? (
            <div className="flex items-center justify-center py-12">
              <p className="text-gray-600 text-sm">No matching requests</p>
            </div>
          ) : (
            results.map((req, idx) => {
              const col = getCollection(req.collectionId);
              return (
                <div
                  key={req.id}
                  className={clsx(
                    'flex items-center gap-3 px-3 py-2 cursor-pointer',
                    idx === selectedIndex ? 'bg-blue-700/30' : 'hover:bg-gray-800'
                  )}
                  onClick={() => handleSelect(idx)}
                  onMouseEnter={() => setSelectedIndex(idx)}
                >
                  <span className={clsx('text-xs font-bold w-14 text-right shrink-0', METHOD_COLORS[req.method] ?? 'text-gray-400')}>
                    {req.method}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm text-gray-200 truncate">{req.name}</span>
                      {col && (
                        <span className="text-[10px] text-gray-500 bg-gray-800 px-1.5 py-0.5 rounded shrink-0">
                          {col.name}
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-gray-500 truncate font-mono">{req.url}</p>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center gap-3 px-3 py-2 border-t border-gray-700 text-[10px] text-gray-600">
          <span><kbd className="bg-gray-800 px-1 rounded">↑↓</kbd> navigate</span>
          <span><kbd className="bg-gray-800 px-1 rounded">↵</kbd> open</span>
          <span><kbd className="bg-gray-800 px-1 rounded">Esc</kbd> close</span>
          <div className="flex-1 text-right">{results.length} results</div>
        </div>
      </div>
    </div>
  );
}
