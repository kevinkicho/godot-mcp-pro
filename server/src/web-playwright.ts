/**
 * Optional Playwright adapter for Godot HTML5/web exports.
 * Does not hard-depend on playwright — dynamic import or clear error.
 */

import { createServer, type Server } from 'http';
import { readFileSync, existsSync, statSync } from 'fs';
import { join, extname } from 'path';
import { pathToFileURL } from 'url';

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
  console_errors?: string[];
  title?: string;
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
  chromium: { launch: (opts?: object) => Promise<BrowserLike> };
} | null> {
  // Optional peer dependency — avoid static module resolution in tsc
  const tryImport = async (name: string) => {
    try {
      // eslint-disable-next-line @typescript-eslint/no-implied-eval
      const dyn = new Function('m', 'return import(m)') as (m: string) => Promise<unknown>;
      return (await dyn(name)) as {
        chromium: { launch: (opts?: object) => Promise<BrowserLike> };
      };
    } catch {
      return null;
    }
  };
  return (await tryImport('playwright')) ?? (await tryImport('playwright-core'));
}

type BrowserLike = {
  newPage: (opts?: object) => Promise<PageLike>;
  close: () => Promise<void>;
};

type PageLike = {
  goto: (url: string, opts?: object) => Promise<unknown>;
  title: () => Promise<string>;
  screenshot: (opts?: object) => Promise<Buffer>;
  on: (ev: string, fn: (msg: { type: () => string; text: () => string }) => void) => void;
  video: () => { path: () => Promise<string> } | null;
  close: () => Promise<void>;
};

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
  let browser: BrowserLike | null = null;

  try {
    browser = await pw.chromium.launch({ headless: true });
    const contextOpts: Record<string, unknown> = {};
    if (args.record_video_dir) {
      contextOpts.recordVideo = { dir: args.record_video_dir, size: { width: 1280, height: 720 } };
    }
    // chromium.launch returns Browser; newContext for video
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const browserAny = browser as any;
    const context = contextOpts.recordVideo
      ? await browserAny.newContext(contextOpts)
      : null;
    const page: PageLike = context
      ? await context.newPage()
      : await browser.newPage();

    page.on('console', (msg) => {
      if (msg.type() === 'error') console_errors.push(msg.text());
    });
    // pageerror is available on Playwright Page; type loosely
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (page as any).on('pageerror', (err: Error | string) => {
      console_errors.push(typeof err === 'string' ? err : err?.message ?? String(err));
    });

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await new Promise((r) => setTimeout(r, waitMs));

    const title = await page.title();
    let screenshot_path = args.screenshot_path;
    if (screenshot_path) {
      await page.screenshot({ path: screenshot_path, fullPage: false });
    }

    let video_path: string | undefined;
    if (context) {
      await page.close();
      await context.close();
      // video path assigned after close — best effort from record dir
      video_path = args.record_video_dir;
    } else {
      await page.close();
    }
    await browser.close();
    browser = null;

    return {
      ok: true,
      url,
      title,
      screenshot_path,
      video_path,
      console_errors,
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
      url,
    };
  }
}

// silence unused import in some bundlers
void pathToFileURL;
