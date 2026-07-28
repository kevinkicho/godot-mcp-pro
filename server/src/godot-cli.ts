import { spawn, execFile, ChildProcess } from 'child_process';
import { promisify } from 'util';
import { existsSync, readdirSync, statSync } from 'fs';
import { join, normalize, dirname } from 'path';
import { fileURLToPath } from 'url';

const execFileAsync = promisify(execFile);

export interface GodotProcess {
  process: ChildProcess;
  output: string[];
  errors: string[];
}

export class GodotCli {
  godotPath: string | null = null;
  activeProcess: GodotProcess | null = null;
  private operationsScriptPath: string;
  private debug: boolean;
  private validated = new Map<string, boolean>();

  constructor(options: { godotPath?: string; debug?: boolean; operationsScriptPath?: string } = {}) {
    this.debug = options.debug ?? process.env.DEBUG === 'true';
    if (options.godotPath) {
      this.godotPath = normalize(options.godotPath);
    } else if (process.env.GODOT_PATH) {
      this.godotPath = normalize(process.env.GODOT_PATH);
    }
    const __dirname = dirname(fileURLToPath(import.meta.url));
    this.operationsScriptPath =
      options.operationsScriptPath ?? join(__dirname, 'scripts', 'godot_operations.gd');
  }

  private log(msg: string): void {
    if (this.debug) console.error(`[CLI] ${msg}`);
  }

  async ensureGodot(): Promise<string | null> {
    if (this.godotPath && (await this.isValid(this.godotPath))) {
      return this.godotPath;
    }
    await this.detect();
    return this.godotPath;
  }

  private async isValid(path: string): Promise<boolean> {
    if (this.validated.has(path)) return this.validated.get(path)!;
    try {
      if (path !== 'godot' && !existsSync(path)) {
        this.validated.set(path, false);
        return false;
      }
      await execFileAsync(path, ['--version'], { timeout: 15_000 });
      this.validated.set(path, true);
      return true;
    } catch {
      this.validated.set(path, false);
      return false;
    }
  }

  private async detect(): Promise<void> {
    if (this.godotPath && (await this.isValid(this.godotPath))) return;

    if (process.env.GODOT_PATH) {
      const p = normalize(process.env.GODOT_PATH);
      if (await this.isValid(p)) {
        this.godotPath = p;
        return;
      }
    }

    const candidates: string[] = ['godot'];
    if (process.platform === 'win32') {
      candidates.push(
        'C:\\Program Files\\Godot\\Godot.exe',
        'C:\\Program Files (x86)\\Godot\\Godot.exe',
        join(process.env.USERPROFILE ?? '', 'Godot', 'Godot.exe'),
        'C:\\Program Files\\Godot_v4.7.1-stable_mono_win64\\Godot_v4.7.1-stable_mono_win64.exe',
      );
    } else if (process.platform === 'darwin') {
      candidates.push(
        '/Applications/Godot.app/Contents/MacOS/Godot',
        '/Applications/Godot_4.app/Contents/MacOS/Godot',
      );
    } else {
      candidates.push('/usr/bin/godot', '/usr/local/bin/godot', '/snap/bin/godot');
    }

    for (const c of candidates) {
      const p = normalize(c);
      if (await this.isValid(p)) {
        this.godotPath = p;
        this.log(`Found Godot at ${p}`);
        return;
      }
    }
  }

  async getVersion(): Promise<string> {
    const godot = await this.ensureGodot();
    if (!godot) throw new Error('Godot executable not found. Set GODOT_PATH.');
    const { stdout } = await execFileAsync(godot, ['--version']);
    return stdout.trim();
  }

  async launchEditor(projectPath: string): Promise<void> {
    const godot = await this.ensureGodot();
    if (!godot) throw new Error('Godot executable not found. Set GODOT_PATH.');
    const projectFile = join(projectPath, 'project.godot');
    if (!existsSync(projectFile)) {
      throw new Error(`Not a valid Godot project: ${projectPath}`);
    }
    const child = spawn(godot, ['-e', '--path', projectPath], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
  }

  findProjects(directory: string, recursive: boolean): Array<{ path: string; name: string }> {
    const results: Array<{ path: string; name: string }> = [];
    this.walkProjects(directory, recursive, results, 0, 8);
    return results;
  }

  private walkProjects(
    directory: string,
    recursive: boolean,
    out: Array<{ path: string; name: string }>,
    depth: number,
    maxDepth: number,
  ): void {
    if (!existsSync(directory)) return;
    const projectFile = join(directory, 'project.godot');
    if (existsSync(projectFile)) {
      out.push({ path: directory, name: directory.split(/[/\\]/).pop() || directory });
      return;
    }
    if (depth >= maxDepth) return;
    if (!recursive && depth > 0) return;

    let entries: string[];
    try {
      entries = readdirSync(directory);
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry.startsWith('.')) continue;
      const full = join(directory, entry);
      try {
        if (statSync(full).isDirectory()) {
          if (recursive || depth === 0) {
            this.walkProjects(full, recursive, out, depth + 1, maxDepth);
          }
        }
      } catch {
        // skip unreadable
      }
    }
  }

  async runProject(projectPath: string, scene?: string): Promise<void> {
    const godot = await this.ensureGodot();
    if (!godot) throw new Error('Godot executable not found. Set GODOT_PATH.');
    if (!existsSync(join(projectPath, 'project.godot'))) {
      throw new Error(`Not a valid Godot project: ${projectPath}`);
    }
    if (this.activeProcess) {
      this.activeProcess.process.kill();
      this.activeProcess = null;
    }
    const args = ['-d', '--path', projectPath];
    if (scene) args.push(scene);

    const child = spawn(godot, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    const record: GodotProcess = { process: child, output: [], errors: [] };
    this.activeProcess = record;

    child.stdout?.on('data', (buf: Buffer) => {
      record.output.push(buf.toString());
    });
    child.stderr?.on('data', (buf: Buffer) => {
      record.errors.push(buf.toString());
    });
    child.on('exit', () => {
      if (this.activeProcess?.process === child) {
        // keep buffers for get_debug_output
      }
    });
  }

  getDebugOutput(): { output: string[]; errors: string[]; running: boolean } {
    if (!this.activeProcess) {
      return { output: [], errors: [], running: false };
    }
    const running = this.activeProcess.process.exitCode === null && !this.activeProcess.process.killed;
    return {
      output: [...this.activeProcess.output],
      errors: [...this.activeProcess.errors],
      running,
    };
  }

  stopProject(): boolean {
    if (!this.activeProcess) return false;
    this.activeProcess.process.kill();
    this.activeProcess = null;
    return true;
  }

  /**
   * Run a headless godot_operations.gd operation (Coding-Solo style).
   */
  async runOperation(
    projectPath: string,
    operation: string,
    params: Record<string, unknown>,
  ): Promise<string> {
    const godot = await this.ensureGodot();
    if (!godot) throw new Error('Godot executable not found. Set GODOT_PATH.');
    if (!existsSync(this.operationsScriptPath)) {
      throw new Error(`Operations script missing: ${this.operationsScriptPath}`);
    }
    const args = [
      '--headless',
      '--path',
      projectPath,
      '--script',
      this.operationsScriptPath,
      operation,
      JSON.stringify(params),
    ];
    const { stdout, stderr } = await execFileAsync(godot, args, {
      timeout: 120_000,
      maxBuffer: 10 * 1024 * 1024,
    });
    return (stdout || stderr || '').trim();
  }
}
