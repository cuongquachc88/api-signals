import React, { useState } from 'react';
import { clsx } from 'clsx';
import { useAppStore } from '../store/appStore';
import type { Environment, Variable } from '../types';
import { uuid } from '../utils/uuid';

function EnvironmentModal({
  env,
  onSave,
  onClose,
}: {
  env: Environment;
  onSave: (env: Environment) => void;
  onClose: () => void;
}) {
  const [name, setName] = useState(env.name);
  const [variables, setVariables] = useState<Variable[]>(env.variables);

  const addVar = () => {
    setVariables(v => [...v, { id: uuid(), key: '', value: '', enabled: true, secret: false }]);
  };

  const updateVar = (id: string, field: keyof Variable, value: string | boolean) => {
    setVariables(v => v.map(item => item.id === id ? { ...item, [field]: value } : item));
  };

  const removeVar = (id: string) => {
    setVariables(v => v.filter(item => item.id !== id));
  };

  const handleSave = () => {
    onSave({ ...env, name: name.trim() || env.name, variables });
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-gray-900 border border-gray-700 rounded-lg w-[600px] max-h-[80vh] flex flex-col shadow-2xl">
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h2 className="text-sm font-semibold text-white">Edit Environment</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-white">
            <svg className="w-4 h-4" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M2 2l10 10M12 2L2 12" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col gap-3 p-4 flex-1 overflow-auto">
          <div>
            <label className="text-xs text-gray-400 font-medium">Name</label>
            <input
              className="mt-1 w-full bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>

          <div className="flex-1">
            <div className="flex items-center justify-between mb-1">
              <label className="text-xs text-gray-400 font-medium">Variables</label>
              <button onClick={addVar} className="text-xs text-blue-400 hover:text-blue-300">+ Add</button>
            </div>
            <table className="w-full text-xs">
              <thead>
                <tr className="text-gray-500 border-b border-gray-700">
                  <th className="w-6 text-left py-1"></th>
                  <th className="text-left py-1 px-1">Key</th>
                  <th className="text-left py-1 px-1">Value</th>
                  <th className="w-6 text-left py-1">Secret</th>
                  <th className="w-6"></th>
                </tr>
              </thead>
              <tbody>
                {variables.map(v => (
                  <tr key={v.id} className="border-b border-gray-800">
                    <td className="py-0.5 px-1">
                      <input type="checkbox" checked={v.enabled}
                        onChange={(e) => updateVar(v.id, 'enabled', e.target.checked)}
                        className="accent-blue-500" />
                    </td>
                    <td className="py-0.5 px-1">
                      <input className="w-full bg-gray-800 text-gray-200 rounded px-1 py-0.5 outline-none text-xs"
                        value={v.key} placeholder="KEY"
                        onChange={(e) => updateVar(v.id, 'key', e.target.value)} />
                    </td>
                    <td className="py-0.5 px-1">
                      <input
                        type={v.secret ? 'password' : 'text'}
                        className="w-full bg-gray-800 text-gray-200 rounded px-1 py-0.5 outline-none text-xs"
                        value={v.value} placeholder="value"
                        onChange={(e) => updateVar(v.id, 'value', e.target.value)} />
                    </td>
                    <td className="py-0.5 px-1 text-center">
                      <input type="checkbox" checked={v.secret}
                        onChange={(e) => updateVar(v.id, 'secret', e.target.checked)}
                        className="accent-purple-500" />
                    </td>
                    <td className="py-0.5 px-1">
                      <button onClick={() => removeVar(v.id)} className="text-gray-600 hover:text-red-400">
                        <svg className="w-3 h-3" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2">
                          <path d="M2 2l6 6M8 2L2 8" strokeLinecap="round" />
                        </svg>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="flex justify-end gap-2 px-4 py-3 border-t border-gray-700">
          <button onClick={onClose}
            className="px-3 py-1.5 text-sm text-gray-400 hover:text-white rounded border border-gray-700 hover:border-gray-500">
            Cancel
          </button>
          <button onClick={handleSave}
            className="px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded">
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

export function EnvironmentBar() {
  const {
    environments, activeEnvironmentId, setActiveEnvironment,
    createEnvironment, updateEnvironment, deleteEnvironment,
  } = useAppStore();

  const [isOpen, setIsOpen] = useState(false);
  const [editingEnv, setEditingEnv] = useState<Environment | null>(null);
  const [showDropdown, setShowDropdown] = useState(false);

  const activeEnv = environments.find(e => e.id === activeEnvironmentId);
  const activeVarCount = activeEnv ? activeEnv.variables.filter(v => v.enabled && v.key).length : 0;

  const handleNewEnv = async () => {
    const name = prompt('Environment name:');
    if (name?.trim()) {
      await createEnvironment(name.trim());
    }
  };

  return (
    <>
      <div className="relative">
        <button
          onClick={() => setShowDropdown(!showDropdown)}
          className="flex items-center gap-1.5 px-2 py-1 text-xs rounded border border-gray-700 hover:border-gray-500 bg-gray-800 text-gray-300"
        >
          <span className={clsx('w-1.5 h-1.5 rounded-full shrink-0', activeEnv ? 'bg-green-500' : 'bg-gray-600')} />
          {activeEnv ? (
            <>
              {activeEnv.name}
              {activeVarCount > 0 && (
                <span className="ml-1 text-[9px] bg-gray-700 text-gray-400 rounded-full px-1.5 py-0.5 font-mono">
                  {activeVarCount}
                </span>
              )}
            </>
          ) : 'No Environment'}
          <svg className="w-3 h-3 text-gray-500" viewBox="0 0 10 10" fill="currentColor">
            <path d="M2 4l3 3 3-3" />
          </svg>
        </button>

        {showDropdown && (
          <div className="absolute right-0 top-full mt-1 bg-gray-900 border border-gray-700 rounded-lg shadow-2xl w-56 z-50">
            <div className="py-1">
              <button
                className={clsx(
                  'w-full text-left px-3 py-1.5 text-xs hover:bg-gray-800 flex items-center gap-2',
                  !activeEnvironmentId ? 'text-blue-400' : 'text-gray-400'
                )}
                onClick={() => { setActiveEnvironment(null); setShowDropdown(false); }}
              >
                <span className="w-1.5 h-1.5 rounded-full bg-gray-600" />
                No Environment
              </button>

              {environments.map(env => {
                const varCount = env.variables.filter(v => v.enabled && v.key).length;
                return (
                <div key={env.id} className="flex items-center group">
                  <button
                    className={clsx(
                      'flex-1 text-left px-3 py-1.5 text-xs hover:bg-gray-800 flex items-center gap-2',
                      env.id === activeEnvironmentId ? 'text-blue-400' : 'text-gray-300'
                    )}
                    onClick={() => { setActiveEnvironment(env.id); setShowDropdown(false); }}
                  >
                    <span className={clsx('w-1.5 h-1.5 rounded-full shrink-0',
                      env.id === activeEnvironmentId ? 'bg-green-500' : 'bg-gray-600')} />
                    <span className="flex-1">{env.name}</span>
                    {varCount > 0 && (
                      <span className="text-[9px] bg-gray-700 text-gray-500 rounded-full px-1.5 font-mono">{varCount}</span>
                    )}
                  </button>
                  <button
                    onClick={(e) => { e.stopPropagation(); setEditingEnv(env); setShowDropdown(false); }}
                    className="opacity-0 group-hover:opacity-100 p-1 text-gray-500 hover:text-gray-300"
                  >
                    <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
                      <path d="M2 10l1.5-1.5L9 3 10 4l-5.5 5.5L3 11z" />
                      <path d="M7.5 2.5l2 2" />
                    </svg>
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      if (confirm(`Delete environment "${env.name}"?`)) deleteEnvironment(env.id);
                    }}
                    className="opacity-0 group-hover:opacity-100 p-1 text-gray-500 hover:text-red-400"
                  >
                    <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
                      <path d="M3 3L9 9M9 3L3 9" strokeLinecap="round" />
                    </svg>
                  </button>
                </div>
              ); })}

              <div className="border-t border-gray-700 mt-1 pt-1">
                <button
                  onClick={() => { handleNewEnv(); setShowDropdown(false); }}
                  className="w-full text-left px-3 py-1.5 text-xs text-blue-400 hover:bg-gray-800 flex items-center gap-2"
                >
                  <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
                    <path d="M6 1v10M1 6h10" strokeLinecap="round" />
                  </svg>
                  New Environment
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {editingEnv && (
        <EnvironmentModal
          env={editingEnv}
          onSave={(env) => updateEnvironment(env)}
          onClose={() => setEditingEnv(null)}
        />
      )}

      {showDropdown && (
        <div className="fixed inset-0 z-40" onClick={() => setShowDropdown(false)} />
      )}
    </>
  );
}
