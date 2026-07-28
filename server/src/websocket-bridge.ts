import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';

export type JsonRpcResult = {
  ok: true;
  result: unknown;
} | {
  ok: false;
  error: { code?: number; message: string; data?: unknown };
};

/**
 * WebSocket server that the Godot MCP Pro plugin connects to as a client.
 * Protocol: JSON-RPC 2.0 text frames (see addons/godot_mcp/websocket_server.gd).
 */
export class GodotWebSocketBridge extends EventEmitter {
  private wss: WebSocketServer | null = null;
  private clients = new Set<WebSocket>();
  private nextId = 1;
  private pending = new Map<number | string, {
    resolve: (value: JsonRpcResult) => void;
    reject: (err: Error) => void;
    timer: NodeJS.Timeout;
    ws: WebSocket;
  }>();
  private port: number;
  private actualPort: number | null = null;
  private debug: boolean;
  /** Prefer this port, then scan 6505-6509 (plugin connects to all of them). */
  private preferPort: number;

  constructor(port: number, debug = false) {
    super();
    this.port = port;
    this.preferPort = port;
    this.debug = debug;
  }

  getPort(): number {
    return this.actualPort ?? this.port;
  }

  /**
   * Bind WebSocket. If preferred port is busy, try 6505-6509 so multiple
   * Grok sessions can each run an MCP server (plugin multi-connects).
   */
  async start(): Promise<void> {
    const preferred = this.preferPort;
    const candidates: number[] = [preferred];
    for (let p = 6505; p <= 6509; p++) {
      if (p !== preferred) candidates.push(p);
    }

    let lastError: Error | null = null;
    for (const port of candidates) {
      try {
        await this.listenOn(port);
        this.port = port;
        this.actualPort = port;
        this.log(`WebSocket listening on ws://127.0.0.1:${port}`);
        return;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
        this.log(`Port ${port} unavailable: ${lastError.message}`);
        this.wss = null;
      }
    }
    throw lastError ?? new Error('No free Godot MCP port in 6505-6509');
  }

  private listenOn(port: number): Promise<void> {
    return new Promise((resolve, reject) => {
      let settled = false;
      try {
        this.wss = new WebSocketServer({
          host: '127.0.0.1',
          port,
          maxPayload: 16 * 1024 * 1024,
        });
      } catch (err) {
        reject(err);
        return;
      }

      const fail = (err: Error) => {
        if (settled) return;
        settled = true;
        try {
          this.wss?.close();
        } catch {
          /* ignore */
        }
        this.wss = null;
        reject(err);
      };

      this.wss.on('listening', () => {
        if (settled) return;
        settled = true;
        resolve();
      });

      this.wss.on('error', (err) => {
        // EADDRINUSE during bind
        if (!settled) {
          fail(err);
          return;
        }
        this.log(`WebSocket server error: ${err.message}`);
        this.emit('error', err);
      });

      this.wss.on('connection', (ws) => {
        this.clients.add(ws);
        this.log(`Godot plugin connected (${this.clients.size} client(s))`);
        this.emit('connection');

        ws.on('message', (data) => {
          this.handleMessage(String(data), ws);
        });

        const onClose = () => {
          this.clients.delete(ws);
          this.log(`Godot plugin disconnected (${this.clients.size} client(s))`);
          this.emit('disconnect');
          clearInterval(pingTimer);
        };
        ws.on('close', onClose);

        ws.on('error', (err) => {
          this.log(`Client error: ${err.message}`);
        });

        // Heartbeat ping (plugin replies with pong and resets inactivity timer)
        const pingTimer = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ jsonrpc: '2.0', method: 'ping', params: {} }));
          }
        }, 10_000);
      });
    });
  }

  stop(): void {
    for (const [, p] of this.pending) {
      clearTimeout(p.timer);
      p.reject(new Error('Bridge shutting down'));
    }
    this.pending.clear();
    for (const ws of this.clients) {
      ws.close(1000, 'Server shutting down');
    }
    this.clients.clear();
    this.wss?.close();
    this.wss = null;
  }

  isConnected(): boolean {
    for (const ws of this.clients) {
      if (ws.readyState === WebSocket.OPEN) return true;
    }
    return false;
  }

  getClientCount(): number {
    let n = 0;
    for (const ws of this.clients) {
      if (ws.readyState === WebSocket.OPEN) n++;
    }
    return n;
  }

  /**
   * Call a plugin command by method name.
   */
  call(method: string, params: Record<string, unknown> = {}, timeoutMs = 60_000): Promise<JsonRpcResult> {
    if (!this.isConnected()) {
      return Promise.resolve({
        ok: false,
        error: {
          code: -32000,
          message: 'Godot editor is not connected',
          data: {
            suggestion: 'Open your project in Godot with the Godot MCP Pro plugin enabled.',
          },
        },
      });
    }

    const id = this.nextId++;
    const payload = JSON.stringify({
      jsonrpc: '2.0',
      id,
      method,
      params,
    });

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        resolve({
          ok: false,
          error: { code: -32000, message: `Timeout waiting for ${method} (${timeoutMs}ms)` },
        });
      }, timeoutMs);

      const ws = this.firstOpenClient();
      if (!ws) {
        clearTimeout(timer);
        this.pending.delete(id);
        resolve({
          ok: false,
          error: { code: -32000, message: 'Godot editor is not connected' },
        });
        return;
      }
      this.pending.set(id, { resolve, reject, timer, ws });
      ws.send(payload);
    });
  }

  private firstOpenClient(): WebSocket | null {
    for (const ws of this.clients) {
      if (ws.readyState === WebSocket.OPEN) return ws;
    }
    return null;
  }

  private handleMessage(text: string, from: WebSocket): void {
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(text);
    } catch {
      this.log(`Invalid JSON from Godot: ${text.slice(0, 200)}`);
      return;
    }

    // Plugin-initiated ping → reply pong on the *same* socket
    if (msg.method === 'ping') {
      if (from.readyState === WebSocket.OPEN) {
        from.send(JSON.stringify({ jsonrpc: '2.0', method: 'pong', params: {} }));
      }
      return;
    }
    if (msg.method === 'pong') {
      return;
    }

    if (msg.id === undefined || msg.id === null) {
      return;
    }

    const pending = this.pending.get(msg.id as number | string);
    if (!pending) {
      return;
    }

    clearTimeout(pending.timer);
    this.pending.delete(msg.id as number | string);

    if (msg.error) {
      const err = msg.error as { code?: number; message?: string; data?: unknown };
      pending.resolve({
        ok: false,
        error: {
          code: err.code,
          message: err.message ?? 'Unknown error',
          data: err.data,
        },
      });
    } else {
      pending.resolve({ ok: true, result: msg.result ?? {} });
    }
  }

  private log(message: string): void {
    if (this.debug) {
      console.error(`[WS] ${message}`);
    }
  }
}
