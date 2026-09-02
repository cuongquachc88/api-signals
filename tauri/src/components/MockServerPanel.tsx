import React, { useState, useEffect } from 'react';
import { clsx } from 'clsx';
import { api } from '../api/tauri';
import type { MockRoute, KeyValue } from '../types';
import { uuid } from '../utils/uuid';

export function MockServerPanel() {
  const [routes, setRoutes] = useState<MockRoute[]>([]);
  const [isRunning, setIsRunning] = useState(false);
  const [port, setPort] = useState(3456);
  const [editingRoute, setEditingRoute] = useState<MockRoute | null>(null);
  const [statusMessage, setStatusMessage] = useState('');

  useEffect(() => {
    loadRoutes();
    api.getMockServerStatus().then(setIsRunning).catch(() => {});
  }, []);

  const loadRoutes = async () => {
    try {
      const r = await api.getMockRoutes();
      setRoutes(r);
    } catch (e) {
      console.error(e);
    }
  };

  const handleToggleServer = async () => {
    try {
      if (isRunning) {
        await api.stopMockServer();
        setIsRunning(false);
        setStatusMessage('Mock server stopped');
      } else {
        const msg = await api.startMockServer(port);
        setIsRunning(true);
        setStatusMessage(msg);
      }
    } catch (e) {
      setStatusMessage(String(e));
    }
  };

  const handleAddRoute = async () => {
    const route = await api.addMockRoute('GET', '/api/example');
    setRoutes([...routes, route]);
    setEditingRoute(route);
  };

  const handleDeleteRoute = async (id: string) => {
    await api.deleteMockRoute(id);
    setRoutes(routes.filter(r => r.id !== id));
  };

  const handleSaveRoute = async (route: MockRoute) => {
    const updated = await api.updateMockRoute(route);
    setRoutes(routes.map(r => r.id === updated.id ? updated : r));
    setEditingRoute(null);
  };

  return (
    <div className="flex flex-col h-full">
      {/* Server controls */}
      <div className="flex items-center gap-3 px-3 py-2 border-b border-gray-700 shrink-0">
        <div className="flex items-center gap-2">
          <span className={clsx('w-2 h-2 rounded-full', isRunning ? 'bg-green-500' : 'bg-gray-500')} />
          <span className="text-xs text-gray-400">{isRunning ? `Running on :${port}` : 'Stopped'}</span>
        </div>

        <label className="text-xs text-gray-500">Port:</label>
        <input
          type="number"
          className="w-20 bg-gray-800 text-gray-200 rounded px-2 py-1 text-xs border border-gray-700 outline-none"
          value={port}
          min={1024}
          max={65535}
          disabled={isRunning}
          onChange={(e) => setPort(Number(e.target.value))}
        />

        <button
          onClick={handleToggleServer}
          className={clsx(
            'px-3 py-1 rounded text-xs font-medium',
            isRunning
              ? 'bg-red-700 hover:bg-red-600 text-white'
              : 'bg-green-700 hover:bg-green-600 text-white'
          )}
        >
          {isRunning ? 'Stop Server' : 'Start Server'}
        </button>

        {statusMessage && (
          <span className="text-xs text-gray-500 flex-1 truncate">{statusMessage}</span>
        )}

        <button
          onClick={handleAddRoute}
          className="ml-auto text-xs text-blue-400 hover:text-blue-300 flex items-center gap-1"
        >
          <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M6 1v10M1 6h10" strokeLinecap="round" />
          </svg>
          Add Route
        </button>
      </div>

      {/* Routes list */}
      <div className="flex-1 overflow-auto">
        {routes.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-gray-600">
            <p className="text-sm">No mock routes configured</p>
            <button onClick={handleAddRoute} className="mt-2 text-xs text-blue-500 hover:text-blue-400">
              Add your first route
            </button>
          </div>
        ) : (
          <table className="w-full text-xs">
            <thead className="sticky top-0 bg-gray-900 text-gray-400">
              <tr className="border-b border-gray-700">
                <th className="w-8 py-1.5 px-2"></th>
                <th className="text-left py-1.5 px-2">Method</th>
                <th className="text-left py-1.5 px-2">Path</th>
                <th className="text-left py-1.5 px-2">Status</th>
                <th className="text-left py-1.5 px-2">Delay (ms)</th>
                <th className="w-16 py-1.5 px-2"></th>
              </tr>
            </thead>
            <tbody>
              {routes.map(route => (
                <tr key={route.id} className="border-b border-gray-800 hover:bg-gray-800/40 group">
                  <td className="px-2 py-1.5">
                    <input
                      type="checkbox"
                      checked={route.enabled}
                      onChange={async (e) => {
                        const updated = { ...route, enabled: e.target.checked };
                        await handleSaveRoute(updated);
                      }}
                      className="accent-blue-500"
                    />
                  </td>
                  <td className="px-2 py-1.5">
                    <span className={clsx('font-bold', {
                      'text-emerald-400': route.method === 'GET',
                      'text-amber-400': route.method === 'POST',
                      'text-blue-400': route.method === 'PUT',
                      'text-purple-400': route.method === 'PATCH',
                      'text-red-400': route.method === 'DELETE',
                      'text-gray-400': route.method === 'ANY',
                    })}>
                      {route.method}
                    </span>
                  </td>
                  <td className="px-2 py-1.5 font-mono text-gray-300">{route.path}</td>
                  <td className="px-2 py-1.5">
                    <span className={clsx('px-1.5 py-0.5 rounded text-[10px] font-bold', {
                      'bg-green-800 text-green-200': route.statusCode >= 200 && route.statusCode < 300,
                      'bg-yellow-800 text-yellow-200': route.statusCode >= 300 && route.statusCode < 400,
                      'bg-red-800 text-red-200': route.statusCode >= 400,
                    })}>
                      {route.statusCode}
                    </span>
                  </td>
                  <td className="px-2 py-1.5 text-gray-400">{route.delayMs}</td>
                  <td className="px-2 py-1.5">
                    <div className="hidden group-hover:flex items-center gap-1">
                      <button
                        onClick={() => setEditingRoute(route)}
                        className="p-0.5 text-gray-500 hover:text-blue-400"
                      >
                        <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
                          <path d="M2 10l1.5-1.5L9 3 10 4l-5.5 5.5L3 11z" />
                          <path d="M7.5 2.5l2 2" />
                        </svg>
                      </button>
                      <button
                        onClick={() => handleDeleteRoute(route.id)}
                        className="p-0.5 text-gray-500 hover:text-red-400"
                      >
                        <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
                          <path d="M3 3L9 9M9 3L3 9" strokeLinecap="round" />
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Edit route modal */}
      {editingRoute && (
        <RouteEditor
          route={editingRoute}
          onSave={handleSaveRoute}
          onClose={() => setEditingRoute(null)}
        />
      )}
    </div>
  );
}

function RouteEditor({
  route,
  onSave,
  onClose,
}: {
  route: MockRoute;
  onSave: (route: MockRoute) => void;
  onClose: () => void;
}) {
  const [r, setR] = useState<MockRoute>({ ...route });

  const updateHeader = (id: string, field: keyof KeyValue, value: string | boolean) => {
    setR(prev => ({
      ...prev,
      responseHeaders: prev.responseHeaders.map(h => h.id === id ? { ...h, [field]: value } : h),
    }));
  };

  const addHeader = () => {
    setR(prev => ({
      ...prev,
      responseHeaders: [...prev.responseHeaders, { id: uuid(), key: '', value: '', enabled: true }],
    }));
  };

  const removeHeader = (id: string) => {
    setR(prev => ({ ...prev, responseHeaders: prev.responseHeaders.filter(h => h.id !== id) }));
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-gray-900 border border-gray-700 rounded-lg w-[600px] max-h-[80vh] flex flex-col shadow-2xl">
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h2 className="text-sm font-semibold text-white">Edit Mock Route</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-white">
            <svg className="w-4 h-4" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M2 2l10 10M12 2L2 12" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        <div className="flex-1 overflow-auto p-4 flex flex-col gap-3">
          <div className="flex gap-3">
            <div className="flex flex-col gap-1">
              <label className="text-xs text-gray-400">Method</label>
              <select
                className="bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
                value={r.method}
                onChange={(e) => setR(prev => ({ ...prev, method: e.target.value }))}
              >
                {['ANY', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'].map(m => (
                  <option key={m} value={m}>{m}</option>
                ))}
              </select>
            </div>
            <div className="flex-1 flex flex-col gap-1">
              <label className="text-xs text-gray-400">Path</label>
              <input
                className="bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none font-mono"
                value={r.path}
                placeholder="/api/example"
                onChange={(e) => setR(prev => ({ ...prev, path: e.target.value }))}
              />
            </div>
          </div>

          <div className="flex gap-3">
            <div className="flex flex-col gap-1">
              <label className="text-xs text-gray-400">Status Code</label>
              <input
                type="number"
                className="w-24 bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
                value={r.statusCode}
                onChange={(e) => setR(prev => ({ ...prev, statusCode: Number(e.target.value) }))}
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs text-gray-400">Delay (ms)</label>
              <input
                type="number"
                className="w-24 bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-sm border border-gray-700 outline-none"
                value={r.delayMs}
                min={0}
                onChange={(e) => setR(prev => ({ ...prev, delayMs: Number(e.target.value) }))}
              />
            </div>
          </div>

          <div className="flex flex-col gap-1">
            <label className="text-xs text-gray-400">Response Body</label>
            <textarea
              className="bg-gray-800 text-gray-200 rounded px-2 py-1.5 text-xs border border-gray-700 outline-none font-mono h-24 resize-none"
              value={r.responseBody}
              onChange={(e) => setR(prev => ({ ...prev, responseBody: e.target.value }))}
            />
          </div>

          <div className="flex flex-col gap-1">
            <div className="flex items-center justify-between">
              <label className="text-xs text-gray-400">Response Headers</label>
              <button onClick={addHeader} className="text-xs text-blue-400">+ Add</button>
            </div>
            {r.responseHeaders.map(h => (
              <div key={h.id} className="flex gap-2">
                <input
                  className="flex-1 bg-gray-800 text-gray-200 rounded px-2 py-1 text-xs border border-gray-700 outline-none"
                  value={h.key} placeholder="Header-Name"
                  onChange={(e) => updateHeader(h.id, 'key', e.target.value)}
                />
                <input
                  className="flex-1 bg-gray-800 text-gray-200 rounded px-2 py-1 text-xs border border-gray-700 outline-none"
                  value={h.value} placeholder="value"
                  onChange={(e) => updateHeader(h.id, 'value', e.target.value)}
                />
                <button onClick={() => removeHeader(h.id)} className="text-gray-600 hover:text-red-400">
                  <svg className="w-3 h-3" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2">
                    <path d="M2 2l6 6M8 2L2 8" strokeLinecap="round" />
                  </svg>
                </button>
              </div>
            ))}
          </div>
        </div>

        <div className="flex justify-end gap-2 px-4 py-3 border-t border-gray-700">
          <button onClick={onClose} className="px-3 py-1.5 text-sm text-gray-400 hover:text-white rounded border border-gray-700">
            Cancel
          </button>
          <button onClick={() => onSave(r)} className="px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded">
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
