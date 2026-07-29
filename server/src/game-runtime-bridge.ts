/**
 * TCP client for Godot MCPGameInspector runtime probe (JSON lines on 6510-6514).
 * Supports multi-client queue (retries on queue_full) and optional MCP_RUNTIME_TOKEN.
 */

import net from 'net';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const PORT_START = 6510;
const PORT_END = 6514;

export type RuntimeCallResult =
  | { ok: true; data: unknown; port: number; queue_depth?: number }
  | { ok: false; error: string; port?: number; code?: string; queue_depth?: number };

function discoverPorts(userDataHint?: string): number[] {
  const ports: number[] = [];
  const tryFile = (p: string) => {
    try {
      if (existsSync(p)) {
        const raw = readFileSync(p, 'utf8').trim();
        // port file is plain number; meta is JSON
        if (raw.startsWith('{')) {
          const j = JSON.parse(raw) as { port?: number };
          if (typeof j.port === 'number' && j.port >= PORT_START && j.port <= PORT_END) {
            if (!ports.includes(j.port)) ports.push(j.port);
          }
        } else {
          const n = parseInt(raw, 10);
          if (n >= PORT_START && n <= PORT_END && !ports.includes(n)) ports.push(n);
        }
      }
    } catch {
      /* ignore */
    }
  };
  if (userDataHint) {
    tryFile(join(userDataHint, 'mcp_runtime_port'));
    tryFile(join(userDataHint, 'mcp_runtime_meta.json'));
  }
  for (let p = PORT_START; p <= PORT_END; p++) {
    if (!ports.includes(p)) ports.push(p);
  }
  return ports;
}

function runtimeToken(explicit?: string): string {
  if (explicit && explicit.length > 0) return explicit;
  return process.env.MCP_RUNTIME_TOKEN ?? '';
}

export async function callGameRuntime(
  command: string,
  params: Record<string, unknown> = {},
  options: {
    timeoutMs?: number;
    userDataHint?: string;
    port?: number;
    token?: string;
    retries?: number;
  } = {},
): Promise<RuntimeCallResult> {
  const timeoutMs = options.timeoutMs ?? 8000;
  const retries = options.retries ?? 4;
  const ports = options.port ? [options.port] : discoverPorts(options.userDataHint);
  const token = runtimeToken(options.token);

  let last: RuntimeCallResult = { ok: false, error: 'no open runtime port' };

  for (let attempt = 0; attempt < retries; attempt++) {
    for (const port of ports) {
      const result = await tryPort(port, command, params, timeoutMs, token);
      if (result.ok) return result;
      last = result;
      // Retry queue pressure
      if (result.code === 'queue_full') {
        await sleep(40 * (attempt + 1));
        break; // next attempt
      }
      // Auth won't recover by retrying other ports
      if (result.code === 'auth_required' || /unauthorized/i.test(result.error)) {
        return result;
      }
      // Only continue scan on connection failures
      if (!/ECONNREFUSED|timeout connect|not connected|connection closed/i.test(result.error)) {
        // business error from game — return
        if (result.port !== undefined && !/timeout/i.test(result.error)) {
          return result;
        }
      }
    }
  }
  return last;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function tryPort(
  port: number,
  command: string,
  params: Record<string, unknown>,
  timeoutMs: number,
  token: string,
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
      const payload: Record<string, unknown> = { id, command, params };
      if (token) payload.token = token;
      socket.write(JSON.stringify(payload) + '\n');
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
          code?: string;
          queue_depth?: number;
        };
        if (parsed.ok === false) {
          finish({
            ok: false,
            error: String(parsed.error ?? 'runtime error'),
            port,
            code: parsed.code,
            queue_depth: parsed.queue_depth,
          });
        } else {
          finish({
            ok: true,
            data: parsed.data ?? parsed,
            port,
            queue_depth: parsed.queue_depth,
          });
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
  options: { timeoutMs?: number; userDataHint?: string; token?: string } = {},
): Promise<RuntimeCallResult> {
  return callGameRuntime('ping_runtime', {}, {
    ...options,
    timeoutMs: options.timeoutMs ?? 2000,
  });
}
