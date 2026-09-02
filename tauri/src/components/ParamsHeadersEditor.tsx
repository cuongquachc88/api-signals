import React from 'react';
import type { KeyValue } from '../types';
import { uuid } from '../utils/uuid';

interface Props {
  items: KeyValue[];
  onChange: (items: KeyValue[]) => void;
  keyPlaceholder?: string;
  valuePlaceholder?: string;
}

export function ParamsHeadersEditor({ items, onChange, keyPlaceholder = 'Key', valuePlaceholder = 'Value' }: Props) {
  const addRow = () => {
    onChange([...items, { id: uuid(), key: '', value: '', enabled: true, description: null }]);
  };

  const updateItem = (id: string, field: keyof KeyValue, value: string | boolean) => {
    onChange(items.map(item => item.id === id ? { ...item, [field]: value } : item));
  };

  const removeItem = (id: string) => {
    onChange(items.filter(item => item.id !== id));
  };

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto">
        <table className="w-full text-sm">
          <thead className="sticky top-0 bg-gray-850">
            <tr className="text-gray-400 text-xs border-b border-gray-700">
              <th className="w-8 py-1.5"></th>
              <th className="text-left py-1.5 px-2 font-medium">{keyPlaceholder}</th>
              <th className="text-left py-1.5 px-2 font-medium">{valuePlaceholder}</th>
              <th className="w-8"></th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id} className="border-b border-gray-800 group hover:bg-gray-800/40">
                <td className="px-1.5 py-1">
                  <input
                    type="checkbox"
                    checked={item.enabled}
                    onChange={(e) => updateItem(item.id, 'enabled', e.target.checked)}
                    className="accent-blue-500"
                  />
                </td>
                <td className="py-1 px-1">
                  <input
                    className="w-full bg-transparent text-gray-200 placeholder-gray-600 outline-none px-1 py-0.5"
                    value={item.key}
                    placeholder={keyPlaceholder}
                    onChange={(e) => updateItem(item.id, 'key', e.target.value)}
                  />
                </td>
                <td className="py-1 px-1">
                  <input
                    className="w-full bg-transparent text-gray-200 placeholder-gray-600 outline-none px-1 py-0.5"
                    value={item.value}
                    placeholder={valuePlaceholder}
                    onChange={(e) => updateItem(item.id, 'value', e.target.value)}
                  />
                </td>
                <td className="px-1">
                  <button
                    onClick={() => removeItem(item.id)}
                    className="opacity-0 group-hover:opacity-100 text-gray-500 hover:text-red-400 p-0.5"
                  >
                    <svg className="w-3.5 h-3.5" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5">
                      <path d="M3 3L11 11M11 3L3 11" strokeLinecap="round"/>
                    </svg>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="p-2 border-t border-gray-700">
        <button
          onClick={addRow}
          className="text-xs text-blue-400 hover:text-blue-300 flex items-center gap-1"
        >
          <svg className="w-3 h-3" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M6 1v10M1 6h10" strokeLinecap="round"/>
          </svg>
          Add row
        </button>
      </div>
    </div>
  );
}
