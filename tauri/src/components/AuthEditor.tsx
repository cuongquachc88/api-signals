import React from 'react';
import type { Auth } from '../types';

interface Props {
  auth: Auth;
  onChange: (auth: Auth) => void;
}

const AUTH_TYPES = ['None', 'Bearer', 'Basic', 'ApiKey', 'OAuth2', 'Digest'] as const;

export function AuthEditor({ auth, onChange }: Props) {
  const Input = ({ label, value, onChange: onC, type = 'text', placeholder = '' }: {
    label: string; value: string; onChange: (v: string) => void; type?: string; placeholder?: string;
  }) => (
    <div className="flex flex-col gap-1">
      <label className="text-xs text-gray-400 font-medium">{label}</label>
      <input
        type={type}
        className="bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm outline-none border border-gray-700 focus:border-blue-500"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onC(e.target.value)}
      />
    </div>
  );

  return (
    <div className="p-3 flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <label className="text-xs text-gray-400 font-medium">Auth Type</label>
        <select
          className="bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm outline-none border border-gray-700 focus:border-blue-500"
          value={auth.type}
          onChange={(e) => {
            const t = e.target.value;
            if (t === 'None') onChange({ type: 'None' });
            else if (t === 'Bearer') onChange({ type: 'Bearer', token: '' });
            else if (t === 'Basic') onChange({ type: 'Basic', username: '', password: '' });
            else if (t === 'ApiKey') onChange({ type: 'ApiKey', key: '', value: '', location: 'header' });
            else if (t === 'OAuth2') onChange({ type: 'OAuth2', grantType: 'authorization_code', authUrl: '', tokenUrl: '', clientId: '', clientSecret: '', scope: '', accessToken: null });
            else if (t === 'Digest') onChange({ type: 'Digest', username: '', password: '' });
          }}
        >
          {AUTH_TYPES.map(t => <option key={t} value={t}>{t === 'None' ? 'No Auth' : t === 'ApiKey' ? 'API Key' : t}</option>)}
        </select>
      </div>

      {auth.type === 'Bearer' && (
        <Input label="Token" value={auth.token} placeholder="Bearer token..."
          onChange={(v) => onChange({ ...auth, token: v })} />
      )}

      {(auth.type === 'Basic' || auth.type === 'Digest') && (
        <>
          <Input label="Username" value={auth.username} placeholder="username"
            onChange={(v) => onChange({ ...auth, username: v })} />
          <Input label="Password" type="password" value={auth.password} placeholder="password"
            onChange={(v) => onChange({ ...auth, password: v })} />
        </>
      )}

      {auth.type === 'ApiKey' && (
        <>
          <Input label="Key" value={auth.key} placeholder="X-API-Key"
            onChange={(v) => onChange({ ...auth, key: v })} />
          <Input label="Value" value={auth.value} placeholder="api_key_value"
            onChange={(v) => onChange({ ...auth, value: v })} />
          <div className="flex flex-col gap-1">
            <label className="text-xs text-gray-400 font-medium">Add to</label>
            <select
              className="bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm outline-none border border-gray-700 focus:border-blue-500"
              value={auth.location}
              onChange={(e) => onChange({ ...auth, location: e.target.value as 'header' | 'query' })}
            >
              <option value="header">Header</option>
              <option value="query">Query Parameter</option>
            </select>
          </div>
        </>
      )}

      {auth.type === 'OAuth2' && (
        <>
          <div className="flex flex-col gap-1">
            <label className="text-xs text-gray-400 font-medium">Grant Type</label>
            <select
              className="bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm outline-none border border-gray-700 focus:border-blue-500"
              value={auth.grantType}
              onChange={(e) => onChange({ ...auth, grantType: e.target.value })}
            >
              <option value="authorization_code">Authorization Code</option>
              <option value="client_credentials">Client Credentials</option>
              <option value="password">Resource Owner Password</option>
              <option value="implicit">Implicit</option>
            </select>
          </div>
          <Input label="Auth URL" value={auth.authUrl} placeholder="https://provider.com/auth"
            onChange={(v) => onChange({ ...auth, authUrl: v })} />
          <Input label="Token URL" value={auth.tokenUrl} placeholder="https://provider.com/token"
            onChange={(v) => onChange({ ...auth, tokenUrl: v })} />
          <Input label="Client ID" value={auth.clientId} placeholder="client_id"
            onChange={(v) => onChange({ ...auth, clientId: v })} />
          <Input label="Client Secret" type="password" value={auth.clientSecret} placeholder="client_secret"
            onChange={(v) => onChange({ ...auth, clientSecret: v })} />
          <Input label="Scope" value={auth.scope} placeholder="openid profile email"
            onChange={(v) => onChange({ ...auth, scope: v })} />
          {auth.accessToken && (
            <div className="bg-green-900/20 border border-green-700/40 rounded p-2">
              <p className="text-xs text-green-400 font-medium mb-1">Access Token</p>
              <p className="text-xs text-gray-300 font-mono break-all">{auth.accessToken}</p>
            </div>
          )}
          <button className="bg-blue-600 hover:bg-blue-700 text-white text-sm rounded px-3 py-1.5 self-start">
            Get New Access Token
          </button>
        </>
      )}

      {auth.type === 'None' && (
        <p className="text-sm text-gray-500">No authentication configured for this request.</p>
      )}
    </div>
  );
}
