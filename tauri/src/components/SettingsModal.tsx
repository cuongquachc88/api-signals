import React, { useState } from 'react';
import { useAppStore } from '../store/appStore';
import type { AppSettings } from '../types';

export function SettingsModal() {
  const { settings, updateSettings, setSettingsOpen } = useAppStore();
  const [local, setLocal] = useState<AppSettings>({ ...settings });

  const handleSave = async () => {
    await updateSettings(local);
    setSettingsOpen(false);
  };

  const Section = ({ title, children }: { title: string; children: React.ReactNode }) => (
    <div className="mb-6">
      <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">{title}</h3>
      <div className="flex flex-col gap-3">{children}</div>
    </div>
  );

  const Row = ({ label, children, hint }: { label: string; children: React.ReactNode; hint?: string }) => (
    <div className="flex items-center justify-between gap-4">
      <div>
        <label className="text-sm text-gray-200">{label}</label>
        {hint && <p className="text-xs text-gray-500 mt-0.5">{hint}</p>}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-gray-900 border border-gray-700 rounded-lg w-[520px] max-h-[80vh] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-700">
          <h2 className="text-base font-semibold text-white">Settings</h2>
          <button onClick={() => setSettingsOpen(false)} className="text-gray-500 hover:text-white">
            <svg className="w-5 h-5" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M4 4l12 12M16 4L4 16" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-5 py-4">
          <Section title="Appearance">
            <Row label="Theme">
              <div className="flex items-center gap-2">
                {(['dark', 'light'] as const).map(t => (
                  <button
                    key={t}
                    onClick={() => setLocal(s => ({ ...s, theme: t }))}
                    className={`px-3 py-1 rounded text-sm ${
                      local.theme === t
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-800 text-gray-400 hover:text-white border border-gray-700'
                    }`}
                  >
                    {t.charAt(0).toUpperCase() + t.slice(1)}
                  </button>
                ))}
              </div>
            </Row>
          </Section>

          <Section title="Requests">
            <Row label="Timeout" hint="Maximum time to wait for a response">
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  className="w-24 bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none text-right"
                  value={local.timeoutMs}
                  min={1000}
                  max={300000}
                  onChange={(e) => setLocal(s => ({ ...s, timeoutMs: Number(e.target.value) }))}
                />
                <span className="text-xs text-gray-500">ms</span>
              </div>
            </Row>

            <Row label="Verify SSL Certificates" hint="Disable for self-signed certificates">
              <button
                onClick={() => setLocal(s => ({ ...s, sslVerify: !s.sslVerify }))}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  local.sslVerify ? 'bg-blue-600' : 'bg-gray-700'
                }`}
              >
                <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                  local.sslVerify ? 'translate-x-4' : 'translate-x-1'
                }`} />
              </button>
            </Row>

            <Row label="Follow Redirects">
              <button
                onClick={() => setLocal(s => ({ ...s, followRedirects: !s.followRedirects }))}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  local.followRedirects ? 'bg-blue-600' : 'bg-gray-700'
                }`}
              >
                <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                  local.followRedirects ? 'translate-x-4' : 'translate-x-1'
                }`} />
              </button>
            </Row>

            <Row label="Max Redirects">
              <input
                type="number"
                className="w-20 bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none text-right"
                value={local.maxRedirects}
                min={0}
                max={30}
                onChange={(e) => setLocal(s => ({ ...s, maxRedirects: Number(e.target.value) }))}
              />
            </Row>
          </Section>

          <Section title="Proxy">
            <Row label="Proxy URL" hint="HTTP/HTTPS proxy (e.g. http://proxy:8080)">
              <input
                className="w-56 bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none"
                value={local.proxyUrl ?? ''}
                placeholder="http://proxy.example.com:8080"
                onChange={(e) => setLocal(s => ({ ...s, proxyUrl: e.target.value || null }))}
              />
            </Row>
          </Section>
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2 px-5 py-3 border-t border-gray-700">
          <button
            onClick={() => setSettingsOpen(false)}
            className="px-4 py-1.5 text-sm text-gray-400 hover:text-white rounded border border-gray-700 hover:border-gray-500"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded"
          >
            Save Settings
          </button>
        </div>
      </div>
    </div>
  );
}
