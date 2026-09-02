import { describe, it, expect, beforeEach, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import type { Workspace, Collection, APIRequest, Environment, HistoryEntry, AppSettings, APIResponse } from '../types';

// ─── Fixtures ─────────────────────────────────────────────────────────────────
const makeWorkspace = (id = 'ws-1', name = 'My Workspace'): Workspace => ({
  id, name, createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
});

const makeCollection = (id = 'col-1', wsId = 'ws-1', name = 'Test Collection'): Collection => ({
  id, workspaceId: wsId, parentId: null, name,
  description: null, sortOrder: 0, createdAt: '', updatedAt: '',
});

const makeRequest = (id = 'req-1', colId = 'col-1', wsId = 'ws-1'): APIRequest => ({
  id, collectionId: colId, workspaceId: wsId,
  name: 'New Request', method: 'GET', url: 'https://example.com',
  headers: [], params: [], body: { type: 'None' }, auth: { type: 'None' },
  preRequestScript: '', postResponseScript: '', description: '',
  sortOrder: 0, createdAt: '', updatedAt: '',
});

const makeEnv = (id = 'env-1', wsId = 'ws-1'): Environment => ({
  id, workspaceId: wsId, name: 'Production',
  variables: [
    { id: 'v1', key: 'BASE_URL', value: 'https://api.example.com', enabled: true, secret: false },
  ],
  isActive: false, createdAt: '', updatedAt: '',
});

const makeResponse = (): APIResponse => ({
  status: 200, statusText: 'OK',
  headers: [{ id: 'h1', key: 'content-type', value: 'application/json', enabled: true }],
  body: '{"ok":true}', bodySize: 11,
  timing: { dnsMs: 5, connectMs: 15, tlsMs: 20, sendMs: 3, waitMs: 80, receiveMs: 10, totalMs: 133 },
  cookies: [],
});

// ─── Helper: fresh store instance ─────────────────────────────────────────────
async function freshStore() {
  // Re-import store fresh each time so Zustand state doesn't leak between tests
  vi.resetModules();
  const { useAppStore } = await import('../store/appStore');
  return useAppStore.getState();
}

// ─── Tests ────────────────────────────────────────────────────────────────────
describe('AppStore: loadWorkspaces', () => {
  beforeEach(() => {
    vi.mocked(invoke).mockReset();
  });

  it('loads workspaces and auto-selects first', async () => {
    const ws1 = makeWorkspace('ws-1', 'First');
    const ws2 = makeWorkspace('ws-2', 'Second');
    vi.mocked(invoke)
      .mockResolvedValueOnce([ws1, ws2])   // get_workspaces
      .mockResolvedValueOnce([])            // get_collections
      .mockResolvedValueOnce([])            // get_environments
      .mockResolvedValueOnce([])            // get_history
      .mockResolvedValueOnce([]);           // get_all_requests

    const store = await freshStore();
    await store.loadWorkspaces();
    const state = (await import('../store/appStore')).useAppStore.getState();

    expect(state.workspaces).toHaveLength(2);
    expect(state.selectedWorkspaceId).toBe('ws-1');
  });

  it('handles empty workspace list gracefully', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    const store = await freshStore();
    await store.loadWorkspaces();
    const state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.workspaces).toHaveLength(0);
    expect(state.selectedWorkspaceId).toBeNull();
  });
});

describe('AppStore: Tab management', () => {
  it('openTab adds a new tab and selects it', async () => {
    const store = await freshStore();
    const req = makeRequest();
    store.openTab(req);

    const state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs).toHaveLength(1);
    expect(state.selectedTabId).toBe(state.tabs[0].id);
    expect(state.tabs[0].request.id).toBe(req.id);
  });

  it('openTab does not duplicate if same request is opened twice', async () => {
    const store = await freshStore();
    const req = makeRequest();
    store.openTab(req);
    store.openTab(req);

    const state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs).toHaveLength(1);
  });

  it('closeTab removes tab and selects adjacent', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));
    store.openTab(makeRequest('req-2'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const firstTabId = state.tabs[0].id;
    const secondTabId = state.tabs[1].id;
    state.closeTab(firstTabId);

    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs).toHaveLength(1);
    expect(state.selectedTabId).toBe(secondTabId);
  });

  it('closeTab on last tab sets selectedTabId to null', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const tabId = state.tabs[0].id;
    state.closeTab(tabId);

    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs).toHaveLength(0);
    expect(state.selectedTabId).toBeNull();
  });

  it('selectTab sets selectedTabId', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));
    store.openTab(makeRequest('req-2'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const firstId = state.tabs[0].id;
    state.selectTab(firstId);

    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.selectedTabId).toBe(firstId);
  });

  it('updateTabRequest marks tab as dirty', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const tabId = state.tabs[0].id;
    state.updateTabRequest(tabId, { method: 'POST' });

    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs[0].isDirty).toBe(true);
    expect(state.tabs[0].request.method).toBe('POST');
  });

  it('updateTabResponse stores response on tab', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const tabId = state.tabs[0].id;
    const resp = makeResponse();
    state.updateTabResponse(tabId, resp);

    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs[0].response?.status).toBe(200);
  });

  it('setTabLoading toggles isLoading', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const tabId = state.tabs[0].id;
    state.setTabLoading(tabId, true);

    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs[0].isLoading).toBe(true);

    state.setTabLoading(tabId, false);
    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs[0].isLoading).toBe(false);
  });

  it('markTabDirty sets dirty flag explicitly', async () => {
    const store = await freshStore();
    store.openTab(makeRequest('req-1'));

    let state = (await import('../store/appStore')).useAppStore.getState();
    const tabId = state.tabs[0].id;
    state.markTabDirty(tabId, true);
    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs[0].isDirty).toBe(true);

    state.markTabDirty(tabId, false);
    state = (await import('../store/appStore')).useAppStore.getState();
    expect(state.tabs[0].isDirty).toBe(false);
  });
});

describe('AppStore: createCollection', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('creates collection and appends to list', async () => {
    const store = await freshStore();
    // Manually set workspace
    (await import('../store/appStore')).useAppStore.setState({
      selectedWorkspaceId: 'ws-1',
      collections: [],
    });

    const col = makeCollection();
    vi.mocked(invoke).mockResolvedValueOnce(col);

    const state = (await import('../store/appStore')).useAppStore.getState();
    await state.createCollection('Test Collection');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.collections).toHaveLength(1);
    expect(after.collections[0].name).toBe('Test Collection');
  });

  it('returns null if no workspace selected', async () => {
    (await import('../store/appStore')).useAppStore.setState({ selectedWorkspaceId: null });
    const state = (await import('../store/appStore')).useAppStore.getState();
    const result = await state.createCollection('Foo');
    expect(result).toBeNull();
  });
});

describe('AppStore: deleteCollection', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('removes collection and its requests', async () => {
    (await import('../store/appStore')).useAppStore.setState({
      collections: [makeCollection('col-1'), makeCollection('col-2')],
      requestsByCollection: { 'col-1': [makeRequest()], 'col-2': [] },
    });
    vi.mocked(invoke).mockResolvedValueOnce(undefined);

    const state = (await import('../store/appStore')).useAppStore.getState();
    await state.deleteCollection('col-1');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.collections).toHaveLength(1);
    expect(after.collections[0].id).toBe('col-2');
    expect(after.requestsByCollection['col-1']).toBeUndefined();
  });
});

describe('AppStore: createRequest', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('creates request, appends to collection, and opens tab', async () => {
    (await import('../store/appStore')).useAppStore.setState({
      selectedWorkspaceId: 'ws-1',
      collections: [makeCollection()],
      requestsByCollection: {},
      tabs: [],
      selectedTabId: null,
    });

    const req = makeRequest();
    vi.mocked(invoke).mockResolvedValueOnce(req);

    const state = (await import('../store/appStore')).useAppStore.getState();
    await state.createRequest('col-1', 'New Request');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.requestsByCollection['col-1']).toHaveLength(1);
    expect(after.tabs).toHaveLength(1);
    expect(after.selectedTabId).toBe(after.tabs[0].id);
  });
});

describe('AppStore: deleteRequest', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('removes request from collection and closes its tab', async () => {
    const req = makeRequest('req-1');
    (await import('../store/appStore')).useAppStore.setState({
      requestsByCollection: { 'col-1': [req] },
      tabs: [],
    });
    // Open the tab first
    (await import('../store/appStore')).useAppStore.getState().openTab(req);

    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await (await import('../store/appStore')).useAppStore.getState().deleteRequest('req-1');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.requestsByCollection['col-1']).toHaveLength(0);
    expect(after.tabs.some(t => t.requestId === 'req-1')).toBe(false);
  });
});

describe('AppStore: Environments', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('setActiveEnvironment updates activeEnvironmentId and isActive flags', async () => {
    const env1 = makeEnv('env-1');
    const env2 = { ...makeEnv('env-2'), name: 'Staging' };
    (await import('../store/appStore')).useAppStore.setState({
      selectedWorkspaceId: 'ws-1',
      environments: [env1, env2],
      activeEnvironmentId: null,
    });

    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await (await import('../store/appStore')).useAppStore.getState().setActiveEnvironment('env-2');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.activeEnvironmentId).toBe('env-2');
    expect(after.environments.find(e => e.id === 'env-2')?.isActive).toBe(true);
    expect(after.environments.find(e => e.id === 'env-1')?.isActive).toBe(false);
  });

  it('setActiveEnvironment to null clears active env', async () => {
    (await import('../store/appStore')).useAppStore.setState({
      selectedWorkspaceId: 'ws-1',
      environments: [{ ...makeEnv(), isActive: true }],
      activeEnvironmentId: 'env-1',
    });
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await (await import('../store/appStore')).useAppStore.getState().setActiveEnvironment(null);

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.activeEnvironmentId).toBeNull();
  });

  it('deleteEnvironment removes env from list', async () => {
    (await import('../store/appStore')).useAppStore.setState({
      environments: [makeEnv('env-1'), { ...makeEnv('env-2'), name: 'Dev' }],
      activeEnvironmentId: null,
    });
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await (await import('../store/appStore')).useAppStore.getState().deleteEnvironment('env-1');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.environments).toHaveLength(1);
    expect(after.environments[0].id).toBe('env-2');
  });

  it('deleteEnvironment resets activeEnvironmentId when deleting active env', async () => {
    (await import('../store/appStore')).useAppStore.setState({
      environments: [{ ...makeEnv('env-1'), isActive: true }],
      activeEnvironmentId: 'env-1',
    });
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await (await import('../store/appStore')).useAppStore.getState().deleteEnvironment('env-1');

    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.activeEnvironmentId).toBeNull();
  });
});

describe('AppStore: UI state', () => {
  it('setQuickOpen toggles isQuickOpenOpen', async () => {
    const store = await freshStore();
    store.setQuickOpen(true);
    expect((await import('../store/appStore')).useAppStore.getState().isQuickOpenOpen).toBe(true);
    store.setQuickOpen(false);
    expect((await import('../store/appStore')).useAppStore.getState().isQuickOpenOpen).toBe(false);
  });

  it('setSettingsOpen toggles isSettingsOpen', async () => {
    const store = await freshStore();
    store.setSettingsOpen(true);
    expect((await import('../store/appStore')).useAppStore.getState().isSettingsOpen).toBe(true);
  });

  it('setSidebarSection sets section', async () => {
    const store = await freshStore();
    store.setSidebarSection('history');
    expect((await import('../store/appStore')).useAppStore.getState().sidebarSection).toBe('history');
    store.setSidebarSection('collections');
    expect((await import('../store/appStore')).useAppStore.getState().sidebarSection).toBe('collections');
  });

  it('setSearchQuery updates searchQuery', async () => {
    const store = await freshStore();
    store.setSearchQuery('foo');
    expect((await import('../store/appStore')).useAppStore.getState().searchQuery).toBe('foo');
  });
});

describe('AppStore: History', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('loadHistory calls get_history with workspaceId', async () => {
    (await import('../store/appStore')).useAppStore.setState({ selectedWorkspaceId: 'ws-1' });
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await (await import('../store/appStore')).useAppStore.getState().loadHistory();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_history', { workspaceId: 'ws-1', limit: 200 });
  });

  it('clearHistory empties history list', async () => {
    const entry: HistoryEntry = {
      id: 'h1', workspaceId: 'ws-1', requestName: 'Test',
      method: 'GET', url: 'https://x.com', status: 200,
      durationMs: 100, responseSize: 50,
      timestamp: '', requestSnapshot: '', responseSnapshot: '',
    };
    (await import('../store/appStore')).useAppStore.setState({
      selectedWorkspaceId: 'ws-1',
      history: [entry],
    });
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await (await import('../store/appStore')).useAppStore.getState().clearHistory();
    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.history).toHaveLength(0);
  });
});

describe('AppStore: Settings', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('loadSettings applies settings from backend', async () => {
    const settings: AppSettings = {
      theme: 'light', timeoutMs: 5000, sslVerify: false,
      proxyUrl: null, followRedirects: true, maxRedirects: 5,
    };
    vi.mocked(invoke).mockResolvedValueOnce(settings);
    await (await import('../store/appStore')).useAppStore.getState().loadSettings();
    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.settings.theme).toBe('light');
    expect(after.settings.timeoutMs).toBe(5000);
  });

  it('updateSettings persists and applies returned settings', async () => {
    const newSettings: AppSettings = {
      theme: 'dark', timeoutMs: 60000, sslVerify: true,
      proxyUrl: 'http://proxy:8080', followRedirects: false, maxRedirects: 3,
    };
    vi.mocked(invoke).mockResolvedValueOnce(newSettings);
    await (await import('../store/appStore')).useAppStore.getState().updateSettings(newSettings);
    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.settings.proxyUrl).toBe('http://proxy:8080');
    expect(after.settings.followRedirects).toBe(false);
  });
});

describe('AppStore: deleteWorkspace', () => {
  beforeEach(() => vi.mocked(invoke).mockReset());

  it('removes workspace and selects another', async () => {
    const ws1 = makeWorkspace('ws-1', 'First');
    const ws2 = makeWorkspace('ws-2', 'Second');
    (await import('../store/appStore')).useAppStore.setState({
      workspaces: [ws1, ws2],
      selectedWorkspaceId: 'ws-1',
    });
    vi.mocked(invoke)
      .mockResolvedValueOnce(undefined)  // delete_workspace
      .mockResolvedValueOnce([])         // get_collections
      .mockResolvedValueOnce([])         // get_environments
      .mockResolvedValueOnce([])         // get_history
      .mockResolvedValueOnce([]);        // get_all_requests

    await (await import('../store/appStore')).useAppStore.getState().deleteWorkspace('ws-1');
    const after = (await import('../store/appStore')).useAppStore.getState();
    expect(after.workspaces).toHaveLength(1);
    expect(after.selectedWorkspaceId).toBe('ws-2');
  });
});
