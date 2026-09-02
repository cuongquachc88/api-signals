import { useCallback } from 'react';
import { useAppStore } from '../store/appStore';
import { api } from '../api/tauri';
import { uuid } from '../utils/uuid';
import type { APIRequest, HistoryEntry } from '../types';

export function useRequest() {
  const {
    selectedTabId,
    tabs,
    settings,
    activeEnvironmentId,
    environments,
    selectedWorkspaceId,
    setTabLoading,
    updateTabResponse,
    loadHistory,
    saveRequest,
  } = useAppStore();

  const activeEnv = environments.find(e => e.id === activeEnvironmentId);

  const buildVariables = useCallback((): Record<string, string> => {
    const vars: Record<string, string> = {};
    if (activeEnv) {
      for (const v of activeEnv.variables) {
        if (v.enabled) {
          vars[v.key] = v.value;
        }
      }
    }
    return vars;
  }, [activeEnv]);

  const sendRequest = useCallback(async (tabId?: string) => {
    const tid = tabId ?? selectedTabId;
    if (!tid) return;

    const tab = tabs.find(t => t.id === tid);
    if (!tab) return;

    const { request } = tab;
    if (!request.url.trim()) {
      alert('Please enter a URL');
      return;
    }

    setTabLoading(tid, true);
    updateTabResponse(tid, null);

    try {
      const variables = buildVariables();
      const response = await api.executeRequest(request, {
        timeoutMs: settings.timeoutMs,
        sslVerify: settings.sslVerify,
        followRedirects: settings.followRedirects,
        proxyUrl: settings.proxyUrl,
        variables,
      });

      updateTabResponse(tid, response);

      // Auto-save request if dirty
      if (tab.isDirty && request.collectionId) {
        await saveRequest(request).catch(console.error);
      }

      // Add to history
      if (selectedWorkspaceId) {
        const entry: HistoryEntry = {
          id: uuid(),
          workspaceId: selectedWorkspaceId,
          requestName: request.name,
          method: request.method,
          url: request.url,
          status: response.status,
          durationMs: response.timing.totalMs,
          responseSize: response.bodySize,
          timestamp: new Date().toISOString(),
          requestSnapshot: JSON.stringify(request),
          responseSnapshot: JSON.stringify(response),
        };
        await api.addHistoryEntry(entry).catch(console.error);
        await loadHistory().catch(console.error);
      }
    } catch (err) {
      const errorResponse = {
        status: 0,
        statusText: 'Error',
        headers: [],
        body: String(err),
        bodySize: 0,
        timing: { dnsMs: 0, connectMs: 0, tlsMs: 0, sendMs: 0, waitMs: 0, receiveMs: 0, totalMs: 0 },
        cookies: [],
      };
      updateTabResponse(tid, errorResponse);
    } finally {
      setTabLoading(tid, false);
    }
  }, [selectedTabId, tabs, settings, buildVariables, setTabLoading, updateTabResponse, saveRequest, selectedWorkspaceId, loadHistory]);

  return { sendRequest };
}
