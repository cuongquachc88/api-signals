// ─── Workspace ────────────────────────────────────────────────────────────────
export interface Workspace {
  id: string;
  name: string;
  createdAt: string;
  updatedAt: string;
}

// ─── Collection ───────────────────────────────────────────────────────────────
export interface Collection {
  id: string;
  workspaceId: string;
  parentId: string | null;
  name: string;
  description: string | null;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

// ─── Key/Value ────────────────────────────────────────────────────────────────
export interface KeyValue {
  id: string;
  key: string;
  value: string;
  enabled: boolean;
  description?: string | null;
}

// ─── Auth ─────────────────────────────────────────────────────────────────────
export type Auth =
  | { type: 'None' }
  | { type: 'Bearer'; token: string }
  | { type: 'Basic'; username: string; password: string }
  | { type: 'ApiKey'; key: string; value: string; location: 'header' | 'query' }
  | { type: 'OAuth2'; grantType: string; authUrl: string; tokenUrl: string; clientId: string; clientSecret: string; scope: string; accessToken: string | null }
  | { type: 'Digest'; username: string; password: string };

// ─── Request Body ─────────────────────────────────────────────────────────────
export type RequestBody =
  | { type: 'None' }
  | { type: 'Json'; content: string }
  | { type: 'Raw'; content: string; contentType: string }
  | { type: 'FormData'; fields: KeyValue[] }
  | { type: 'UrlEncoded'; fields: KeyValue[] }
  | { type: 'Binary'; filePath: string }
  | { type: 'GraphQL'; query: string; variables: string };

// ─── APIRequest ───────────────────────────────────────────────────────────────
export interface APIRequest {
  id: string;
  collectionId: string;
  workspaceId: string;
  name: string;
  method: HttpMethod;
  url: string;
  headers: KeyValue[];
  params: KeyValue[];
  body: RequestBody;
  auth: Auth;
  preRequestScript: string;
  postResponseScript: string;
  description: string;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD' | 'OPTIONS' | 'TRACE' | 'CONNECT';

export const HTTP_METHODS: HttpMethod[] = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE'];

// ─── Response ─────────────────────────────────────────────────────────────────
export interface RequestTiming {
  dnsMs: number;
  connectMs: number;
  tlsMs: number;
  sendMs: number;
  waitMs: number;
  receiveMs: number;
  totalMs: number;
}

export interface Cookie {
  name: string;
  value: string;
  domain: string | null;
  path: string | null;
  expires: string | null;
  httpOnly: boolean;
  secure: boolean;
}

export interface APIResponse {
  status: number;
  statusText: string;
  headers: KeyValue[];
  body: string;
  bodySize: number;
  timing: RequestTiming;
  cookies: Cookie[];
}

// ─── Environment ──────────────────────────────────────────────────────────────
export interface Variable {
  id: string;
  key: string;
  value: string;
  enabled: boolean;
  secret: boolean;
}

export interface Environment {
  id: string;
  workspaceId: string;
  name: string;
  variables: Variable[];
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// ─── History ──────────────────────────────────────────────────────────────────
export interface HistoryEntry {
  id: string;
  workspaceId: string;
  requestName: string;
  method: HttpMethod;
  url: string;
  status: number;
  durationMs: number;
  responseSize: number;
  timestamp: string;
  requestSnapshot: string;
  responseSnapshot: string;
}

// ─── MockRoute ────────────────────────────────────────────────────────────────
export interface MockRoute {
  id: string;
  method: string;
  path: string;
  statusCode: number;
  responseBody: string;
  responseHeaders: KeyValue[];
  delayMs: number;
  enabled: boolean;
}

// ─── Settings ─────────────────────────────────────────────────────────────────
export interface AppSettings {
  theme: 'dark' | 'light';
  timeoutMs: number;
  sslVerify: boolean;
  proxyUrl: string | null;
  followRedirects: boolean;
  maxRedirects: number;
}

// ─── Tab ─────────────────────────────────────────────────────────────────────
export interface Tab {
  id: string;
  requestId: string;
  isDirty: boolean;
  request: APIRequest;
  response: APIResponse | null;
  isLoading: boolean;
}

// ─── Execute Options ──────────────────────────────────────────────────────────
export interface ExecuteRequestOptions {
  timeoutMs?: number;
  sslVerify?: boolean;
  followRedirects?: boolean;
  proxyUrl?: string | null;
  variables?: Record<string, string>;
}

// ─── Import/Export ────────────────────────────────────────────────────────────
export interface PostmanImportResult {
  collectionName: string;
  requests: APIRequest[];
}
