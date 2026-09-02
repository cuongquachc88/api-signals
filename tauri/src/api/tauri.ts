import { invoke } from '@tauri-apps/api/core';
import type {
  Workspace, Collection, APIRequest, Environment, HistoryEntry,
  MockRoute, AppSettings, APIResponse, PostmanImportResult,
  ExecuteRequestOptions,
} from '../types';

// ─── Workspaces ───────────────────────────────────────────────────────────────
export const api = {
  // Workspace
  getWorkspaces: () => invoke<Workspace[]>('get_workspaces'),
  createWorkspace: (name: string) => invoke<Workspace>('create_workspace', { name }),
  updateWorkspace: (id: string, name: string) => invoke<Workspace>('update_workspace', { id, name }),
  deleteWorkspace: (id: string) => invoke<void>('delete_workspace', { id }),

  // Collections
  getCollections: (workspaceId: string) => invoke<Collection[]>('get_collections', { workspaceId }),
  createCollection: (workspaceId: string, name: string, parentId?: string | null) =>
    invoke<Collection>('create_collection', { workspaceId, name, parentId: parentId ?? null }),
  updateCollection: (id: string, name: string, description?: string | null, parentId?: string | null) =>
    invoke<Collection>('update_collection', { id, name, description: description ?? null, parentId: parentId ?? null }),
  deleteCollection: (id: string) => invoke<void>('delete_collection', { id }),
  reorderCollection: (id: string, sortOrder: number) => invoke<void>('reorder_collection', { id, sortOrder }),

  // Requests
  getRequests: (collectionId: string) => invoke<APIRequest[]>('get_requests', { collectionId }),
  getAllRequests: (workspaceId: string) => invoke<APIRequest[]>('get_all_requests', { workspaceId }),
  createRequest: (collectionId: string, workspaceId: string, name: string) =>
    invoke<APIRequest>('create_request', { collectionId, workspaceId, name }),
  updateRequest: (request: APIRequest) => invoke<APIRequest>('update_request', { request }),
  deleteRequest: (id: string) => invoke<void>('delete_request', { id }),
  duplicateRequest: (id: string) => invoke<APIRequest>('duplicate_request', { id }),

  // Environments
  getEnvironments: (workspaceId: string) => invoke<Environment[]>('get_environments', { workspaceId }),
  createEnvironment: (workspaceId: string, name: string) =>
    invoke<Environment>('create_environment', { workspaceId, name }),
  updateEnvironment: (environment: Environment) => invoke<Environment>('update_environment', { environment }),
  deleteEnvironment: (id: string) => invoke<void>('delete_environment', { id }),
  setActiveEnvironment: (workspaceId: string, environmentId?: string | null) =>
    invoke<void>('set_active_environment', { workspaceId, environmentId: environmentId ?? null }),

  // History
  getHistory: (workspaceId: string, limit?: number) =>
    invoke<HistoryEntry[]>('get_history', { workspaceId, limit: limit ?? null }),
  addHistoryEntry: (entry: HistoryEntry) => invoke<void>('add_history_entry', { entry }),
  clearHistory: (workspaceId: string) => invoke<void>('clear_history', { workspaceId }),
  deleteHistoryEntry: (id: string) => invoke<void>('delete_history_entry', { id }),

  // HTTP
  executeRequest: (request: APIRequest, options?: ExecuteRequestOptions) =>
    invoke<APIResponse>('execute_request', { request, options: options ?? null }),

  // Mock server
  getMockRoutes: () => invoke<MockRoute[]>('get_mock_routes'),
  addMockRoute: (method: string, path: string) => invoke<MockRoute>('add_mock_route', { method, path }),
  updateMockRoute: (route: MockRoute) => invoke<MockRoute>('update_mock_route', { route }),
  deleteMockRoute: (id: string) => invoke<void>('delete_mock_route', { id }),
  startMockServer: (port: number) => invoke<string>('start_mock_server', { port }),
  stopMockServer: () => invoke<void>('stop_mock_server'),
  getMockServerStatus: () => invoke<boolean>('get_mock_server_status'),

  // Import/Export
  importCurl: (curlString: string) => invoke<APIRequest>('import_curl', { curlString }),
  exportCurl: (request: APIRequest) => invoke<string>('export_curl', { request }),
  importPostman: (jsonString: string, workspaceId: string, collectionId: string) =>
    invoke<PostmanImportResult>('import_postman', { jsonString, workspaceId, collectionId }),
  exportPostman: (collectionName: string, requests: APIRequest[]) =>
    invoke<string>('export_postman', { collectionName, requests }),
  importHar: (jsonString: string, workspaceId: string, collectionId: string) =>
    invoke<APIRequest[]>('import_har', { jsonString, workspaceId, collectionId }),
  importOpenapi: (jsonString: string, workspaceId: string, collectionId: string) =>
    invoke<APIRequest[]>('import_openapi', { jsonString, workspaceId, collectionId }),

  // Snippets
  generateSnippet: (language: string, request: APIRequest) =>
    invoke<string>('generate_snippet', { language, request }),

  // Settings
  getSettings: () => invoke<AppSettings>('get_settings'),
  updateSettings: (settings: AppSettings) => invoke<AppSettings>('update_settings', { settings }),
};
