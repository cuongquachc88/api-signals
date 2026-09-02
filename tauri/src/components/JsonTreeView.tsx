import React, { useState, useCallback } from 'react';
import { clsx } from 'clsx';

interface JsonNodeProps {
  data: unknown;
  keyName?: string;
  depth?: number;
  defaultExpanded?: boolean;
}

function JsonNode({ data, keyName, depth = 0, defaultExpanded = true }: JsonNodeProps) {
  const [expanded, setExpanded] = useState(defaultExpanded && depth < 2);

  const copyValue = (e: React.MouseEvent) => {
    e.stopPropagation();
    navigator.clipboard.writeText(JSON.stringify(data, null, 2));
  };

  const isExpandable = data !== null && typeof data === 'object';
  const isArray = Array.isArray(data);

  if (!isExpandable) {
    const primitive = data;
    return (
      <div className="flex items-baseline gap-1 group pl-1 hover:bg-white/5 rounded">
        {keyName !== undefined && (
          <span className="text-purple-300 shrink-0 font-mono text-xs">"{keyName}":</span>
        )}
        <span className={clsx('font-mono text-xs', {
          'text-amber-300': typeof primitive === 'string',
          'text-blue-300': typeof primitive === 'number',
          'text-green-300': typeof primitive === 'boolean',
          'text-gray-500': primitive === null,
        })}>
          {primitive === null ? 'null' : typeof primitive === 'string'
            ? `"${(primitive as string).length > 100 ? (primitive as string).slice(0, 100) + '...' : primitive}"`
            : String(primitive)}
        </span>
        <button
          onClick={copyValue}
          className="opacity-0 group-hover:opacity-100 text-gray-600 hover:text-gray-400 text-[10px] ml-1"
        >
          copy
        </button>
      </div>
    );
  }

  const entries = isArray
    ? (data as unknown[]).map((v, i) => [String(i), v] as [string, unknown])
    : Object.entries(data as Record<string, unknown>);

  const count = entries.length;

  return (
    <div>
      <div
        className="flex items-baseline gap-1 cursor-pointer select-none hover:bg-white/5 rounded group"
        onClick={() => setExpanded(!expanded)}
      >
        <span className="text-gray-500 w-3 text-xs shrink-0">{expanded ? '▾' : '▸'}</span>
        {keyName !== undefined && (
          <span className="text-purple-300 font-mono text-xs">"{keyName}":</span>
        )}
        <span className="text-gray-400 font-mono text-xs">
          {isArray ? '[' : '{'}
        </span>
        {!expanded && (
          <span className="text-gray-500 font-mono text-xs">
            {count} {count === 1 ? (isArray ? 'item' : 'key') : (isArray ? 'items' : 'keys')}
            {isArray ? ']' : '}'}
          </span>
        )}
        <button
          onClick={copyValue}
          className="opacity-0 group-hover:opacity-100 text-gray-600 hover:text-gray-400 text-[10px] ml-1"
        >
          copy
        </button>
      </div>

      {expanded && (
        <div className="ml-4 border-l border-gray-800 pl-2">
          {entries.map(([k, v]) => (
            <JsonNode
              key={k}
              data={v}
              keyName={isArray ? undefined : k}
              depth={depth + 1}
              defaultExpanded={depth < 1}
            />
          ))}
        </div>
      )}

      {expanded && (
        <span className="text-gray-400 font-mono text-xs ml-1 pl-1">
          {isArray ? ']' : '}'}
        </span>
      )}
    </div>
  );
}

interface Props {
  json: string;
}

export function JsonTreeView({ json }: Props) {
  const [expandAll, setExpandAll] = useState(false);
  const [parsed, error] = React.useMemo(() => {
    try {
      return [JSON.parse(json), null];
    } catch (e) {
      return [null, String(e)];
    }
  }, [json]);

  if (error) {
    return (
      <div className="p-3 text-red-400 text-xs font-mono">
        Invalid JSON: {error}
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center gap-2 px-2 py-1 border-b border-gray-800 shrink-0">
        <button
          onClick={() => setExpandAll(!expandAll)}
          className="text-xs text-gray-500 hover:text-gray-300"
        >
          {expandAll ? 'Collapse All' : 'Expand All'}
        </button>
        <button
          onClick={() => navigator.clipboard.writeText(json)}
          className="text-xs text-gray-500 hover:text-gray-300"
        >
          Copy All
        </button>
      </div>
      <div className="flex-1 overflow-auto p-2 font-mono">
        <JsonNode data={parsed} defaultExpanded={true} />
      </div>
    </div>
  );
}
