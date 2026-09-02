import React, { useState, useRef, useEffect } from 'react';
import { clsx } from 'clsx';

interface WsMessage {
  id: string;
  type: 'sent' | 'received' | 'info' | 'error';
  content: string;
  timestamp: Date;
}

export function WebSocketPanel() {
  const [url, setUrl] = useState('ws://localhost:8080');
  const [connected, setConnected] = useState(false);
  const [messages, setMessages] = useState<WsMessage[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const wsRef = useRef<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  useEffect(() => {
    return () => {
      wsRef.current?.close();
    };
  }, []);

  const addMessage = (type: WsMessage['type'], content: string) => {
    setMessages(prev => [...prev, {
      id: crypto.randomUUID(),
      type, content,
      timestamp: new Date(),
    }]);
  };

  const handleConnect = () => {
    if (connected) {
      wsRef.current?.close();
      return;
    }

    try {
      const ws = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        setConnected(true);
        addMessage('info', `Connected to ${url}`);
      };

      ws.onmessage = (e) => {
        addMessage('received', e.data);
      };

      ws.onerror = (e) => {
        addMessage('error', 'WebSocket error');
      };

      ws.onclose = (e) => {
        setConnected(false);
        addMessage('info', `Disconnected (code: ${e.code}${e.reason ? `, reason: ${e.reason}` : ''})`);
      };
    } catch (err) {
      addMessage('error', `Failed to connect: ${err}`);
    }
  };

  const handleSend = () => {
    if (!connected || !inputMessage.trim()) return;
    wsRef.current?.send(inputMessage);
    addMessage('sent', inputMessage);
    setInputMessage('');
  };

  const handleClear = () => setMessages([]);

  return (
    <div className="flex flex-col h-full">
      {/* URL Bar */}
      <div className="flex items-center gap-2 px-3 py-2 border-b border-gray-700 shrink-0">
        <div className={clsx('w-2 h-2 rounded-full shrink-0', connected ? 'bg-green-500' : 'bg-gray-600')} />
        <input
          className="flex-1 bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none focus:border-blue-500 font-mono"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="ws://localhost:8080"
          disabled={connected}
        />
        <button
          onClick={handleConnect}
          className={clsx(
            'px-4 py-1.5 rounded text-sm font-medium transition-colors',
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

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-2 font-mono text-xs">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full text-gray-600">
            Connect to a WebSocket server to start
          </div>
        ) : (
          messages.map((msg) => (
            <div
              key={msg.id}
              className={clsx('flex gap-2 mb-1.5 items-start', {
                'justify-end': msg.type === 'sent',
              })}
            >
              {msg.type !== 'sent' && (
                <span className="text-[10px] text-gray-600 shrink-0 mt-0.5">
                  {msg.timestamp.toLocaleTimeString()}
                </span>
              )}
              <div className={clsx('rounded px-2 py-1 max-w-[80%] break-all', {
                'bg-blue-700/30 text-blue-200': msg.type === 'sent',
                'bg-gray-800 text-gray-200': msg.type === 'received',
                'bg-gray-800/50 text-gray-500 italic': msg.type === 'info',
                'bg-red-900/30 text-red-300': msg.type === 'error',
              })}>
                <div className="flex items-center gap-1 mb-0.5">
                  <span className={clsx('text-[9px] font-bold uppercase', {
                    'text-blue-400': msg.type === 'sent',
                    'text-gray-400': msg.type === 'received',
                    'text-gray-500': msg.type === 'info',
                    'text-red-400': msg.type === 'error',
                  })}>
                    {msg.type}
                  </span>
                </div>
                <pre className="whitespace-pre-wrap text-[11px]">{msg.content}</pre>
              </div>
              {msg.type === 'sent' && (
                <span className="text-[10px] text-gray-600 shrink-0 mt-0.5">
                  {msg.timestamp.toLocaleTimeString()}
                </span>
              )}
            </div>
          ))
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Send input */}
      <div className="flex items-center gap-2 px-3 py-2 border-t border-gray-700 shrink-0">
        <input
          className="flex-1 bg-gray-800 text-gray-200 rounded px-3 py-1.5 text-sm border border-gray-700 outline-none focus:border-blue-500 font-mono"
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          placeholder={connected ? 'Type a message...' : 'Connect first...'}
          disabled={!connected}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              handleSend();
            }
          }}
        />
        <button
          onClick={handleSend}
          disabled={!connected || !inputMessage.trim()}
          className="px-4 py-1.5 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white text-sm rounded"
        >
          Send
        </button>
      </div>
    </div>
  );
}
