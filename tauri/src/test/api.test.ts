import { describe, it, expect, beforeEach, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import { api } from '../api/tauri';
import type { APIRequest, AppSettings } from '../types';

beforeEach(() => vi.mocked(invoke).mockReset());

const makeRequest = (id = 'req-1'): APIRequest => ({
  id, collectionId: 'col-1', workspaceId: 'ws-1',
  name: 'Test', method: 'GET', url: 'https://example.com',
  headers: [], params: [], body: { type: 'None' }, auth: { type: 'None' },
  preRequestScript: '', postResponseScript: '', description: '',
  sortOrder: 0, createdAt: '', updatedAt: '',
});

describe('api.getWorkspaces', () => {
  it('invokes get_workspaces', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getWorkspaces();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_workspaces');
  });
});

describe('api.createWorkspace', () => {
  it('passes name to create_workspace', async () => {
    vi.mocked(invoke).mockResolvedValueOnce({ id: 'ws-1', name: 'Test', createdAt: '', updatedAt: '' });
    await api.createWorkspace('Test');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('create_workspace', { name: 'Test' });
  });
});

describe('api.updateWorkspace', () => {
  it('passes id and name to update_workspace', async () => {
    vi.mocked(invoke).mockResolvedValueOnce({});
    await api.updateWorkspace('ws-1', 'Renamed');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('update_workspace', { id: 'ws-1', name: 'Renamed' });
  });
});

describe('api.deleteWorkspace', () => {
  it('passes id to delete_workspace', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await api.deleteWorkspace('ws-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('delete_workspace', { id: 'ws-1' });
  });
});

describe('api.getCollections', () => {
  it('passes workspaceId to get_collections', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getCollections('ws-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_collections', { workspaceId: 'ws-1' });
  });
});

describe('api.createCollection', () => {
  it('passes workspaceId, name, parentId to create_collection', async () => {
    vi.mocked(invoke).mockResolvedValueOnce({});
    await api.createCollection('ws-1', 'My Col', null);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('create_collection', {
      workspaceId: 'ws-1', name: 'My Col', parentId: null,
    });
  });

  it('defaults parentId to null when undefined', async () => {
    vi.mocked(invoke).mockResolvedValueOnce({});
    await api.createCollection('ws-1', 'Col');
    const call = vi.mocked(invoke).mock.calls[0];
    expect((call[1] as any).parentId).toBeNull();
  });
});

describe('api.getRequests', () => {
  it('passes collectionId to get_requests', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getRequests('col-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_requests', { collectionId: 'col-1' });
  });
});

describe('api.getAllRequests', () => {
  it('passes workspaceId to get_all_requests', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getAllRequests('ws-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_all_requests', { workspaceId: 'ws-1' });
  });
});

describe('api.createRequest', () => {
  it('passes collectionId, workspaceId, name to create_request', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(makeRequest());
    await api.createRequest('col-1', 'ws-1', 'New Request');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('create_request', {
      collectionId: 'col-1', workspaceId: 'ws-1', name: 'New Request',
    });
  });
});

describe('api.updateRequest', () => {
  it('passes entire request to update_request', async () => {
    const req = makeRequest();
    vi.mocked(invoke).mockResolvedValueOnce(req);
    await api.updateRequest(req);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('update_request', { request: req });
  });
});

describe('api.deleteRequest', () => {
  it('passes id to delete_request', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await api.deleteRequest('req-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('delete_request', { id: 'req-1' });
  });
});

describe('api.duplicateRequest', () => {
  it('passes id to duplicate_request', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(makeRequest('req-copy'));
    const result = await api.duplicateRequest('req-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('duplicate_request', { id: 'req-1' });
    expect((result as APIRequest).id).toBe('req-copy');
  });
});

describe('api.getEnvironments', () => {
  it('passes workspaceId to get_environments', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getEnvironments('ws-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_environments', { workspaceId: 'ws-1' });
  });
});

describe('api.setActiveEnvironment', () => {
  it('passes workspaceId and environmentId', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await api.setActiveEnvironment('ws-1', 'env-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('set_active_environment', {
      workspaceId: 'ws-1', environmentId: 'env-1',
    });
  });

  it('passes null environmentId to deactivate', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await api.setActiveEnvironment('ws-1', null);
    const call = vi.mocked(invoke).mock.calls[0];
    expect((call[1] as any).environmentId).toBeNull();
  });
});

describe('api.getHistory', () => {
  it('passes workspaceId and limit to get_history', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getHistory('ws-1', 50);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_history', { workspaceId: 'ws-1', limit: 50 });
  });

  it('defaults limit to null when not provided', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getHistory('ws-1');
    const call = vi.mocked(invoke).mock.calls[0];
    expect((call[1] as any).limit).toBeNull();
  });
});

describe('api.clearHistory', () => {
  it('passes workspaceId to clear_history', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await api.clearHistory('ws-1');
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('clear_history', { workspaceId: 'ws-1' });
  });
});

describe('api.executeRequest', () => {
  it('passes request and options to execute_request', async () => {
    const req = makeRequest();
    const resp = { status: 200, statusText: 'OK', headers: [], body: '', bodySize: 0, timing: {}, cookies: [] };
    vi.mocked(invoke).mockResolvedValueOnce(resp);
    await api.executeRequest(req, { timeoutMs: 5000, sslVerify: true });
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('execute_request', {
      request: req,
      options: { timeoutMs: 5000, sslVerify: true },
    });
  });

  it('passes null options when not provided', async () => {
    vi.mocked(invoke).mockResolvedValueOnce({});
    await api.executeRequest(makeRequest());
    const call = vi.mocked(invoke).mock.calls[0];
    expect((call[1] as any).options).toBeNull();
  });
});

describe('api.importCurl', () => {
  it('passes curlString to import_curl', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(makeRequest());
    await api.importCurl("curl -X POST https://example.com -d 'test'");
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('import_curl', {
      curlString: "curl -X POST https://example.com -d 'test'",
    });
  });
});

describe('api.exportCurl', () => {
  it('passes request to export_curl and returns string', async () => {
    vi.mocked(invoke).mockResolvedValueOnce('curl https://example.com');
    const result = await api.exportCurl(makeRequest());
    expect(result).toBe('curl https://example.com');
  });
});

describe('api.generateSnippet', () => {
  it('passes language and request to generate_snippet', async () => {
    vi.mocked(invoke).mockResolvedValueOnce('fetch("https://example.com")');
    await api.generateSnippet('javascript', makeRequest());
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('generate_snippet', {
      language: 'javascript',
      request: makeRequest(),
    });
  });
});

describe('api.getMockRoutes', () => {
  it('calls get_mock_routes with no arguments', async () => {
    vi.mocked(invoke).mockResolvedValueOnce([]);
    await api.getMockRoutes();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_mock_routes');
  });
});

describe('api.startMockServer', () => {
  it('passes port to start_mock_server', async () => {
    vi.mocked(invoke).mockResolvedValueOnce('http://127.0.0.1:3456');
    await api.startMockServer(3456);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('start_mock_server', { port: 3456 });
  });
});

describe('api.stopMockServer', () => {
  it('calls stop_mock_server', async () => {
    vi.mocked(invoke).mockResolvedValueOnce(undefined);
    await api.stopMockServer();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('stop_mock_server');
  });
});

describe('api.getSettings / updateSettings', () => {
  it('getSettings calls get_settings', async () => {
    vi.mocked(invoke).mockResolvedValueOnce({});
    await api.getSettings();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_settings');
  });

  it('updateSettings passes settings object', async () => {
    const s: AppSettings = {
      theme: 'dark', timeoutMs: 30000, sslVerify: true,
      proxyUrl: null, followRedirects: true, maxRedirects: 10,
    };
    vi.mocked(invoke).mockResolvedValueOnce(s);
    await api.updateSettings(s);
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('update_settings', { settings: s });
  });
});
