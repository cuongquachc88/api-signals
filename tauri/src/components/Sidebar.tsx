import React, { useState, useCallback } from 'react';
import { clsx } from 'clsx';
import { useAppStore } from '../store/appStore';
import { METHOD_COLORS } from './RequestEditor';
import { api } from '../api/tauri';
import { ImportModal, downloadJson } from './ImportModal';
import type { Collection, APIRequest, HistoryEntry } from '../types';

// ─── Highlight helper ─────────────────────────────────────────────────────────

function Highlight({ text, query }: { text: string; query: string }) {
  if (!query) return <>{text}</>;
  const idx = text.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return <>{text}</>;
  return (
    <>
      {text.slice(0, idx)}
      <mark className="bg-yellow-500/30 text-yellow-300 rounded px-0.5">
        {text.slice(idx, idx + query.length)}
      </mark>
      {text.slice(idx + query.length)}
    </>
  );
}

// ─── Collection Tree ──────────────────────────────────────────────────────────

function CollectionNode({ collection, depth = 0, searchQuery = '' }: { collection: Collection; depth?: number; searchQuery?: string }) {
  const {
    collections, requestsByCollection, openTab, createRequest, createCollection,
    deleteCollection, loadRequests, updateCollection,
  } = useAppStore();

  const [expanded, setExpanded] = useState(true);
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState(collection.name);
  const [showImportModal, setShowImportModal] = useState(false);

  const childCollections = collections.filter(c => c.parentId === collection.id);
  const requests = requestsByCollection[collection.id] ?? [];

  const handleToggle = async () => {
    if (!expanded && requests.length === 0) {
      await loadRequests(collection.id);
    }
    setExpanded(!expanded);
  };

  const handleAddRequest = async (e: React.MouseEvent) => {
    e.stopPropagation();
    await createRequest(collection.id);
  };

  const handleAddSubCollection = async (e: React.MouseEvent) => {
    e.stopPropagation();
    await createCollection('New Collection', collection.id);
  };

  const handleRename = async () => {
    if (editName.trim() && editName !== collection.name) {
      await updateCollection(collection.id, editName.trim());
    }
    setIsEditing(false);
  };

  const handleDelete = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (confirm(`Delete collection "${collection.name}" and all its contents?`)) {
      await deleteCollection(collection.id);
    }
  };

  const handleExport = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const reqs = requestsByCollection[collection.id] ?? [];
      const json = await api.exportPostman(collection.name, reqs);
      downloadJson(`${collection.name.replace(/\s+/g, '_')}.postman_collection.json`, json);
    } catch (err: any) {
      alert(`Export failed: ${err?.message ?? err}`);
    }
  };

  return (
    <>
    {showImportModal && (
      <ImportModal
        onClose={() => setShowImportModal(false)}
        preselectedCollectionId={collection.id}
      />
    )}
    <div>
      <div
        className="flex items-center gap-1 px-1 py-0.5 rounded hover:bg-gray-800 group cursor-pointer"
        style={{ paddingLeft: `${4 + depth * 12}px` }}
        onClick={handleToggle}
        onDoubleClick={() => { setIsEditing(true); setEditName(collection.name); }}
      >
        <svg
          className={clsx('w-3 h-3 text-gray-500 shrink-0 transition-transform', expanded ? 'rotate-90' : '')}
          viewBox="0 0 12 12" fill="currentColor"
        >
          <path d="M4 2l4 4-4 4" />
        </svg>
        <svg className="w-3.5 h-3.5 text-amber-500 shrink-0" viewBox="0 0 14 14" fill="currentColor">
          <path d="M1 3h4l1.5 1.5H13v8H1z" />
        </svg>
        {isEditing ? (
          <input
            autoFocus
            className="flex-1 bg-gray-700 text-gray-200 text-xs rounded px-1 outline-none"
            value={editName}
            onChange={(e) => setEditName(e.target.value)}
            onBlur={handleRename}
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleRename();
              if (e.key === 'Escape') { setIsEditing(false); setEditName(collection.name); }
            }}
            onClick={(e) => e.stopPropagation()}
          />
        ) : (
          <span className="flex-1 text-xs text-gray-300 truncate">
            <Highlight text={collection.name} query={searchQuery} />
          </span>
        )}
        {/* Actions */}
        <div className="hidden group-hover:flex items-center gap-0.5 shrink-0">
          <button
            title="New Request"
            onClick={handleAddRequest}
            className="p-0.5 text-gray-500 hover:text-blue-400 rounded"
          >
            <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M6 1v10M1 6h10" strokeLinecap="round" />
            </svg>
          </button>
          <button
            title="New Folder"
            onClick={handleAddSubCollection}
            className="p-0.5 text-gray-500 hover:text-amber-400 rounded"
          >
            <svg className="w-3 h-3" viewBox="0 0 12 12" fill="currentColor">
              <path d="M1 2h3l1 1.5H11v6H1z" opacity="0.6" />
            </svg>
          </button>
          <button
            title="Import into collection"
            onClick={(e) => { e.stopPropagation(); setShowImportModal(true); }}
            className="p-0.5 text-gray-500 hover:text-green-400 rounded"
          >
            <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M6 1v7M3 5l3 3 3-3" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M1 10h10" strokeLinecap="round" />
            </svg>
          </button>
          <button
            title="Export as Postman"
            onClick={handleExport}
            className="p-0.5 text-gray-500 hover:text-purple-400 rounded"
          >
            <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M6 8V1M3 4L6 1l3 3" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M1 10h10" strokeLinecap="round" />
            </svg>
          </button>
          <button
            title="Delete"
            onClick={handleDelete}
            className="p-0.5 text-gray-500 hover:text-red-400 rounded"
          >
            <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M3 3L9 9M9 3L3 9" strokeLinecap="round" />
            </svg>
          </button>
        </div>
      </div>

      {expanded && (
        <div>
          {childCollections.map(c => (
            <CollectionNode key={c.id} collection={c} depth={depth + 1} searchQuery={searchQuery} />
          ))}
          {requests.map(req => (
            <RequestItem key={req.id} request={req} depth={depth + 1} searchQuery={searchQuery} />
          ))}
        </div>
      )}
    </div>
    </>
  );
}

function RequestItem({ request, depth = 0, searchQuery = '' }: { request: APIRequest; depth?: number; searchQuery?: string }) {
  const { openTab, deleteRequest, duplicateRequest, tabs, selectedTabId } = useAppStore();
  const isOpen = tabs.some(t => t.requestId === request.id);
  const isSelected = tabs.find(t => t.id === selectedTabId)?.requestId === request.id;

  const handleCopyAsCurl = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const curlStr = await api.exportCurl(request);
      await navigator.clipboard.writeText(curlStr);
    } catch (err: any) {
      alert(`Copy failed: ${err?.message ?? err}`);
    }
  };

  return (
    <div
      className={clsx(
        'flex items-center gap-1.5 px-1 py-0.5 rounded cursor-pointer group',
        isSelected ? 'bg-blue-900/40 border border-blue-700/30' : 'hover:bg-gray-800'
      )}
      style={{ paddingLeft: `${4 + depth * 12 + 8}px` }}
      onClick={() => openTab(request)}
      onDoubleClick={() => openTab(request)}
    >
      <span className={clsx('text-[10px] font-bold shrink-0 w-10 text-right', METHOD_COLORS[request.method] ?? 'text-gray-400')}>
        {request.method}
      </span>
      <span className="flex-1 text-xs text-gray-400 truncate">
        <Highlight text={request.name} query={searchQuery} />
      </span>
      {isOpen && <span className="w-1.5 h-1.5 rounded-full bg-blue-500 shrink-0" />}
      <div className="hidden group-hover:flex items-center gap-0.5 shrink-0">
        <button
          title="Copy as cURL"
          onClick={handleCopyAsCurl}
          className="p-0.5 text-gray-600 hover:text-teal-400 rounded"
        >
          <svg className="w-2.5 h-2.5" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2">
            <path d="M3 2h5a1 1 0 011 1v5" strokeLinecap="round" />
            <rect x="1" y="3" width="6" height="6" rx="1" />
          </svg>
        </button>
        <button
          title="Duplicate"
          onClick={(e) => { e.stopPropagation(); duplicateRequest(request.id); }}
          className="p-0.5 text-gray-600 hover:text-gray-400 rounded"
        >
          <svg className="w-2.5 h-2.5" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2">
            <rect x="1" y="3" width="6" height="6" rx="1" />
            <path d="M3 3V2a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1H7" />
          </svg>
        </button>
        <button
          title="Delete"
          onClick={(e) => { e.stopPropagation(); if (confirm('Delete request?')) deleteRequest(request.id); }}
          className="p-0.5 text-gray-600 hover:text-red-400 rounded"
        >
          <svg className="w-2.5 h-2.5" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2">
            <path d="M2 2L8 8M8 2L2 8" strokeLinecap="round" />
          </svg>
        </button>
      </div>
    </div>
  );
}

// ─── History Item ──────────────────────────────────────────────────────────────

function HistoryItem({ entry, searchQuery = '' }: { entry: HistoryEntry; searchQuery?: string }) {
  const { openTab, workspaces, selectedWorkspaceId } = useAppStore();

  const handleOpen = () => {
    try {
      const req = JSON.parse(entry.requestSnapshot);
      openTab({ ...req, id: entry.id + '-history' });
    } catch { }
  };

  const statusColor = entry.status >= 200 && entry.status < 300
    ? 'text-green-400'
    : entry.status >= 400 ? 'text-red-400' : 'text-yellow-400';

  return (
    <div
      className="flex flex-col gap-0.5 px-2 py-1.5 rounded hover:bg-gray-800 cursor-pointer group border-b border-gray-800/60"
      onClick={handleOpen}
    >
      <div className="flex items-center gap-1.5">
        <span className={clsx('text-[10px] font-bold shrink-0 w-10 text-right', METHOD_COLORS[entry.method] ?? 'text-gray-400')}>
          {entry.method}
        </span>
        <span className={clsx('text-[10px] font-mono shrink-0', statusColor)}>
          {entry.status || 'ERR'}
        </span>
        <span className="text-[10px] text-gray-500 shrink-0">{entry.durationMs.toFixed(0)}ms</span>
      </div>
      <span className="text-xs text-gray-400 truncate pl-12"><Highlight text={entry.url} query={searchQuery} /></span>
      <span className="text-[10px] text-gray-600 pl-12">
        {new Date(entry.timestamp).toLocaleString()}
      </span>
    </div>
  );
}

// ─── Sidebar ───────────────────────────────────────────────────────────────────

export function Sidebar() {
  const {
    collections, history, sidebarSection, setSidebarSection,
    searchQuery, setSearchQuery, createCollection, clearHistory,
    selectedWorkspaceId,
  } = useAppStore();

  const rootCollections = collections.filter(c => c.parentId === null);

  const filteredCollections = searchQuery
    ? collections.filter(c => c.name.toLowerCase().includes(searchQuery.toLowerCase()))
    : rootCollections;

  const filteredHistory = searchQuery
    ? history.filter(h =>
        h.url.toLowerCase().includes(searchQuery.toLowerCase()) ||
        h.method.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : history;

  return (
    <div className="flex flex-col h-full bg-gray-900 text-gray-300 min-w-0">
      {/* Search */}
      <div className="px-2 py-2 border-b border-gray-700 shrink-0">
        <div className="relative">
          <svg
            className="absolute left-2 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500"
            viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5"
          >
            <circle cx="6" cy="6" r="4" />
            <path d="M9 9l3 3" strokeLinecap="round" />
          </svg>
          <input
            className="w-full bg-gray-800 rounded pl-7 pr-2 py-1 text-xs text-gray-200 outline-none border border-gray-700 focus:border-gray-600 placeholder-gray-600"
            placeholder="Search..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>

      {/* Section tabs */}
      <div className="flex border-b border-gray-700 shrink-0">
        <button
          onClick={() => setSidebarSection('collections')}
          className={clsx(
            'flex-1 py-1.5 text-xs font-medium transition-colors',
            sidebarSection === 'collections' ? 'text-blue-400 border-b-2 border-blue-400' : 'text-gray-500 hover:text-gray-300'
          )}
        >
          Collections
        </button>
        <button
          onClick={() => setSidebarSection('history')}
          className={clsx(
            'flex-1 py-1.5 text-xs font-medium transition-colors',
            sidebarSection === 'history' ? 'text-blue-400 border-b-2 border-blue-400' : 'text-gray-500 hover:text-gray-300'
          )}
        >
          History
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        {sidebarSection === 'collections' && (
          <div>
            <div className="flex items-center justify-between px-2 py-1.5">
              <span className="text-[10px] text-gray-500 uppercase tracking-wide font-medium">Collections</span>
              <button
                onClick={() => createCollection('New Collection')}
                className="text-gray-500 hover:text-blue-400 p-0.5 rounded"
                title="New Collection"
              >
                <svg className="w-3.5 h-3.5" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M7 1v12M1 7h12" strokeLinecap="round" />
                </svg>
              </button>
            </div>
            {filteredCollections.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-gray-600 text-xs">No collections yet</p>
                <button
                  onClick={() => createCollection('My Collection')}
                  className="mt-2 text-xs text-blue-500 hover:text-blue-400"
                >
                  Create collection
                </button>
              </div>
            ) : (
              filteredCollections.map(col => (
                <CollectionNode key={col.id} collection={col} searchQuery={searchQuery} />
              ))
            )}
          </div>
        )}

        {sidebarSection === 'history' && (
          <div>
            <div className="flex items-center justify-between px-2 py-1.5">
              <span className="text-[10px] text-gray-500 uppercase tracking-wide font-medium">History</span>
              {history.length > 0 && (
                <button
                  onClick={() => { if (confirm('Clear all history?')) clearHistory(); }}
                  className="text-[10px] text-gray-600 hover:text-red-400"
                >
                  Clear
                </button>
              )}
            </div>
            {filteredHistory.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-gray-600 text-xs">No history yet</p>
              </div>
            ) : (
              filteredHistory.map(entry => (
                <HistoryItem key={entry.id} entry={entry} searchQuery={searchQuery} />
              ))
            )}
          </div>
        )}
      </div>
    </div>
  );
}
