/**
 * Optional Playwright adapter for Godot HTML5/web exports.
 * Does not hard-depend on playwright — dynamic import or clear error.
 */

import { createServer, type Server } from 'http';
import { readFileSync, existsSync, statSync, readdirSync, mkdirSync } from 'fs';
import { join, extname } from 'path';

const MIME: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.css': 'text/css',
  '.ico': 'image/x-icon',
};

export type WebProbeResult = {
  ok: boolean;
  url?: string;
  screenshot_path?: string;
  video_path?: string;
  video_paths?: string[];
  console_errors?: string[];
  page_errors?: string[];
  title?: string;
  wait_ms?: number;
  error?: string;
  hint?: string;
};

let staticServer: Server | null = null;
let staticPort = 0;
let staticRoot = '';

export function stopWebServe(): void {
  if (staticServer) {
    staticServer.close();
    staticServer = null;
    staticPort = 0;
    staticRoot = '';
  }
}

export async function webServeExport(
  dir: string,
  port = 8765,
): Promise<{ ok: boolean; url?: string; port?: number; error?: string }> {
  if (!existsSync(dir) || !statSync(dir).isDirectory()) {
    return { ok: false, error: `Not a directory: ${dir}` };
  }
  stopWebServe();
  staticRoot = dir;
  return new Promise((resolve) => {
    staticServer = createServer((req, res) => {
      try {
        let urlPath = (req.url ?? '/').split('?')[0];
        if (urlPath === '/') urlPath = '/index.html';
        const filePath = join(staticRoot, decodeURIComponent(urlPath));
        if (!filePath.startsWith(staticRoot) || !existsSync(filePath) || statSync(filePath).isDirectory()) {
          res.writeHead(404);
          res.end('Not found');
          return;
        }
        const ext = extname(filePath).toLowerCase();
        res.writeHead(200, { 'Content-Type': MIME[ext] ?? 'application/octet-stream' });
        res.end(readFileSync(filePath));
      } catch (e) {
        res.writeHead(500);
        res.end(String(e));
      }
    });
    staticServer.listen(port, '127.0.0.1', () => {
      staticPort = port;
      resolve({ ok: true, url: `http://127.0.0.1:${port}/`, port });
    });
    staticServer.on('error', (err) => {
      resolve({ ok: false, error: err.message });
    });
  });
}

async function loadPlaywright(): Promise<{
  chromium: {
    launch: (opts?: object) => Promise<{
      newContext: (opts?: object) => Promise<ContextLike>;
      newPage: (opts?: object) => Promise<PageLike>;
      close: () => Promise<void>;
    }>;
  };
} | null> {
  const tryImport = async (name: string) => {
    try {
      const dyn = new Function('m', 'return import(m)') as (m: string) => Promise<unknown>;
      return (await dyn(name)) as {
        chromium: {
          launch: (opts?: object) => Promise<{
            newContext: (opts?: object) => Promise<ContextLike>;
            newPage: (opts?: object) => Promise<PageLike>;
            close: () => Promise<void>;
          }>;
        };
      };
    } catch {
      return null;
    }
  };
  return (await tryImport('playwright')) ?? (await tryImport('playwright-core'));
}

type VideoLike = {
  path: () => Promise<string>;
};

type PageLike = {
  goto: (url: string, opts?: object) => Promise<unknown>;
  title: () => Promise<string>;
  screenshot: (opts?: object) => Promise<Buffer>;
  on: (ev: string, fn: (...args: unknown[]) => void) => void;
  video: () => VideoLike | null;
  close: () => Promise<void>;
};

type ContextLike = {
  newPage: () => Promise<PageLike>;
  close: () => Promise<void>;
};

function newestMediaInDir(dir: string): string[] {
  if (!existsSync(dir)) return [];
  const files = readdirSync(dir)
    .filter((f) => /\.(webm|mp4)$/i.test(f))
    .map((f) => {
      const p = join(dir, f);
      return { p, mtime: statSync(p).mtimeMs };
    })
    .sort((a, b) => b.mtime - a.mtime)
    .map((x) => x.p);
  return files;
}

export async function webPlaywrightProbe(args: {
  url?: string;
  export_dir?: string;
  serve_port?: number;
  wait_ms?: number;
  screenshot_path?: string;
  record_video_dir?: string;
}): Promise<WebProbeResult> {
  const pw = await loadPlaywright();
  if (!pw) {
    return {
      ok: false,
      error: 'Playwright not installed',
      hint: 'cd server && npm i -D playwright && npx playwright install chromium',
    };
  }

  let url = args.url ?? '';
  if (!url && args.export_dir) {
    const served = await webServeExport(args.export_dir, args.serve_port ?? 8765);
    if (!served.ok || !served.url) {
      return { ok: false, error: served.error ?? 'serve failed' };
    }
    url = served.url;
  }
  if (!url) {
    return { ok: false, error: 'url or export_dir required' };
  }

  const waitMs = args.wait_ms ?? 3000;
  const console_errors: string[] = [];
  const page_errors: string[] = [];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let browser: any = null;

  try {
    browser = await pw.chromium.launch({ headless: true });

    const wantVideo = Boolean(args.record_video_dir);
    if (wantVideo && args.record_video_dir) {
      mkdirSync(args.record_video_dir, { recursive: true });
    }

    const context: ContextLike = await browser.newContext(
      wantVideo
        ? {
            recordVideo: {
              dir: args.record_video_dir,
              size: { width: 1280, height: 720 },
            },
          }
        : {},
    );
    const page = await context.newPage();

    page.on('console', (...a: unknown[]) => {
      const msg = a[0] as { type?: () => string; text?: () => string };
      if (msg?.type?.() === 'error') console_errors.push(msg.text?.() ?? '');
    });
    page.on('pageerror', (...a: unknown[]) => {
      const err = a[0];
      page_errors.push(err instanceof Error ? err.message : String(err));
    });

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await new Promise((r) => setTimeout(r, waitMs));

    const title = await page.title();
    let screenshot_path = args.screenshot_path;
    if (screenshot_path) {
      await page.screenshot({ path: screenshot_path, fullPage: false });
    }

    // Video path is only finalized after page.close(); then context.close().
    let video_path: string | undefined;
    const video = page.video?.() ?? null;
    await page.close();
    if (video) {
      try {
        video_path = await video.path();
      } catch {
        video_path = undefined;
      }
    }
    await context.close();
    await browser.close();
    browser = null;

    // Fallback: newest file in record dir
    let video_paths: string[] | undefined;
    if (args.record_video_dir) {
      video_paths = newestMediaInDir(args.record_video_dir);
      if (!video_path && video_paths.length > 0) {
        video_path = video_paths[0];
      }
    }

    return {
      ok: true,
      url,
      title,
      screenshot_path,
      video_path,
      video_paths,
      console_errors,
      page_errors,
      wait_ms: waitMs,
      hint: 'Web export only. For native Godot use run_session_* / runtime TCP.',
    };
  } catch (e) {
    if (browser) {
      try {
        await browser.close();
      } catch {
        /* ignore */
      }
    }
    return {
      ok: false,
      error: e instanceof Error ? e.message : String(e),
      console_errors,
      page_errors,
      url,
    };
  }
}
