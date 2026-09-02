import React, { useState, useRef, useEffect } from 'react';
import { clsx } from 'clsx';

interface SseEvent {
  id: string;
  event: string;
  data: string;
  timestamp: Date;
}

export function SSEPanel() {
  const [url, setUrl] = useState('http://localhost:8080/sse');
  const [connected, setConnected] = useState(false);
  const [events, setEvents] = useState<SseEvent[]>([]);
  const [filter, setFilter] = useState('');
  const esRef = useRef<EventSource | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [events]);

  useEffect(() => {
    return () => { esRef.current?.close(); };
  }, []);

  const addEvent = (event: string, data: string) => {
    setEvents(prev => [...prev, {
      id: crypto.randomUUID(),
      event, data,
      timestamp: new Date(),
    }]);
  };

  const handleConnect = () => {
    if (connected) {
      esRef.current?.close();
      setConnected(false);
      addEvent('system', 'Disconnected');
      return;
    }

    try {
      const es = new EventSource(url);
      esRef.current = es;

      es.onopen = () => {
        setConnected(true);
        addEvent('system', `Connected to ${url}`);
      };

      es.onmessage = (e) => {
        addEvent('message', e.data);
      };

      es.onerror = () => {
        setConnected(false);
        addEvent('error', 'Connection error or closed');
      };

      // Listen for named events
      ['update', 'ping', 'heartbeat', 'data', 'event'].forEach(eventName => {
        es.addEventListener(eventName, (e: MessageEvent) => {
          addEvent(eventName, e.data);
        });
      });
    } catch (err) {
      addEvent('error', `Failed to connect: ${err}`);
    }
  };

  const handleClear = () => setEvents([]);

  const filteredEvents = filter
    ? events.filter(e =>
        e.event.toLowerCase().includes(filter.toLowerCase()) ||
        e.data.toLowerCase().includes(filter.toLowerCase())
      )
    : events;

  return (
    <div className="flex flex-col h-full">
      {/* Controls */}
      <div className="flex items-center gap-2 px-3 py-2 border-b border-gray-700 shrink-0">
        <div className={clsx('w-2 h-2 rounded-full shrink-0', connected ? 'bg-green-500 animate-pulse' : 'bg-gray-600')} />
        <input
          className="flex-1 bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none focus:border-blue-500 font-mono"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="http://localhost:8080/events"
          disabled={connected}
        />
        <button
          onClick={handleConnect}
          className={clsx(
            'px-4 py-1.5 rounded text-sm font-medium',
            connected
              ? 'bg-red-700 hover:bg-red-600 text-white'
              : 'bg-green-700 hover:bg-green-600 text-white'
          )}
        >
          {connected ? 'Disconnect' : 'Connect'}
        </button>
        <button
          onClick={handleClear}
          className="px-3 py-1.5 text-sm text-gray-500 hover:text-white border border-gray-700 rounded"
        >
          Clear
        </button>
      </div>

      {/* Filter */}
      <div className="px-3 py-1.5 border-b border-gray-800 shrink-0">
        <input
          className="w-full bg-gray-800 text-gray-200 rounded px-3 py-1 text-xs border border-gray-700 outline-none placeholder-gray-600"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          placeholder="Filter events..."
        />
      </div>

      {/* Events */}
      <div className="flex-1 overflow-y-auto p-2 font-mono text-xs">
        {filteredEvents.length === 0 ? (
          <div className="flex items-center justify-center h-full text-gray-600">
            {connected ? 'Waiting for events...' : 'Connect to an SSE endpoint to receive events'}
          </div>
        ) : (
          filteredEvents.map((evt) => (
            <div
              key={evt.id}
              className={clsx('mb-2 rounded overflow-hidden border', {
                'border-blue-700/30 bg-blue-900/10': evt.event === 'message',
                'border-gray-700/30 bg-gray-800/30': evt.event === 'system',
                'border-red-700/30 bg-red-900/10': evt.event === 'error',
                'border-purple-700/30 bg-purple-900/10': !['message', 'system', 'error'].includes(evt.event),
              })}
            >
              <div className="flex items-center gap-2 px-2 py-0.5 border-b border-current/10">
                <span className={clsx('text-[10px] font-bold uppercase', {
                  'text-blue-400': evt.event === 'message',
                  'text-gray-500': evt.event === 'system',
                  'text-red-400': evt.event === 'error',
                  'text-purple-400': !['message', 'system', 'error'].includes(evt.event),
                })}>
                  {evt.event}
                </span>
                <span className="text-[10px] text-gray-600 ml-auto">
                  {evt.timestamp.toLocaleTimeString()}
                </span>
              </div>
              <pre className="px-2 py-1 text-[11px] whitespace-pre-wrap break-all text-gray-300">
                {evt.data}
              </pre>
            </div>
          ))
        )}
        <div ref={endRef} />
      </div>

      {/* Stats */}
      <div className="flex items-center gap-4 px-3 py-1.5 border-t border-gray-700 shrink-0 text-[10px] text-gray-600">
        <span>{events.length} events total</span>
        {filter && <span>{filteredEvents.length} shown</span>}
      </div>
    </div>
  );
}
