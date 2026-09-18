import React, { useState, useRef, useEffect } from 'react';
import { useAppStore } from '../store/appStore';
import { clsx } from 'clsx';
import { METHOD_COLORS } from './RequestEditor';

function TabLabel({ tabId, name, isSelected }: { tabId: string; name: string; isSelected: boolean }) {
  const { updateTabRequest, saveRequest } = useAppStore();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(name);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => { setDraft(name); }, [name]);

  const startEdit = (e: React.MouseEvent) => {
    if (!isSelected) return;
    e.stopPropagation();
    setDraft(name);
    setEditing(true);
    setTimeout(() => inputRef.current?.select(), 0);
  };

  const commit = async () => {
    setEditing(false);
    const trimmed = draft.trim();
    if (!trimmed || trimmed === name) return;
    updateTabRequest(tabId, { name: trimmed });
    const tab = useAppStore.getState().tabs.find(t => t.id === tabId);
    if (tab && !tab.requestId.endsWith('-history')) {
      await saveRequest({ ...tab.request, name: trimmed }).catch(console.error);
    }
  };

  const cancel = () => { setEditing(false); setDraft(name); };

  if (editing) {
    return (
      <input
        ref={inputRef}
        className="flex-1 min-w-0 bg-transparent text-xs text-white outline-none border-b border-blue-400"
        value={draft}
        autoFocus
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') { e.preventDefault(); commit(); }
          if (e.key === 'Escape') cancel();
          e.stopPropagation();
        }}
        onClick={(e) => e.stopPropagation()}
        style={{ width: `${Math.max(draft.length, 4)}ch` }}
      />
    );
  }

  return (
    <span
      className="text-xs truncate flex-1 min-w-0"
      onDoubleClick={startEdit}
      title={isSelected ? 'Double-click to rename' : undefined}
    >
      {name || 'Untitled'}
    </span>
  );
}

export function TabBar() {
  const { tabs, selectedTabId, selectTab, closeTab } = useAppStore();

  if (tabs.length === 0) return null;

  return (
    <div className="flex items-center overflow-x-auto border-b border-gray-700 bg-gray-900 h-9 shrink-0">
      {tabs.map((tab) => (
        <div
          key={tab.id}
          className={clsx(
            'flex items-center gap-1.5 px-3 h-full border-r border-gray-700 cursor-pointer select-none min-w-0 max-w-[200px] shrink-0 group',
            tab.id === selectedTabId
              ? 'bg-gray-800 border-b-2 border-b-blue-500 text-white'
              : 'text-gray-400 hover:bg-gray-800 hover:text-gray-200'
          )}
          onClick={() => selectTab(tab.id)}
        >
          <span className={clsx('text-xs font-bold shrink-0', METHOD_COLORS[tab.request.method] ?? 'text-gray-400')}>
            {tab.request.method}
          </span>
          <TabLabel
            tabId={tab.id}
            name={tab.request.name}
            isSelected={tab.id === selectedTabId}
          />
          {tab.isDirty && (
            <span className="text-blue-400 text-xs shrink-0 leading-none">●</span>
          )}
          <button
            className="shrink-0 opacity-0 group-hover:opacity-100 hover:text-white rounded p-0.5 ml-0.5"
            onClick={(e) => { e.stopPropagation(); closeTab(tab.id); }}
          >
            <svg className="w-3 h-3" viewBox="0 0 12 12" fill="currentColor">
              <path d="M8.5 3.5L3.5 8.5M3.5 3.5L8.5 8.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          </button>
        </div>
      ))}
    </div>
  );
}
