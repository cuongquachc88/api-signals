import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { invoke } from '@tauri-apps/api/core';
import type { APIRequest, APIResponse, AppSettings, Tab } from '../types';

vi.mock('@tauri-apps/api/core', () => ({ invoke: vi.fn() }));

const makeRequest = (id = 'req-1'): APIRequest => ({
  id, collectionId: 'col-1', workspaceId: 'ws-1',
  name: 'Test', method: 'GET', url: 'https://example.com',
  headers: [], params: [], body: { type: 'None' }, auth: { type: 'None' },
  preRequestScript: '', postResponseScript: '', description: '',
  sortOrder: 0, createdAt: '', updatedAt: '',
});

const makeResponse = (): APIResponse => ({
  status: 200, statusText: 'OK',
  headers: [{ id: 'h1', key: 'content-type', value: 'application/json', enabled: true }],
  body: '{"ok":true}', bodySize: 11,
  timing: { dnsMs: 5, connectMs: 15, tlsMs: 20, sendMs: 3, waitMs: 80, receiveMs: 10, totalMs: 133 },
  cookies: [],
});

const makeTab = (id = 'tab-1', req = makeRequest()): Tab => ({
  id, requestId: req.id, isDirty: false, request: req, response: null, isLoading: false,
});

const defaultSettings: AppSettings = {
  theme: 'dark', timeoutMs: 30000, sslVerify: true,
  proxyUrl: null, followRedirects: true, maxRedirects: 10,
};

describe('useRequest hook', () => {
  beforeEach(() => {
    vi.mocked(invoke).mockReset();
    vi.resetModules();
  });

  it('does nothing if no selectedTabId', async () => {
    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({ selectedTabId: null, tabs: [] });

    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    await act(async () => {
      await result.current.sendRequest();
    });

    expect(vi.mocked(invoke)).not.toHaveBeenCalled();
  });

  it('does nothing if tab URL is empty', async () => {
    const req = { ...makeRequest(), url: '' };
    const tab = makeTab('tab-1', req);

    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({
      selectedTabId: 'tab-1',
      tabs: [tab],
      settings: defaultSettings,
      environments: [],
      activeEnvironmentId: null,
      selectedWorkspaceId: 'ws-1',
    });

    const alertMock = vi.spyOn(window, 'alert').mockImplementation(() => {});
    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    await act(async () => {
      await result.current.sendRequest();
    });

    expect(alertMock).toHaveBeenCalledWith('Please enter a URL');
    expect(vi.mocked(invoke)).not.toHaveBeenCalledWith('execute_request', expect.anything());
    alertMock.mockRestore();
  });

  it('calls execute_request and updates tab response on success', async () => {
    const req = makeRequest();
    const tab = makeTab('tab-1', req);
    const resp = makeResponse();

    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({
      selectedTabId: 'tab-1',
      tabs: [tab],
      settings: defaultSettings,
      environments: [],
      activeEnvironmentId: null,
      selectedWorkspaceId: 'ws-1',
    });

    // execute_request -> response; add_history_entry -> void; get_history -> []
    vi.mocked(invoke)
      .mockResolvedValueOnce(resp)
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce([]);

    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    await act(async () => {
      await result.current.sendRequest('tab-1');
    });

    const after = useAppStore.getState();
    const updatedTab = after.tabs.find(t => t.id === 'tab-1');
    expect(updatedTab?.response?.status).toBe(200);
    expect(updatedTab?.isLoading).toBe(false);
  });

  it('stores error response when execute_request throws', async () => {
    const req = makeRequest();
    const tab = makeTab('tab-1', req);

    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({
      selectedTabId: 'tab-1',
      tabs: [tab],
      settings: defaultSettings,
      environments: [],
      activeEnvironmentId: null,
      selectedWorkspaceId: 'ws-1',
    });

    vi.mocked(invoke).mockRejectedValueOnce(new Error('Network unreachable'));

    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    await act(async () => {
      await result.current.sendRequest('tab-1');
    });

    const after = useAppStore.getState();
    const updatedTab = after.tabs.find(t => t.id === 'tab-1');
    expect(updatedTab?.response?.status).toBe(0);
    expect(updatedTab?.response?.statusText).toBe('Error');
    expect(updatedTab?.isLoading).toBe(false);
  });

  it('interpolates environment variables into request before sending', async () => {
    const req = { ...makeRequest(), url: 'https://{{BASE_URL}}/users' };
    const tab = makeTab('tab-1', req);
    const resp = makeResponse();

    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({
      selectedTabId: 'tab-1',
      tabs: [tab],
      settings: defaultSettings,
      environments: [{
        id: 'env-1', workspaceId: 'ws-1', name: 'Prod',
        variables: [{ id: 'v1', key: 'BASE_URL', value: 'api.example.com', enabled: true, secret: false }],
        isActive: true, createdAt: '', updatedAt: '',
      }],
      activeEnvironmentId: 'env-1',
      selectedWorkspaceId: 'ws-1',
    });

    vi.mocked(invoke)
      .mockResolvedValueOnce(resp)
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce([]);

    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    await act(async () => {
      await result.current.sendRequest('tab-1');
    });

    // Variables are passed to the backend — verify they're in the options
    const executeCalls = vi.mocked(invoke).mock.calls.filter(c => c[0] === 'execute_request');
    expect(executeCalls.length).toBe(1);
    const opts = (executeCalls[0][1] as any).options;
    expect(opts.variables).toEqual({ BASE_URL: 'api.example.com' });
  });

  it('skips disabled environment variables', async () => {
    const req = makeRequest();
    const tab = makeTab('tab-1', req);
    const resp = makeResponse();

    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({
      selectedTabId: 'tab-1',
      tabs: [tab],
      settings: defaultSettings,
      environments: [{
        id: 'env-1', workspaceId: 'ws-1', name: 'Prod',
        variables: [
          { id: 'v1', key: 'ACTIVE', value: 'yes', enabled: true, secret: false },
          { id: 'v2', key: 'DISABLED', value: 'no', enabled: false, secret: false },
        ],
        isActive: true, createdAt: '', updatedAt: '',
      }],
      activeEnvironmentId: 'env-1',
      selectedWorkspaceId: 'ws-1',
    });

    vi.mocked(invoke)
      .mockResolvedValueOnce(resp)
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce([]);

    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    await act(async () => {
      await result.current.sendRequest('tab-1');
    });

    const executeCalls = vi.mocked(invoke).mock.calls.filter(c => c[0] === 'execute_request');
    const opts = (executeCalls[0][1] as any).options;
    expect(opts.variables).toHaveProperty('ACTIVE', 'yes');
    expect(opts.variables).not.toHaveProperty('DISABLED');
  });

  it('sets isLoading to true while request is in flight', async () => {
    const req = makeRequest();
    const tab = makeTab('tab-1', req);

    const { useAppStore } = await import('../store/appStore');
    useAppStore.setState({
      selectedTabId: 'tab-1',
      tabs: [tab],
      settings: defaultSettings,
      environments: [],
      activeEnvironmentId: null,
      selectedWorkspaceId: 'ws-1',
    });

    let resolveRequest!: (v: any) => void;
    vi.mocked(invoke).mockImplementationOnce(
      () => new Promise(res => { resolveRequest = res; })
    );

    const { useRequest } = await import('../hooks/useRequest');
    const { result } = renderHook(() => useRequest());

    let sendPromise: Promise<void>;
    act(() => {
      sendPromise = result.current.sendRequest('tab-1');
    });

    // Check loading state before resolving
    const loadingState = useAppStore.getState();
    const loadingTab = loadingState.tabs.find(t => t.id === 'tab-1');
    expect(loadingTab?.isLoading).toBe(true);

    await act(async () => {
      resolveRequest!({ status: 200, statusText: 'OK', headers: [], body: '', bodySize: 0, timing: {}, cookies: [] });
      await sendPromise!;
    });

    const after = useAppStore.getState();
    expect(after.tabs.find(t => t.id === 'tab-1')?.isLoading).toBe(false);
  });
});
