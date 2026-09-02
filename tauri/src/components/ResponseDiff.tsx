import React, { useState, useMemo } from 'react';
import { useAppStore } from '../store/appStore';

interface DiffLine {
  type: 'added' | 'removed' | 'same';
  text: string;
  lineNum: number;
}

function computeDiff(a: string, b: string): { left: DiffLine[]; right: DiffLine[] } {
  const linesA = a.split('\n');
  const linesB = b.split('\n');

  // Simple LCS-based diff
  const m = linesA.length;
  const n = linesB.length;
  const dp: number[][] = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      if (linesA[i - 1] === linesB[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }

  const left: DiffLine[] = [];
  const right: DiffLine[] = [];
  let i = m, j = n;
  const ops: Array<{ type: 'same' | 'removed' | 'added'; lineA?: number; lineB?: number }> = [];

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && linesA[i - 1] === linesB[j - 1]) {
      ops.unshift({ type: 'same', lineA: i - 1, lineB: j - 1 });
      i--; j--;
    } else if (j > 0 && (i === 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      ops.unshift({ type: 'added', lineB: j - 1 });
      j--;
    } else {
      ops.unshift({ type: 'removed', lineA: i - 1 });
      i--;
    }
  }

  let leftLine = 1, rightLine = 1;
  for (const op of ops) {
    if (op.type === 'same') {
      left.push({ type: 'same', text: linesA[op.lineA!], lineNum: leftLine++ });
      right.push({ type: 'same', text: linesB[op.lineB!], lineNum: rightLine++ });
    } else if (op.type === 'removed') {
      left.push({ type: 'removed', text: linesA[op.lineA!], lineNum: leftLine++ });
      right.push({ type: 'same', text: '', lineNum: 0 });
    } else {
      left.push({ type: 'same', text: '', lineNum: 0 });
      right.push({ type: 'added', text: linesB[op.lineB!], lineNum: rightLine++ });
    }
  }

  return { left, right };
}

function formatJson(str: string): string {
  try {
    return JSON.stringify(JSON.parse(str), null, 2);
  } catch {
    return str;
  }
}

function lineColor(type: DiffLine['type']): string {
  if (type === 'added') return 'bg-green-900/30 text-green-300';
  if (type === 'removed') return 'bg-red-900/30 text-red-300';
  return 'text-gray-300';
}

interface DiffPanelProps {
  lines: DiffLine[];
  label: string;
}

function DiffPanel({ lines, label }: DiffPanelProps) {
  return (
    <div className="flex-1 flex flex-col min-w-0">
      <div className="text-xs text-gray-400 px-3 py-1.5 border-b border-gray-700 bg-gray-850 font-medium">
        {label}
      </div>
      <div className="overflow-auto flex-1 font-mono text-xs">
        {lines.map((line, idx) => (
          <div key={idx} className={`flex items-start ${lineColor(line.type)}`}>
            <span className="w-8 text-right pr-2 text-gray-600 shrink-0 select-none border-r border-gray-800 py-0.5">
              {line.lineNum || ''}
            </span>
            <span className={`px-2 py-0.5 flex-1 whitespace-pre ${
              line.type === 'added' ? 'bg-green-900/20' :
              line.type === 'removed' ? 'bg-red-900/20' : ''
            }`}>
              {line.type === 'added' ? '+ ' : line.type === 'removed' ? '- ' : '  '}
              {line.text}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function ResponseDiff() {
  const { tabs } = useAppStore();
  const responsiveTabs = tabs.filter(t => t.response !== null);

  const [leftTabId, setLeftTabId] = useState<string>('');
  const [rightTabId, setRightTabId] = useState<string>('');
  const [showDiff, setShowDiff] = useState(false);

  const leftTab = tabs.find(t => t.id === leftTabId);
  const rightTab = tabs.find(t => t.id === rightTabId);

  const diff = useMemo(() => {
    if (!leftTab?.response || !rightTab?.response) return null;
    const a = formatJson(leftTab.response.body);
    const b = formatJson(rightTab.response.body);
    return computeDiff(a, b);
  }, [leftTab?.response?.body, rightTab?.response?.body]);

  return (
    <div className="flex flex-col h-full">
      {/* Controls */}
      <div className="flex items-center gap-3 px-3 py-2 border-b border-gray-700 shrink-0">
        <select
          className="bg-gray-800 text-gray-200 rounded px-2 py-1 text-xs border border-gray-700 outline-none flex-1"
          value={leftTabId}
          onChange={(e) => setLeftTabId(e.target.value)}
        >
          <option value="">Select left response...</option>
          {responsiveTabs.map(t => (
            <option key={t.id} value={t.id}>
              {t.request.method} {t.request.name} ({t.response?.status})
            </option>
          ))}
        </select>

        <span className="text-gray-600 text-xs shrink-0">vs</span>

        <select
          className="bg-gray-800 text-gray-200 rounded px-2 py-1 text-xs border border-gray-700 outline-none flex-1"
          value={rightTabId}
          onChange={(e) => setRightTabId(e.target.value)}
        >
          <option value="">Select right response...</option>
          {responsiveTabs.map(t => (
            <option key={t.id} value={t.id}>
              {t.request.method} {t.request.name} ({t.response?.status})
            </option>
          ))}
        </select>

        <button
          onClick={() => setShowDiff(true)}
          disabled={!leftTabId || !rightTabId}
          className="px-3 py-1 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white text-xs rounded"
        >
          Compare
        </button>
      </div>

      {/* Diff display */}
      {diff && showDiff ? (
        <div className="flex flex-1 overflow-hidden divide-x divide-gray-700">
          <DiffPanel
            lines={diff.left}
            label={`${leftTab?.request.method} ${leftTab?.request.name} — ${leftTab?.response?.status}`}
          />
          <DiffPanel
            lines={diff.right}
            label={`${rightTab?.request.method} ${rightTab?.request.name} — ${rightTab?.response?.status}`}
          />
        </div>
      ) : (
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center text-gray-600">
            <p className="text-sm">Select two responses to compare</p>
            <p className="text-xs mt-1">Supports JSON formatting and line-by-line diff</p>
          </div>
        </div>
      )}
    </div>
  );
}
