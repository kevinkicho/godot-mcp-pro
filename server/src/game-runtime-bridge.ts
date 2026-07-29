/**
 * TCP client for Godot MCPGameInspector runtime probe (JSON lines on 6510-6514).
 * Allows the open MCP server to talk to a running game without editor Play.
 */

import net from 'net';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const PORT_START = 6510;
const PORT_END = 6514;

export type RuntimeCallResult =
  | { ok: true; data: unknown; port: number }
  | { ok: false; error: string; port?: number };

function discoverPorts(userDataHint?: string): number[] {
  const ports: number[] = [];
  const tryFile = (p: string) => {
    try {
      if (existsSync(p)) {
        const n = parseInt(readFileSync(p, 'utf8').trim(), 10);
        if (n >= PORT_START && n <= PORT_END && !ports.includes(n)) ports.push(n);
      }
    } catch {
      /* ignore */
    }
  };
  if (userDataHint) {
    tryFile(join(userDataHint, 'mcp_runtime_port'));
  }
  // Common Windows Godot user data layout is unknown; always scan range
  for (let p = PORT_START; p <= PORT_END; p++) {
    if (!ports.includes(p)) ports.push(p);
  }
  return ports;
}

export async function callGameRuntime(
  command: string,
  params: Record<string, unknown> = {},
  options: { timeoutMs?: number; userDataHint?: string; port?: number } = {},
): Promise<RuntimeCallResult> {
  const timeoutMs = options.timeoutMs ?? 8000;
  const ports = options.port
    ? [options.port]
    : discoverPorts(options.userDataHint);

  let lastErr = 'no open runtime port';
  for (const port of ports) {
    const result = await tryPort(port, command, params, timeoutMs);
    if (result.ok) return result;
    lastErr = result.error;
    // Only continue scan on connection failures
    if (!/ECONNREFUSED|timeout connect|not connected/i.test(result.error)) {
      return result;
    }
  }
  return { ok: false, error: lastErr };
}

function tryPort(
  port: number,
  command: string,
  params: Record<string, unknown>,
  timeoutMs: number,
): Promise<RuntimeCallResult> {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let buf = '';
    let settled = false;
    const id = Date.now() % 1_000_000;

    const finish = (r: RuntimeCallResult) => {
      if (settled) return;
      settled = true;
      try {
        socket.destroy();
      } catch {
        /* ignore */
      }
      resolve(r);
    };

    const timer = setTimeout(() => {
      finish({ ok: false, error: `timeout connect/read on ${port}`, port });
    }, timeoutMs);

    socket.setEncoding('utf8');
    socket.connect(port, '127.0.0.1', () => {
      const line = JSON.stringify({ id, command, params }) + '\n';
      socket.write(line);
    });

    socket.on('data', (chunk: string) => {
      buf += chunk;
      const nl = buf.indexOf('\n');
      if (nl < 0) return;
      clearTimeout(timer);
      const line = buf.slice(0, nl).trim();
      try {
        const parsed = JSON.parse(line) as {
          ok?: boolean;
          data?: unknown;
          error?: string;
        };
        if (parsed.ok === false) {
          finish({ ok: false, error: String(parsed.error ?? 'runtime error'), port });
        } else {
          finish({ ok: true, data: parsed.data ?? parsed, port });
        }
      } catch (e) {
        finish({
          ok: false,
          error: `invalid JSON: ${e instanceof Error ? e.message : String(e)}`,
          port,
        });
      }
    });

    socket.on('error', (err) => {
      clearTimeout(timer);
      finish({ ok: false, error: err.message, port });
    });

    socket.on('close', () => {
      if (!settled) {
        clearTimeout(timer);
        finish({ ok: false, error: 'connection closed', port });
      }
    });
  });
}

export async function pingGameRuntime(
  options: { timeoutMs?: number; userDataHint?: string } = {},
): Promise<RuntimeCallResult> {
  return callGameRuntime('ping_runtime', {}, { ...options, timeoutMs: options.timeoutMs ?? 2000 });
}
