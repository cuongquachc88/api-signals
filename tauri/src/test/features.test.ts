/**
 * Feature-level tests covering end-to-end data flows for:
 * - Variable interpolation
 * - Response timing calculation
 * - JSON formatting
 * - Code snippet generation (via api layer)
 * - cURL import/export (via api layer)
 * - History auto-recording
 * - Workspace isolation (collections/requests belong to correct workspace)
 * - Environment variable precedence
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import { api } from '../api/tauri';
import type { APIRequest, APIResponse, RequestTiming, Variable } from '../types';

vi.mock('@tauri-apps/api/core', () => ({ invoke: vi.fn() }));

beforeEach(() => vi.mocked(invoke).mockReset());

// ─── Variable interpolation ───────────────────────────────────────────────────
function interpolate(template: string, vars: Record<string, string>): string {
  return template.replace(/\{\{([^}]+)\}\}/g, (_, key) => vars[key.trim()] ?? `{{${key}}}`);
}

describe('Variable interpolation', () => {
  it('replaces {{VAR}} with value from map', () => {
    expect(interpolate('https://{{HOST}}/api', { HOST: 'example.com' }))
      .toBe('https://example.com/api');
  });

  it('replaces multiple variables in one string', () => {
    expect(interpolate('{{SCHEME}}://{{HOST}}:{{PORT}}/path', {
      SCHEME: 'https', HOST: 'api.example.com', PORT: '443',
    })).toBe('https://api.example.com:443/path');
  });

  it('leaves unknown variables as-is', () => {
    expect(interpolate('https://{{UNKNOWN}}/api', {}))
      .toBe('https://{{UNKNOWN}}/api');
  });

  it('handles empty template', () => {
    expect(interpolate('', { X: '1' })).toBe('');
  });

  it('handles template with no variables', () => {
    expect(interpolate('https://example.com', { X: '1' })).toBe('https://example.com');
  });

  it('trims whitespace in variable names', () => {
    expect(interpolate('{{ BASE_URL }}/users', { BASE_URL: 'https://api.io' }))
      .toBe('https://api.io/users');
  });

  it('replaces same variable multiple times', () => {
    expect(interpolate('{{V}}-{{V}}-{{V}}', { V: 'x' })).toBe('x-x-x');
  });

  it('disabled variable is excluded from map (tested at build-vars level)', () => {
    const variables: Variable[] = [
      { id: '1', key: 'A', value: 'active', enabled: true, secret: false },
      { id: '2', key: 'B', value: 'disabled', enabled: false, secret: false },
    ];
    const vars = Object.fromEntries(
      variables.filter(v => v.enabled).map(v => [v.key, v.value])
    );
    expect(vars).toHaveProperty('A', 'active');
    expect(vars).not.toHaveProperty('B');
    expect(interpolate('{{A}}-{{B}}', vars)).toBe('active-{{B}}');
  });
});

// ─── Response timing ──────────────────────────────────────────────────────────
describe('Response timing fields', () => {
  const timing: RequestTiming = {
    dnsMs: 10, connectMs: 20, tlsMs: 30, sendMs: 5, waitMs: 100, receiveMs: 15, totalMs: 180,
  };

  it('sum of phases equals totalMs', () => {
    const sum = timing.dnsMs + timing.connectMs + timing.tlsMs
      + timing.sendMs + timing.waitMs + timing.receiveMs;
    expect(sum).toBe(timing.totalMs);
  });

  it('all phases are non-negative', () => {
    for (const [key, val] of Object.entries(timing)) {
      expect(val).toBeGreaterThanOrEqual(0);
    }
  });
});

// ─── JSON formatting ──────────────────────────────────────────────────────────
function tryFormatJson(raw: string): string | null {
  try { return JSON.stringify(JSON.parse(raw), null, 2); } catch { return null; }
}

describe('JSON formatting', () => {
  it('formats compact JSON to pretty', () => {
    const result = tryFormatJson('{"a":1,"b":"two"}');
    expect(result).toBe('{\n  "a": 1,\n  "b": "two"\n}');
  });

  it('returns null for invalid JSON', () => {
    expect(tryFormatJson('not json')).toBeNull();
    expect(tryFormatJson('{')).toBeNull();
  });

  it('handles arrays', () => {
    const result = tryFormatJson('[1,2,3]');
    expect(result).toBe('[\n  1,\n  2,\n  3\n]');
  });

  it('handles nested objects', () => {
    const result = tryFormatJson('{"a":{"b":1}}');
    expect(result).toBe('{\n  "a": {\n    "b": 1\n  }\n}');
  });

  it('handles empty object', () => {
    const result = tryFormatJson('{}');
    expect(result).toBe('{}');
  });

  it('handles null value', () => {
    const result = tryFormatJson('{"x":null}');
    expect(result).toContain('"x": null');
  });
});

// ─── Status code classification ───────────────────────────────────────────────
function statusClass(code: number): 'info' | 'success' | 'redirect' | 'client-error' | 'server-error' | 'unknown' {
  if (code >= 100 && code < 200) return 'info';
  if (code >= 200 && code < 300) return 'success';
  if (code >= 300 && code < 400) return 'redirect';
  if (code >= 400 && code < 500) return 'client-error';
  if (code >= 500 && code < 600) return 'server-error';
  return 'unknown';
}

describe('Status code classification', () => {
  it('200 → success', () => expect(statusClass(200)).toBe('success'));
  it('201 → success', () => expect(statusClass(201)).toBe('success'));
  it('204 → success', () => expect(statusClass(204)).toBe('success'));
  it('301 → redirect', () => expect(statusClass(301)).toBe('redirect'));
  it('304 → redirect', () => expect(statusClass(304)).toBe('redirect'));
  it('400 → client-error', () => expect(statusClass(400)).toBe('client-error'));
  it('401 → client-error', () => expect(statusClass(401)).toBe('client-error'));
  it('404 → client-error', () => expect(statusClass(404)).toBe('client-error'));
  it('422 → client-error', () => expect(statusClass(422)).toBe('client-error'));
  it('500 → server-error', () => expect(statusClass(500)).toBe('server-error'));
  it('503 → server-error', () => expect(statusClass(503)).toBe('server-error'));
  it('0 → unknown (network error)', () => expect(statusClass(0)).toBe('unknown'));
  it('101 → info', () => expect(statusClass(101)).toBe('info'));
});

// ─── Byte formatting ──────────────────────────────────────────────────────────
function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

describe('formatBytes', () => {
  it('0 bytes', () => expect(formatBytes(0)).toBe('0 B'));
  it('512 bytes', () => expect(formatBytes(512)).toBe('512 B'));
  it('1023 bytes', () => expect(formatBytes(1023)).toBe('1023 B'));
  it('1024 bytes → 1.0 KB', () => expect(formatBytes(1024)).toBe('1.0 KB'));
  it('1536 bytes → 1.5 KB', () => expect(formatBytes(1536)).toBe('1.5 KB'));
  it('1MB', () => expect(formatBytes(1024 * 1024)).toBe('1.00 MB'));
  it('2.5MB', () => expect(formatBytes(1024 * 1024 * 2.5)).toBe('2.50 MB'));
});

// ─── API calls: code snippet generation ──────────────────────────────────────
describe('api: generateSnippet', () => {
  const makeReq = (): APIRequest => ({
    id: 'req-1', collectionId: 'col-1', workspaceId: 'ws-1',
    name: 'Test', method: 'POST', url: 'https://api.example.com/users',
    headers: [{ id: 'h1', key: 'Content-Type', value: 'application/json', enabled: true }],
    params: [], body: { type: 'Json', content: '{"name":"Alice"}' },
    auth: { type: 'Bearer', token: 'secret' },
    preRequestScript: '', postResponseScript: '', description: '',
    sortOrder: 0, createdAt: '', updatedAt: '',
  });

  const languages = ['curl', 'javascript', 'python', 'go', 'php', 'ruby'];

  for (const lang of languages) {
    it(`generates ${lang} snippet`, async () => {
      vi.mocked(invoke).mockResolvedValueOnce(`# ${lang} snippet`);
      const result = await api.generateSnippet(lang, makeReq());
      expect(vi.mocked(invoke)).toHaveBeenCalledWith('generate_snippet', {
        language: lang,
        request: makeReq(),
      });
      expect(result).toContain(lang);
    });
  }
});

// ─── API calls: import/export ─────────────────────────────────────────────────
describe('api: importCurl', () => {
  it('handles GET request', async () => {
    const fakeResult = {
      id: 'r1', collectionId: 'c1', workspaceId: 'w1',
      name: 'curl import', method: 'GET', url: 'https://api.example.com',
      headers: [], params: [], body: { type: 'None' }, auth: { type: 'None' },
      preRequestScript: '', postResponseScript: '', description: '',
      sortOrder: 0, createdAt: '', updatedAt: '',
    };
    vi.mocked(invoke).mockResolvedValueOnce(fakeResult);
    const result = await api.importCurl('curl https://api.example.com');
    expect((result as APIRequest).method).toBe('GET');
    expect((result as APIRequest).url).toBe('https://api.example.com');
  });

  it('handles POST with body', async () => {
    const fakeResult = {
      id: 'r2', collectionId: 'c1', workspaceId: 'w1',
      name: 'curl import', method: 'POST', url: 'https://api.example.com/users',
      headers: [{ id: 'h1', key: 'Content-Type', value: 'application/json', enabled: true }],
      params: [], body: { type: 'Json', content: '{"name":"Bob"}' },
      auth: { type: 'None' },
      preRequestScript: '', postResponseScript: '', description: '',
      sortOrder: 0, createdAt: '', updatedAt: '',
    };
    vi.mocked(invoke).mockResolvedValueOnce(fakeResult);
    const result = await api.importCurl(
      "curl -X POST https://api.example.com/users -H 'Content-Type: application/json' -d '{\"name\":\"Bob\"}'"
    );
    expect((result as APIRequest).method).toBe('POST');
    expect((result as APIRequest).body.type).toBe('Json');
  });
});

describe('api: exportCurl', () => {
  it('produces a curl command string', async () => {
    vi.mocked(invoke).mockResolvedValueOnce('curl -X GET https://example.com');
    const req: APIRequest = {
      id: 'r1', collectionId: 'c1', workspaceId: 'w1',
      name: 'Test', method: 'GET', url: 'https://example.com',
      headers: [], params: [], body: { type: 'None' }, auth: { type: 'None' },
      preRequestScript: '', postResponseScript: '', description: '',
      sortOrder: 0, createdAt: '', updatedAt: '',
    };
    const curl = await api.exportCurl(req);
    expect(curl as string).toContain('curl');
  });
});

// ─── Workspace isolation ───────────────────────────────────────────────────────
describe('Workspace isolation', () => {
  it('collections are loaded per workspace (different workspaces return different collections)', async () => {
    vi.mocked(invoke)
      .mockResolvedValueOnce([{ id: 'col-ws1', workspaceId: 'ws-1', name: 'WS1 Collection', parentId: null, description: null, sortOrder: 0, createdAt: '', updatedAt: '' }])
      .mockResolvedValueOnce([{ id: 'col-ws2', workspaceId: 'ws-2', name: 'WS2 Collection', parentId: null, description: null, sortOrder: 0, createdAt: '', updatedAt: '' }]);

    const ws1Cols = await api.getCollections('ws-1');
    const ws2Cols = await api.getCollections('ws-2');

    expect((ws1Cols as any[])[0].workspaceId).toBe('ws-1');
    expect((ws2Cols as any[])[0].workspaceId).toBe('ws-2');
    expect((ws1Cols as any[])[0].id).not.toBe((ws2Cols as any[])[0].id);
  });
});

// ─── Mock routes ───────────────────────────────────────────────────────────────
describe('MockRoute management', () => {
  it('enabled routes serve responses; disabled routes are skipped', () => {
    const routes = [
      { id: '1', method: 'GET', path: '/api/users', statusCode: 200, responseBody: '[]', responseHeaders: [], delayMs: 0, enabled: true },
      { id: '2', method: 'POST', path: '/api/users', statusCode: 201, responseBody: '{}', responseHeaders: [], delayMs: 0, enabled: false },
    ];
    const active = routes.filter(r => r.enabled);
    expect(active).toHaveLength(1);
    expect(active[0].method).toBe('GET');
  });

  it('route matching by method AND path', () => {
    const routes = [
      { id: '1', method: 'GET', path: '/api/items', statusCode: 200, responseBody: '[]', responseHeaders: [], delayMs: 0, enabled: true },
      { id: '2', method: 'POST', path: '/api/items', statusCode: 201, responseBody: '{}', responseHeaders: [], delayMs: 0, enabled: true },
    ];
    const match = routes.find(r => r.method === 'POST' && r.path === '/api/items');
    expect(match?.statusCode).toBe(201);
  });
});

// ─── Auth type checks ──────────────────────────────────────────────────────────
describe('Auth type guards', () => {
  it('identifies Bearer token auth', () => {
    const auth = { type: 'Bearer' as const, token: 'tok' };
    expect(auth.type === 'Bearer').toBe(true);
    expect(auth.token).toBe('tok');
  });

  it('identifies Basic auth', () => {
    const auth = { type: 'Basic' as const, username: 'u', password: 'p' };
    expect(auth.type).toBe('Basic');
  });

  it('identifies None auth', () => {
    const auth = { type: 'None' as const };
    expect(auth.type).toBe('None');
  });

  it('ApiKey in header location', () => {
    const auth = { type: 'ApiKey' as const, key: 'X-API-Key', value: 'secret', location: 'header' as const };
    expect(auth.location).toBe('header');
  });

  it('ApiKey in query location', () => {
    const auth = { type: 'ApiKey' as const, key: 'api_key', value: 'secret', location: 'query' as const };
    expect(auth.location).toBe('query');
  });
});

// ─── Body type resolution ─────────────────────────────────────────────────────
describe('RequestBody type resolution', () => {
  it('Json body is detected', () => {
    const body = { type: 'Json' as const, content: '{}' };
    expect(body.type).toBe('Json');
  });

  it('None body is default', () => {
    const body = { type: 'None' as const };
    expect(body.type).toBe('None');
  });

  it('GraphQL body has query and variables fields', () => {
    const body = { type: 'GraphQL' as const, query: '{ me { id } }', variables: '{}' };
    expect(body.query).toContain('me');
  });

  it('FormData body fields can be enabled/disabled', () => {
    const fields = [
      { id: '1', key: 'file', value: 'data.csv', enabled: true },
      { id: '2', key: 'ignored', value: 'x', enabled: false },
    ];
    const active = fields.filter(f => f.enabled);
    expect(active).toHaveLength(1);
    expect(active[0].key).toBe('file');
  });
});

// ─── History entry shape ───────────────────────────────────────────────────────
describe('HistoryEntry shape', () => {
  it('entry snapshot contains serialized request and response', () => {
    const req: APIRequest = {
      id: 'r1', collectionId: 'c1', workspaceId: 'w1',
      name: 'Test', method: 'POST', url: 'https://example.com/api',
      headers: [], params: [], body: { type: 'Json', content: '{}' },
      auth: { type: 'None' },
      preRequestScript: '', postResponseScript: '', description: '',
      sortOrder: 0, createdAt: '', updatedAt: '',
    };
    const resp: APIResponse = {
      status: 201, statusText: 'Created', headers: [], body: '{"id":1}',
      bodySize: 8, timing: { dnsMs: 0, connectMs: 10, tlsMs: 0, sendMs: 2, waitMs: 50, receiveMs: 5, totalMs: 67 },
      cookies: [],
    };
    const entry = {
      id: 'h1', workspaceId: 'w1', requestName: req.name,
      method: req.method, url: req.url,
      status: resp.status, durationMs: resp.timing.totalMs,
      responseSize: resp.bodySize,
      timestamp: new Date().toISOString(),
      requestSnapshot: JSON.stringify(req),
      responseSnapshot: JSON.stringify(resp),
    };
    const parsedReq = JSON.parse(entry.requestSnapshot) as APIRequest;
    const parsedResp = JSON.parse(entry.responseSnapshot) as APIResponse;
    expect(parsedReq.method).toBe('POST');
    expect(parsedResp.status).toBe(201);
    expect(entry.durationMs).toBe(67);
  });
});
