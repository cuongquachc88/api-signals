import React, { useEffect, useState } from 'react';
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels';
import { clsx } from 'clsx';
import { useAppStore } from './store/appStore';
import { Sidebar } from './components/Sidebar';
import { TabBar } from './components/TabBar';
import { RequestEditor } from './components/RequestEditor';
import { ResponseViewer } from './components/ResponseViewer';
import { EnvironmentBar } from './components/EnvironmentBar';
import { QuickOpen } from './components/QuickOpen';
import { SettingsModal } from './components/SettingsModal';
import { CollectionRunner } from './components/CollectionRunner';
import { MockServerPanel } from './components/MockServerPanel';
import { WebSocketPanel } from './components/WebSocketPanel';
import { SSEPanel } from './components/SSEPanel';
import { ResponseDiff } from './components/ResponseDiff';
import { CodeSnippetModal } from './components/CodeSnippetModal';
import { ImportModal } from './components/ImportModal';
import { api } from './api/tauri';
import type { APIRequest } from './types';

type ToolPanel = 'none' | 'runner' | 'mock' | 'websocket' | 'sse' | 'diff';

function WorkspaceSwitcher() {
  const { workspaces, selectedWorkspaceId, selectWorkspace, createWorkspace, deleteWorkspace } = useAppStore();
  const [showDropdown, setShowDropdown] = useState(false);

  const selected = workspaces.find(w => w.id === selectedWorkspaceId);

  const handleNew = async () => {
    const name = prompt('Workspace name:');
    if (name?.trim()) {
      await createWorkspace(name.trim());
    }
    setShowDropdown(false);
  };

  return (
    <div className="relative">
      <button
        onClick={() => setShowDropdown(!showDropdown)}
        className="h-7 flex items-center gap-1.5 px-2 text-sm font-medium text-gray-200 hover:text-white"
      >
        <svg className="w-4 h-4 text-blue-400" viewBox="0 0 16 16" fill="currentColor">
          <rect x="1" y="1" width="6" height="6" rx="1" />
          <rect x="9" y="1" width="6" height="6" rx="1" />
          <rect x="1" y="9" width="6" height="6" rx="1" />
          <rect x="9" y="9" width="6" height="6" rx="1" />
        </svg>
        {selected?.name ?? 'Select Workspace'}
        <svg className="w-3 h-3 text-gray-500" viewBox="0 0 10 10" fill="currentColor">
          <path d="M2 4l3 3 3-3" />
        </svg>
      </button>

      {showDropdown && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setShowDropdown(false)} />
          <div className="absolute left-0 top-full mt-1 bg-gray-900 border border-gray-700 rounded-lg shadow-2xl w-52 z-50 py-1">
            {workspaces.map(ws => (
              <div key={ws.id} className="flex items-center group">
                <button
                  className={clsx(
                    'flex-1 text-left px-3 py-1.5 text-sm hover:bg-gray-800',
                    ws.id === selectedWorkspaceId ? 'text-blue-400' : 'text-gray-300'
                  )}
                  onClick={() => { selectWorkspace(ws.id); setShowDropdown(false); }}
                >
                  {ws.name}
                </button>
                {workspaces.length > 1 && (
                  <button
                    onClick={() => { if (confirm(`Delete workspace "${ws.name}"?`)) deleteWorkspace(ws.id); }}
                    className="opacity-0 group-hover:opacity-100 p-1 text-gray-600 hover:text-red-400"
                  >
                    <svg className="w-3 h-3" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2">
                      <path d="M2 2l6 6M8 2L2 8" strokeLinecap="round" />
                    </svg>
                  </button>
                )}
              </div>
            ))}
            <div className="border-t border-gray-700 mt-1 pt-1">
              <button
                onClick={handleNew}
                className="w-full text-left px-3 py-1.5 text-sm text-blue-400 hover:bg-gray-800 flex items-center gap-2"
              >
                <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M6 1v10M1 6h10" strokeLinecap="round" />
                </svg>
                New Workspace
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function WelcomeScreen({ onImport }: { onImport: () => void }) {
  const { createCollection, createRequest, selectedWorkspaceId, collections } = useAppStore();

  const handleNewRequest = async () => {
    let col = collections[0];
    if (!col && selectedWorkspaceId) {
      col = await createCollection('Default') as any;
    }
    if (col) {
      await createRequest(col.id, 'New Request');
    }
  };

  return (
    <div className="flex flex-col items-center justify-center h-full text-center gap-6">
      <div>
        <div className="w-16 h-16 bg-blue-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <svg className="w-8 h-8 text-white" viewBox="0 0 32 32" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="16" cy="16" r="12" />
            <path d="M10 16h12M16 10l6 6-6 6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        <h1 className="text-2xl font-bold text-white mb-1">API Signals</h1>
        <p className="text-gray-500 text-sm">A modern HTTP API client</p>
      </div>

      <div className="flex flex-col gap-2 w-64">
        <button
          onClick={handleNewRequest}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white py-2.5 rounded-lg text-sm font-medium transition-colors"
        >
          New Request
        </button>
        <button
          onClick={onImport}
          className="w-full bg-gray-800 hover:bg-gray-700 text-gray-300 py-2.5 rounded-lg text-sm border border-gray-700 transition-colors"
        >
          Import Collection
        </button>
      </div>

      <div className="text-xs text-gray-600">
        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded border border-gray-700">⌘K</kbd> Quick Open
        {' · '}
        <kbd className="bg-gray-800 px-1.5 py-0.5 rounded border border-gray-700">⌘⏎</kbd> Send Request
      </div>
    </div>
  );
}

function ToolPanelContainer({ panel, onClose }: { panel: ToolPanel; onClose: () => void }) {
  const panelTitles: Record<ToolPanel, string> = {
    none: '',
    runner: 'Collection Runner',
    mock: 'Mock Server',
    websocket: 'WebSocket',
    sse: 'SSE Stream',
    diff: 'Response Diff',
  };

  if (panel === 'none') return null;

  return (
    <div className="flex flex-col h-full border-t border-gray-700">
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-gray-700 bg-gray-850 shrink-0">
        <span className="text-xs font-medium text-gray-400">{panelTitles[panel]}</span>
        <button onClick={onClose} className="text-gray-600 hover:text-white p-0.5">
          <svg className="w-3.5 h-3.5" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M3 3L9 9M9 3L3 9" strokeLinecap="round" />
          </svg>
        </button>
      </div>
      <div className="flex-1 overflow-hidden">
        {panel === 'runner' && <CollectionRunner />}
        {panel === 'mock' && <MockServerPanel />}
        {panel === 'websocket' && <WebSocketPanel />}
        {panel === 'sse' && <SSEPanel />}
        {panel === 'diff' && <ResponseDiff />}
      </div>
    </div>
  );
}

export default function App() {
  const {
    loadWorkspaces, loadSettings, isSettingsOpen, setSettingsOpen, setQuickOpen,
    isQuickOpenOpen, selectedTabId, tabs,
  } = useAppStore();

  const [toolPanel, setToolPanel] = useState<ToolPanel>('none');
  const [snippetRequest, setSnippetRequest] = useState<APIRequest | null>(null);
  const [showImportModal, setShowImportModal] = useState(false);

  const selectedTab = tabs.find(t => t.id === selectedTabId);

  useEffect(() => {
    loadSettings();
    loadWorkspaces();
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setQuickOpen(true);
      }
      if ((e.metaKey || e.ctrlKey) && e.key === 'w') {
        e.preventDefault();
        const { selectedTabId, closeTab } = useAppStore.getState();
        if (selectedTabId) closeTab(selectedTabId);
      }
      if (e.key === 'Escape' && isQuickOpenOpen) {
        setQuickOpen(false);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isQuickOpenOpen]);

  const toggleToolPanel = (panel: ToolPanel) => {
    setToolPanel(prev => prev === panel ? 'none' : panel);
  };

  return (
    <div className="flex flex-col h-screen bg-gray-900 text-gray-200 overflow-hidden">
      {/* Top bar */}
      <div className="flex items-center h-10 px-3 border-b border-gray-700 bg-gray-900 shrink-0 z-10">
        <WorkspaceSwitcher />

        <div className="flex-1" />

        {/* Tool panel buttons */}
        <div className="flex items-center gap-1 mr-3">
          {[
            { key: 'runner' as ToolPanel, icon: '▶', label: 'Runner' },
            { key: 'mock' as ToolPanel, icon: '⚡', label: 'Mock' },
            { key: 'websocket' as ToolPanel, icon: '⇄', label: 'WS' },
            { key: 'sse' as ToolPanel, icon: '≋', label: 'SSE' },
            { key: 'diff' as ToolPanel, icon: '⟺', label: 'Diff' },
          ].map(({ key, icon, label }) => (
            <button
              key={key}
              onClick={() => toggleToolPanel(key)}
              title={label}
              className={clsx(
                'h-7 px-2 rounded text-xs transition-colors',
                toolPanel === key
                  ? 'bg-blue-700 text-white'
                  : 'text-gray-500 hover:text-gray-300 hover:bg-gray-800'
              )}
            >
              {icon} {label}
            </button>
          ))}
        </div>

        {/* Snippet button */}
        {selectedTab?.request && (
          <button
            onClick={() => setSnippetRequest(selectedTab.request)}
            title="Code Snippet"
            className="h-7 mr-2 px-2 rounded text-xs text-gray-500 hover:text-gray-300 hover:bg-gray-800"
          >
            {'</>'}  Snippet
          </button>
        )}

        <EnvironmentBar />

        {/* Settings */}
        <button
          onClick={() => setSettingsOpen(true)}
          className="h-7 w-7 ml-2 flex items-center justify-center text-gray-500 hover:text-white rounded hover:bg-gray-800"
          title="Settings"
        >
          <svg className="w-4 h-4" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="8" cy="8" r="2.5" />
            <path d="M8 1v1.5M8 13.5V15M1 8h1.5M13.5 8H15M2.93 2.93l1.06 1.06M12.01 12.01l1.06 1.06M2.93 13.07l1.06-1.06M12.01 3.99l1.06-1.06" strokeLinecap="round" />
          </svg>
        </button>
      </div>

      {/* Main content */}
      <div className="flex-1 overflow-hidden">
        <PanelGroup direction="horizontal" className="h-full">
          {/* Sidebar */}
          <Panel defaultSize={20} minSize={15} maxSize={35}>
            <Sidebar />
          </Panel>

          <PanelResizeHandle className="w-px bg-gray-700 hover:bg-blue-500 transition-colors cursor-col-resize" />

          {/* Main area */}
          <Panel defaultSize={80} minSize={50}>
            <div className="flex flex-col h-full">
              <TabBar />

              {selectedTab ? (
                <PanelGroup direction="vertical" className="flex-1">
                  {/* Request + Tool panels area */}
                  <Panel defaultSize={toolPanel !== 'none' ? 45 : 100} minSize={25}>
                    <PanelGroup direction="vertical" className="h-full">
                      <Panel defaultSize={45} minSize={20}>
                        <RequestEditor tabId={selectedTab.id} request={selectedTab.request} />
                      </Panel>

                      <PanelResizeHandle className="h-px bg-gray-700 hover:bg-blue-500 transition-colors cursor-row-resize" />

                      <Panel defaultSize={55} minSize={20}>
                        {selectedTab.isLoading ? (
                          <div className="flex items-center justify-center h-full">
                            <div className="flex flex-col items-center gap-3 text-gray-500">
                              <svg className="w-8 h-8 animate-spin" viewBox="0 0 24 24" fill="none">
                                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" strokeDasharray="50" strokeDashoffset="15"/>
                              </svg>
                              <span className="text-sm">Sending request...</span>
                            </div>
                          </div>
                        ) : selectedTab.response ? (
                          <ResponseViewer response={selectedTab.response} />
                        ) : (
                          <div className="flex items-center justify-center h-full text-gray-600">
                            <div className="text-center">
                              <p className="text-sm mb-1">Send a request to see the response</p>
                              <p className="text-xs">
                                Press <kbd className="bg-gray-800 px-1 rounded border border-gray-700">⌘⏎</kbd> or click Send
                              </p>
                            </div>
                          </div>
                        )}
                      </Panel>
                    </PanelGroup>
                  </Panel>

                  {toolPanel !== 'none' && (
                    <>
                      <PanelResizeHandle className="h-px bg-gray-700 hover:bg-blue-500 transition-colors cursor-row-resize" />
                      <Panel defaultSize={35} minSize={20}>
                        <ToolPanelContainer panel={toolPanel} onClose={() => setToolPanel('none')} />
                      </Panel>
                    </>
                  )}
                </PanelGroup>
              ) : (
                <div className="flex-1 flex flex-col">
                  <WelcomeScreen onImport={() => setShowImportModal(true)} />
                  {toolPanel !== 'none' && (
                    <div className="h-64 border-t border-gray-700">
                      <ToolPanelContainer panel={toolPanel} onClose={() => setToolPanel('none')} />
                    </div>
                  )}
                </div>
              )}
            </div>
          </Panel>
        </PanelGroup>
      </div>

      {/* Modals */}
      {isQuickOpenOpen && <QuickOpen />}
      {isSettingsOpen && <SettingsModal />}
      {snippetRequest && (
        <CodeSnippetModal
          request={snippetRequest}
          onClose={() => setSnippetRequest(null)}
        />
      )}
      {showImportModal && (
        <ImportModal onClose={() => setShowImportModal(false)} />
      )}
    </div>
  );
}
