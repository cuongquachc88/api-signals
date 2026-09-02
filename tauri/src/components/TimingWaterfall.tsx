import React from 'react';
import type { RequestTiming } from '../types';

interface Props {
  timing: RequestTiming;
}

export function TimingWaterfall({ timing }: Props) {
  const total = timing.totalMs || 1;

  const phases = [
    { label: 'DNS Lookup', value: timing.dnsMs, color: 'bg-purple-500' },
    { label: 'TCP Connect', value: timing.connectMs, color: 'bg-orange-500' },
    { label: 'TLS Handshake', value: timing.tlsMs, color: 'bg-yellow-500' },
    { label: 'Request Sent', value: timing.sendMs, color: 'bg-green-500' },
    { label: 'Waiting (TTFB)', value: timing.waitMs, color: 'bg-blue-500' },
    { label: 'Content Download', value: timing.receiveMs, color: 'bg-cyan-500' },
  ];

  return (
    <div className="p-4">
      <div className="mb-4">
        <span className="text-lg font-semibold text-white">{timing.totalMs.toFixed(0)}ms</span>
        <span className="text-gray-500 text-sm ml-2">total</span>
      </div>

      <div className="space-y-3">
        {phases.map((phase) => {
          const pct = Math.max((phase.value / total) * 100, phase.value > 0 ? 1 : 0);
          return (
            <div key={phase.label} className="flex items-center gap-3">
              <div className="w-36 text-xs text-gray-400 shrink-0 text-right">{phase.label}</div>
              <div className="flex-1 bg-gray-800 rounded-full h-4 overflow-hidden">
                <div
                  className={`h-full rounded-full ${phase.color}`}
                  style={{ width: `${pct}%` }}
                />
              </div>
              <div className="w-16 text-xs text-gray-300 font-mono shrink-0">
                {phase.value > 0 ? `${phase.value.toFixed(1)}ms` : '-'}
              </div>
            </div>
          );
        })}
      </div>

      <div className="mt-6 border-t border-gray-700 pt-4">
        <table className="text-xs w-full">
          <tbody className="space-y-1">
            {phases.map(p => (
              <tr key={p.label} className="text-gray-400">
                <td className="py-0.5 pr-4">{p.label}</td>
                <td className="text-right font-mono text-gray-300">{p.value.toFixed(2)} ms</td>
              </tr>
            ))}
            <tr className="border-t border-gray-700 text-white font-medium">
              <td className="pt-2">Total</td>
              <td className="text-right font-mono pt-2">{timing.totalMs.toFixed(2)} ms</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}
