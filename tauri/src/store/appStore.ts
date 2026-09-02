import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';
import type {
  Workspace, Collection, APIRequest, Environment, HistoryEntry,
  AppSettings, Tab, APIResponse,
} from '../types';
import { api } from '../api/tauri';
import { uuid } from '../utils/uuid';

interface AppState {
  // Workspaces
  workspaces: Workspace[];
  selectedWorkspaceId: string | null;

  // Collections (keyed by workspaceId, but we flatten for the selected workspace)
  collections: Collection[];

  // Requests (keyed by collectionId)
  requestsByCollection: Record<string, APIRequest[]>;

  // Tabs
  tabs: Tab[];
  selectedTabId: string | null;

  // Environments
  environments: Environment[];
  activeEnvironmentId: string | null;

  // History
  history: HistoryEntry[];

  // Settings
  settings: AppSettings;

  // UI state
  sidebarSection: 'collections' | 'history';
  isQuickOpenOpen: boolean;
  isSettingsOpen: boolean;
  searchQuery: string;

  // Computed
  selectedWorkspace: Workspace | null;
  selectedTab: Tab | null;
  activeEnvironment: Environment | null;

  // Actions: workspaces
  loadWorkspaces: () => Promise<void>;
  selectWorkspace: (id: string) => Promise<void>;
  createWorkspace: (name: string) => Promise<void>;
  updateWorkspace: (id: string, name: string) => Promise<void>;
  deleteWorkspace: (id: string) => Promise<void>;

  // Actions: collections
  loadCollections: (workspaceId: string) => Promise<void>;
  createCollection: (name: string, parentId?: string | null) => Promise<Collection | null>;
  updateCollection: (id: string, name: string, description?: string | null) => Promise<void>;
  deleteCollection: (id: string) => Promise<void>;

  // Actions: requests
  loadRequests: (collectionId: string) => Promise<void>;
  loadAllRequests: () => Promise<void>;
  createRequest: (collectionId: string, name?: string) => Promise<APIRequest | null>;
  saveRequest: (request: APIRequest) => Promise<void>;
  deleteRequest: (id: string) => Promise<void>;
  duplicateRequest: (id: string) => Promise<void>;

  // Actions: tabs
  openTab: (request: APIRequest) => void;
  closeTab: (tabId: string) => void;
  selectTab: (tabId: string) => void;
  updateTabRequest: (tabId: string, request: Partial<APIRequest>) => void;
  updateTabResponse: (tabId: string, response: APIResponse | null) => void;
  setTabLoading: (tabId: string, isLoading: boolean) => void;
  markTabDirty: (tabId: string, dirty: boolean) => void;

  // Actions: environments
  loadEnvironments: (workspaceId: string) => Promise<void>;
  createEnvironment: (name: string) => Promise<void>;
  updateEnvironment: (env: Environment) => Promise<void>;
  deleteEnvironment: (id: string) => Promise<void>;
  setActiveEnvironment: (envId: string | null) => Promise<void>;

  // Actions: history
  loadHistory: () => Promise<void>;
  clearHistory: () => Promise<void>;

  // Actions: settings
  loadSettings: () => Promise<void>;
  updateSettings: (settings: AppSettings) => Promise<void>;

  // Actions: UI
  setSidebarSection: (section: 'collections' | 'history') => void;
  setQuickOpen: (open: boolean) => void;
  setSettingsOpen: (open: boolean) => void;
  setSearchQuery: (q: string) => void;
}

export const useAppStore = create<AppState>()(
  subscribeWithSelector((set, get) => ({
    workspaces: [],
    selectedWorkspaceId: null,
    collections: [],
    requestsByCollection: {},
    tabs: [],
    selectedTabId: null,
    environments: [],
    activeEnvironmentId: null,
    history: [],
    settings: {
      theme: 'dark',
      timeoutMs: 30000,
      sslVerify: true,
      proxyUrl: null,
      followRedirects: true,
      maxRedirects: 10,
    },
    sidebarSection: 'collections',
    isQuickOpenOpen: false,
    isSettingsOpen: false,
    searchQuery: '',

    get selectedWorkspace() {
      const state = get();
      return state.workspaces.find(w => w.id === state.selectedWorkspaceId) ?? null;
    },
    get selectedTab() {
      const state = get();
      return state.tabs.find(t => t.id === state.selectedTabId) ?? null;
    },
    get activeEnvironment() {
      const state = get();
      return state.environments.find(e => e.id === state.activeEnvironmentId) ?? null;
    },

    // ─── Workspaces ────────────────────────────────────────────────────────
    loadWorkspaces: async () => {
      const workspaces = await api.getWorkspaces();
      set({ workspaces });
      if (workspaces.length > 0) {
        const currentId = get().selectedWorkspaceId;
        if (!currentId || !workspaces.find(w => w.id === currentId)) {
          await get().selectWorkspace(workspaces[0].id);
        }
      }
    },

    selectWorkspace: async (id: string) => {
      set({ selectedWorkspaceId: id, collections: [], requestsByCollection: {}, environments: [], history: [] });
      await Promise.all([
        get().loadCollections(id),
        get().loadEnvironments(id),
        get().loadHistory(),
        get().loadAllRequests(),
      ]);
    },

    createWorkspace: async (name: string) => {
      const ws = await api.createWorkspace(name);
      set(s => ({ workspaces: [...s.workspaces, ws] }));
      await get().selectWorkspace(ws.id);
    },

    updateWorkspace: async (id: string, name: string) => {
      const ws = await api.updateWorkspace(id, name);
      set(s => ({ workspaces: s.workspaces.map(w => w.id === id ? ws : w) }));
    },

    deleteWorkspace: async (id: string) => {
      await api.deleteWorkspace(id);
      const state = get();
      const remaining = state.workspaces.filter(w => w.id !== id);
      set({ workspaces: remaining });
      if (state.selectedWorkspaceId === id) {
        if (remaining.length > 0) {
          await get().selectWorkspace(remaining[0].id);
        } else {
          set({ selectedWorkspaceId: null, collections: [], requestsByCollection: {} });
        }
      }
    },

    // ─── Collections ────────────────────────────────────────────────────────
    loadCollections: async (workspaceId: string) => {
      const collections = await api.getCollections(workspaceId);
      set({ collections });
    },

    createCollection: async (name: string, parentId?: string | null) => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return null;
      const col = await api.createCollection(wsId, name, parentId);
      set(s => ({ collections: [...s.collections, col] }));
      return col;
    },

    updateCollection: async (id: string, name: string, description?: string | null) => {
      const col = await api.updateCollection(id, name, description);
      set(s => ({ collections: s.collections.map(c => c.id === id ? col : c) }));
    },

    deleteCollection: async (id: string) => {
      await api.deleteCollection(id);
      set(s => ({
        collections: s.collections.filter(c => c.id !== id),
        requestsByCollection: Object.fromEntries(
          Object.entries(s.requestsByCollection).filter(([k]) => k !== id)
        ),
      }));
    },

    // ─── Requests ────────────────────────────────────────────────────────────
    loadRequests: async (collectionId: string) => {
      const requests = await api.getRequests(collectionId);
      set(s => ({ requestsByCollection: { ...s.requestsByCollection, [collectionId]: requests } }));
    },

    loadAllRequests: async () => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return;
      const all = await api.getAllRequests(wsId);
      const byCollection: Record<string, APIRequest[]> = {};
      for (const req of all) {
        if (!byCollection[req.collectionId]) byCollection[req.collectionId] = [];
        byCollection[req.collectionId].push(req);
      }
      set({ requestsByCollection: byCollection });
    },

    createRequest: async (collectionId: string, name = 'New Request') => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return null;
      const req = await api.createRequest(collectionId, wsId, name);
      set(s => ({
        requestsByCollection: {
          ...s.requestsByCollection,
          [collectionId]: [...(s.requestsByCollection[collectionId] ?? []), req],
        },
      }));
      get().openTab(req);
      return req;
    },

    saveRequest: async (request: APIRequest) => {
      const saved = await api.updateRequest(request);
      set(s => {
        const cid = request.collectionId;
        const col = (s.requestsByCollection[cid] ?? []).map(r => r.id === request.id ? saved : r);
        const tabs = s.tabs.map(t => t.requestId === request.id ? { ...t, request: saved, isDirty: false } : t);
        return { requestsByCollection: { ...s.requestsByCollection, [cid]: col }, tabs };
      });
    },

    deleteRequest: async (id: string) => {
      await api.deleteRequest(id);
      set(s => {
        const newByCol = { ...s.requestsByCollection };
        for (const cid in newByCol) {
          newByCol[cid] = newByCol[cid].filter(r => r.id !== id);
        }
        const tabs = s.tabs.filter(t => t.requestId !== id);
        const selectedTabId = tabs.find(t => t.id === s.selectedTabId)
          ? s.selectedTabId
          : (tabs[tabs.length - 1]?.id ?? null);
        return { requestsByCollection: newByCol, tabs, selectedTabId };
      });
    },

    duplicateRequest: async (id: string) => {
      const req = await api.duplicateRequest(id);
      set(s => ({
        requestsByCollection: {
          ...s.requestsByCollection,
          [req.collectionId]: [...(s.requestsByCollection[req.collectionId] ?? []), req],
        },
      }));
      get().openTab(req);
    },

    // ─── Tabs ─────────────────────────────────────────────────────────────────
    openTab: (request: APIRequest) => {
      set(s => {
        const existing = s.tabs.find(t => t.requestId === request.id);
        if (existing) {
          return { selectedTabId: existing.id };
        }
        const tab: Tab = {
          id: uuid(),
          requestId: request.id,
          isDirty: false,
          request,
          response: null,
          isLoading: false,
        };
        return { tabs: [...s.tabs, tab], selectedTabId: tab.id };
      });
    },

    closeTab: (tabId: string) => {
      set(s => {
        const idx = s.tabs.findIndex(t => t.id === tabId);
        const tabs = s.tabs.filter(t => t.id !== tabId);
        let selectedTabId = s.selectedTabId;
        if (selectedTabId === tabId) {
          if (tabs.length === 0) {
            selectedTabId = null;
          } else {
            const nextIdx = Math.min(idx, tabs.length - 1);
            selectedTabId = tabs[nextIdx].id;
          }
        }
        return { tabs, selectedTabId };
      });
    },

    selectTab: (tabId: string) => set({ selectedTabId: tabId }),

    updateTabRequest: (tabId: string, partial: Partial<APIRequest>) => {
      set(s => ({
        tabs: s.tabs.map(t =>
          t.id === tabId
            ? { ...t, request: { ...t.request, ...partial }, isDirty: true }
            : t
        ),
      }));
    },

    updateTabResponse: (tabId: string, response: APIResponse | null) => {
      set(s => ({
        tabs: s.tabs.map(t => t.id === tabId ? { ...t, response } : t),
      }));
    },

    setTabLoading: (tabId: string, isLoading: boolean) => {
      set(s => ({
        tabs: s.tabs.map(t => t.id === tabId ? { ...t, isLoading } : t),
      }));
    },

    markTabDirty: (tabId: string, dirty: boolean) => {
      set(s => ({
        tabs: s.tabs.map(t => t.id === tabId ? { ...t, isDirty: dirty } : t),
      }));
    },

    // ─── Environments ─────────────────────────────────────────────────────────
    loadEnvironments: async (workspaceId: string) => {
      const envs = await api.getEnvironments(workspaceId);
      const activeId = envs.find(e => e.isActive)?.id ?? null;
      set({ environments: envs, activeEnvironmentId: activeId });
    },

    createEnvironment: async (name: string) => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return;
      const env = await api.createEnvironment(wsId, name);
      set(s => ({ environments: [...s.environments, env] }));
    },

    updateEnvironment: async (env: Environment) => {
      const updated = await api.updateEnvironment(env);
      set(s => ({ environments: s.environments.map(e => e.id === env.id ? updated : e) }));
    },

    deleteEnvironment: async (id: string) => {
      await api.deleteEnvironment(id);
      set(s => {
        const envs = s.environments.filter(e => e.id !== id);
        return {
          environments: envs,
          activeEnvironmentId: s.activeEnvironmentId === id ? null : s.activeEnvironmentId,
        };
      });
    },

    setActiveEnvironment: async (envId: string | null) => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return;
      await api.setActiveEnvironment(wsId, envId);
      set(s => ({
        activeEnvironmentId: envId,
        environments: s.environments.map(e => ({ ...e, isActive: e.id === envId })),
      }));
    },

    // ─── History ──────────────────────────────────────────────────────────────
    loadHistory: async () => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return;
      const history = await api.getHistory(wsId, 200);
      set({ history });
    },

    clearHistory: async () => {
      const wsId = get().selectedWorkspaceId;
      if (!wsId) return;
      await api.clearHistory(wsId);
      set({ history: [] });
    },

    // ─── Settings ─────────────────────────────────────────────────────────────
    loadSettings: async () => {
      const settings = await api.getSettings();
      set({ settings });
      applyTheme(settings.theme);
    },

    updateSettings: async (settings: AppSettings) => {
      const saved = await api.updateSettings(settings);
      set({ settings: saved });
      applyTheme(saved.theme);
    },

    // ─── UI ───────────────────────────────────────────────────────────────────
    setSidebarSection: (section) => set({ sidebarSection: section }),
    setQuickOpen: (open) => set({ isQuickOpenOpen: open }),
    setSettingsOpen: (open) => set({ isSettingsOpen: open }),
    setSearchQuery: (q) => set({ searchQuery: q }),
  }))
);

function applyTheme(theme: string) {
  if (theme === 'dark') {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
}
