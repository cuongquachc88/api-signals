import React, { useState } from 'react';
import { clsx } from 'clsx';

const INDENT = 16; // px per depth level

function PrimitiveValue({ value }: { value: unknown }) {
  if (value === null) return <span className="text-gray-500 font-mono text-xs">null</span>;
  if (typeof value === 'boolean') return <span className="text-green-400 font-mono text-xs">{String(value)}</span>;
  if (typeof value === 'number') return <span className="text-blue-300 font-mono text-xs">{String(value)}</span>;
  if (typeof value === 'string') {
    const str = value.length > 120 ? value.slice(0, 120) + '…' : value;
    return <span className="text-amber-300 font-mono text-xs break-all">"{str}"</span>;
  }
  return <span className="text-gray-400 font-mono text-xs">{String(value)}</span>;
}

function JsonNode({
  data,
  keyName,
  depth,
  isLast,
}: {
  data: unknown;
  keyName?: string;
  depth: number;
  isLast: boolean;
}) {
  const isExpandable = data !== null && typeof data === 'object';
  const isArray = Array.isArray(data);
  const [expanded, setExpanded] = useState(depth < 2);

  const indentPx = depth * INDENT;

  const copyValue = (e: React.MouseEvent) => {
    e.stopPropagation();
    navigator.clipboard.writeText(JSON.stringify(data, null, 2));
  };

  // ── Primitive ────────────────────────────────────────────────────────────────
  if (!isExpandable) {
    return (
      <div
        className="flex items-baseline gap-1 group hover:bg-white/5 rounded px-1 py-px"
        style={{ paddingLeft: `${indentPx + 12}px` }}
      >
        {keyName !== undefined && (
          <span className="text-purple-300 font-mono text-xs shrink-0">"{keyName}":</span>
        )}
        <PrimitiveValue value={data} />
        {!isLast && <span className="text-gray-600 font-mono text-xs">,</span>}
        <button
          onClick={copyValue}
          className="opacity-0 group-hover:opacity-100 text-gray-600 hover:text-gray-400 text-[10px] ml-auto shrink-0"
        >
          copy
        </button>
      </div>
    );
  }

  // ── Object / Array ───────────────────────────────────────────────────────────
  const entries = isArray
    ? (data as unknown[]).map((v, i) => [i, v] as [number, unknown])
    : Object.entries(data as Record<string, unknown>);
  const count = entries.length;
  const openBracket = isArray ? '[' : '{';
  const closeBracket = isArray ? ']' : '}';

  return (
    <div>
      {/* Header row */}
      <div
        className="flex items-baseline gap-1 cursor-pointer select-none hover:bg-white/5 rounded px-1 py-px group"
        style={{ paddingLeft: `${indentPx}px` }}
        onClick={() => setExpanded(e => !e)}
      >
        <span className="text-gray-500 font-mono text-xs w-3 shrink-0 text-center">
          {expanded ? '▾' : '▸'}
        </span>
        {keyName !== undefined && (
          <span className="text-purple-300 font-mono text-xs shrink-0">"{keyName}":</span>
        )}
        <span className="text-gray-300 font-mono text-xs">{openBracket}</span>
        {!expanded && (
          <span className="text-gray-500 font-mono text-xs">
            {count} {count === 1 ? (isArray ? 'item' : 'key') : (isArray ? 'items' : 'keys')}
            <span className="text-gray-300 ml-0.5">{closeBracket}</span>
            {!isLast && <span className="text-gray-600">,</span>}
          </span>
        )}
        <button
          onClick={copyValue}
          className="opacity-0 group-hover:opacity-100 text-gray-600 hover:text-gray-400 text-[10px] ml-auto shrink-0"
        >
          copy
        </button>
      </div>

      {/* Children */}
      {expanded && (
        <>
          {entries.map(([k, v], i) => (
            <JsonNode
              key={String(k)}
              data={v}
              keyName={isArray ? undefined : String(k)}
              depth={depth + 1}
              isLast={i === entries.length - 1}
            />
          ))}
          {/* Closing bracket */}
          <div
            className="font-mono text-xs text-gray-300 px-1 py-px"
            style={{ paddingLeft: `${indentPx + 12}px` }}
          >
            {closeBracket}
            {!isLast && <span className="text-gray-600">,</span>}
          </div>
        </>
      )}
    </div>
  );
}

interface Props {
  json: string;
}

export function JsonTreeView({ json }: Props) {
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
          onClick={() => navigator.clipboard.writeText(json)}
          className="text-xs text-gray-500 hover:text-gray-300"
        >
          Copy All
        </button>
      </div>
      <div className="flex-1 overflow-auto p-2">
        <JsonNode data={parsed} depth={0} isLast={true} />
      </div>
    </div>
  );
}
