import { describe, it, expect } from 'vitest';
import { HTTP_METHODS } from '../types';
import type {
  Workspace, Collection, APIRequest, Auth, RequestBody,
  APIResponse, Environment, Variable, HistoryEntry, MockRoute,
  AppSettings, Tab, KeyValue, RequestTiming, Cookie,
} from '../types';

// ─── Type shape tests ─────────────────────────────────────────────────────────
// These tests verify TypeScript types resolve correctly at runtime and that
// objects constructed with the expected shape satisfy the interfaces.

describe('HTTP_METHODS', () => {
  it('contains the 8 standard methods', () => {
    expect(HTTP_METHODS).toContain('GET');
    expect(HTTP_METHODS).toContain('POST');
    expect(HTTP_METHODS).toContain('PUT');
    expect(HTTP_METHODS).toContain('PATCH');
    expect(HTTP_METHODS).toContain('DELETE');
    expect(HTTP_METHODS).toContain('HEAD');
    expect(HTTP_METHODS).toContain('OPTIONS');
    expect(HTTP_METHODS).toContain('TRACE');
  });

  it('does not contain CONNECT (not in array)', () => {
    expect(HTTP_METHODS).not.toContain('CONNECT');
  });
});

describe('Auth union type', () => {
  it('None auth has correct shape', () => {
    const auth: Auth = { type: 'None' };
    expect(auth.type).toBe('None');
  });

  it('Bearer auth has token', () => {
    const auth: Auth = { type: 'Bearer', token: 'abc123' };
    expect((auth as Extract<Auth, { type: 'Bearer' }>).token).toBe('abc123');
  });

  it('Basic auth has username and password', () => {
    const auth: Auth = { type: 'Basic', username: 'user', password: 'pass' };
    const basic = auth as Extract<Auth, { type: 'Basic' }>;
    expect(basic.username).toBe('user');
    expect(basic.password).toBe('pass');
  });

  it('ApiKey header location', () => {
    const auth: Auth = { type: 'ApiKey', key: 'X-Key', value: 'secret', location: 'header' };
    const ak = auth as Extract<Auth, { type: 'ApiKey' }>;
    expect(ak.location).toBe('header');
  });

  it('ApiKey query location', () => {
    const auth: Auth = { type: 'ApiKey', key: 'api_key', value: 'v', location: 'query' };
    const ak = auth as Extract<Auth, { type: 'ApiKey' }>;
    expect(ak.location).toBe('query');
  });

  it('OAuth2 auth has required fields', () => {
    const auth: Auth = {
      type: 'OAuth2',
      grantType: 'authorization_code',
      authUrl: 'https://example.com/auth',
      tokenUrl: 'https://example.com/token',
      clientId: 'id',
      clientSecret: 'secret',
      scope: 'read',
      accessToken: null,
    };
    expect((auth as Extract<Auth, { type: 'OAuth2' }>).grantType).toBe('authorization_code');
  });

  it('Digest auth has username and password', () => {
    const auth: Auth = { type: 'Digest', username: 'u', password: 'p' };
    const d = auth as Extract<Auth, { type: 'Digest' }>;
    expect(d.username).toBe('u');
  });
});

describe('RequestBody union type', () => {
  it('None body', () => {
    const body: RequestBody = { type: 'None' };
    expect(body.type).toBe('None');
  });

  it('Json body has content string', () => {
    const body: RequestBody = { type: 'Json', content: '{"key":"value"}' };
    expect((body as Extract<RequestBody, { type: 'Json' }>).content).toBe('{"key":"value"}');
  });

  it('Raw body has content and contentType', () => {
    const body: RequestBody = { type: 'Raw', content: 'hello', contentType: 'text/plain' };
    const raw = body as Extract<RequestBody, { type: 'Raw' }>;
    expect(raw.contentType).toBe('text/plain');
  });

  it('FormData body has fields array', () => {
    const field: KeyValue = { id: '1', key: 'file', value: 'data', enabled: true };
    const body: RequestBody = { type: 'FormData', fields: [field] };
    expect((body as Extract<RequestBody, { type: 'FormData' }>).fields).toHaveLength(1);
  });

  it('UrlEncoded body has fields array', () => {
    const field: KeyValue = { id: '1', key: 'foo', value: 'bar', enabled: true };
    const body: RequestBody = { type: 'UrlEncoded', fields: [field] };
    expect((body as Extract<RequestBody, { type: 'UrlEncoded' }>).fields[0].key).toBe('foo');
  });

  it('Binary body has filePath', () => {
    const body: RequestBody = { type: 'Binary', filePath: '/tmp/file.bin' };
    expect((body as Extract<RequestBody, { type: 'Binary' }>).filePath).toBe('/tmp/file.bin');
  });

  it('GraphQL body has query and variables', () => {
    const body: RequestBody = { type: 'GraphQL', query: '{ users }', variables: '{}' };
    const gql = body as Extract<RequestBody, { type: 'GraphQL' }>;
    expect(gql.query).toBe('{ users }');
    expect(gql.variables).toBe('{}');
  });
});

describe('APIRequest shape', () => {
  const makeRequest = (): APIRequest => ({
    id: 'req-1',
    collectionId: 'col-1',
    workspaceId: 'ws-1',
    name: 'Test Request',
    method: 'GET',
    url: 'https://api.example.com/users',
    headers: [],
    params: [],
    body: { type: 'None' },
    auth: { type: 'None' },
    preRequestScript: '',
    postResponseScript: '',
    description: '',
    sortOrder: 0,
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
  });

  it('has all required fields', () => {
    const req = makeRequest();
    expect(req.id).toBe('req-1');
    expect(req.method).toBe('GET');
    expect(req.url).toBe('https://api.example.com/users');
    expect(req.body.type).toBe('None');
    expect(req.auth.type).toBe('None');
  });

  it('accepts all HTTP methods', () => {
    const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE'] as const;
    for (const method of methods) {
      const req = { ...makeRequest(), method };
      expect(req.method).toBe(method);
    }
  });
});

describe('APIResponse shape', () => {
  const timing: RequestTiming = {
    dnsMs: 10, connectMs: 20, tlsMs: 30,
    sendMs: 5, waitMs: 100, receiveMs: 15, totalMs: 180,
  };

  it('has correct timing fields', () => {
    expect(timing.totalMs).toBe(180);
    expect(timing.dnsMs).toBe(10);
  });

  it('2xx response shape', () => {
    const resp: APIResponse = {
      status: 200, statusText: 'OK',
      headers: [{ id: '1', key: 'content-type', value: 'application/json', enabled: true }],
      body: '{"ok":true}',
      bodySize: 11,
      timing,
      cookies: [],
    };
    expect(resp.status).toBe(200);
    expect(resp.headers[0].key).toBe('content-type');
  });

  it('cookie shape', () => {
    const cookie: Cookie = {
      name: 'session', value: 'abc', domain: '.example.com',
      path: '/', expires: null, httpOnly: true, secure: true,
    };
    expect(cookie.httpOnly).toBe(true);
  });
});

describe('Environment and Variable shape', () => {
  it('variable has enabled flag and secret flag', () => {
    const v: Variable = { id: '1', key: 'BASE_URL', value: 'https://api.example.com', enabled: true, secret: false };
    expect(v.enabled).toBe(true);
    expect(v.secret).toBe(false);
  });

  it('environment has variables array', () => {
    const env: Environment = {
      id: 'env-1', workspaceId: 'ws-1', name: 'Production',
      variables: [{ id: '1', key: 'K', value: 'V', enabled: true, secret: false }],
      isActive: true, createdAt: '', updatedAt: '',
    };
    expect(env.variables).toHaveLength(1);
    expect(env.isActive).toBe(true);
  });
});

describe('MockRoute shape', () => {
  it('has method, path, statusCode, responseBody', () => {
    const route: MockRoute = {
      id: 'm1', method: 'GET', path: '/api/users',
      statusCode: 200, responseBody: '[]',
      responseHeaders: [], delayMs: 0, enabled: true,
    };
    expect(route.statusCode).toBe(200);
    expect(route.enabled).toBe(true);
  });
});

describe('AppSettings shape', () => {
  it('default settings shape', () => {
    const s: AppSettings = {
      theme: 'dark', timeoutMs: 30000, sslVerify: true,
      proxyUrl: null, followRedirects: true, maxRedirects: 10,
    };
    expect(s.theme).toBe('dark');
    expect(s.proxyUrl).toBeNull();
  });

  it('light theme', () => {
    const s: AppSettings = {
      theme: 'light', timeoutMs: 5000, sslVerify: false,
      proxyUrl: 'http://proxy:8080', followRedirects: false, maxRedirects: 3,
    };
    expect(s.theme).toBe('light');
    expect(s.sslVerify).toBe(false);
  });
});

describe('Tab shape', () => {
  it('has request and response', () => {
    const tab: Tab = {
      id: 'tab-1',
      requestId: 'req-1',
      isDirty: false,
      request: {
        id: 'req-1', collectionId: 'col-1', workspaceId: 'ws-1',
        name: 'Test', method: 'GET', url: '', headers: [], params: [],
        body: { type: 'None' }, auth: { type: 'None' },
        preRequestScript: '', postResponseScript: '', description: '',
        sortOrder: 0, createdAt: '', updatedAt: '',
      },
      response: null,
      isLoading: false,
    };
    expect(tab.isDirty).toBe(false);
    expect(tab.response).toBeNull();
  });
});
