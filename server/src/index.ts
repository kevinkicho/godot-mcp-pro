#!/usr/bin/env node
/**
 * Open-source MCP server for Godot MCP Pro (fork) — agent-driven game production.
 *
 *   AI agent  --stdio/MCP-->  this process  --WebSocket:6505-6509-->  Godot editor plugin
 *                              \--CLI Godot-->  headless / launch / run
 *
 * Flags:
 *   --lite / --minimal   Expose core tools only; use call_editor for the rest
 * Env:
 *   GODOT_MCP_PORT, GODOT_PATH, DEBUG, GODOT_MCP_LITE=true
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

import { GodotWebSocketBridge } from './websocket-bridge.js';
import { GodotCli } from './godot-cli.js';
import {
  CLI_TOOLS,
  LITE_EDITOR_TOOLS,
  EDITOR_PREFERRED,
  parseLiteMode,
  type ToolDef,
} from './tools.js';

const DEBUG = process.env.DEBUG === 'true';
const PREFERRED_PORT = parseInt(process.env.GODOT_MCP_PORT || '6505', 10);
const LITE = parseLiteMode(process.argv);
const SERVER_VERSION = '1.29.0';

function log(msg: string): void {
  if (DEBUG) console.error(`[SERVER] ${msg}`);
}

function pick(args: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = args[k];
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return '';
}

function textResult(text: string, isError = false) {
  return {
    content: [{ type: 'text' as const, text }],
    isError,
  };
}

function jsonResult(data: unknown, isError = false) {
  return textResult(JSON.stringify(data, null, 2), isError);
}

class GodotMcpProServer {
  private server: Server;
  private bridge: GodotWebSocketBridge;
  private cli: GodotCli;
  private editorMethods = new Set<string>();

  constructor() {
    this.bridge = new GodotWebSocketBridge(PREFERRED_PORT, DEBUG);
    this.cli = new GodotCli({ debug: DEBUG });

    this.server = new Server(
      { name: 'godot-mcp-pro', version: SERVER_VERSION },
      { capabilities: { tools: {} } },
    );

    this.server.onerror = (err) => console.error('[MCP Error]', err);

    this.bridge.on('connection', () => {
      void this.refreshEditorMethods();
    });

    this.setupHandlers();
  }

  private async refreshEditorMethods(): Promise<void> {
    const res = await this.bridge.call('list_mcp_commands', {}, 10_000);
    if (res.ok && res.result && typeof res.result === 'object') {
      const commands = (res.result as { commands?: string[] }).commands;
      if (Array.isArray(commands)) {
        this.editorMethods = new Set(commands);
        log(`Discovered ${this.editorMethods.size} editor commands`);
      }
    }
  }

  private buildToolList(): ToolDef[] {
    const tools: ToolDef[] = [...CLI_TOOLS];
    const listed = new Set(tools.map((t) => t.name));

    // Always include lite core editor tools (schemas) when not already listed
    for (const t of LITE_EDITOR_TOOLS) {
      if (!listed.has(t.name)) {
        tools.push(t);
        listed.add(t.name);
      }
    }

    if (!LITE) {
      for (const method of this.editorMethods) {
        if (listed.has(method)) continue;
        tools.push({
          name: method,
          description: `Godot editor command: ${method} (plugin). Prefer typed tools when available; call_editor also works.`,
          inputSchema: {
            type: 'object',
            properties: {},
            required: [],
          },
        });
        listed.add(method);
      }
    }

    return tools;
  }

  private setupHandlers(): void {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: this.buildToolList(),
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const name = request.params.name;
      const args = (request.params.arguments ?? {}) as Record<string, unknown>;
      try {
        return await this.handleTool(name, args);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return textResult(message, true);
      }
    });
  }

  private offlineHint(): string {
    return (
      'Editor plugin not connected. Open a Godot 4 project with the Godot MCP Pro plugin enabled, ' +
      'keep the editor open, then call health_check. CLI tools still work without the editor.'
    );
  }

  private async handleTool(name: string, args: Record<string, unknown>) {
    switch (name) {
      case 'health_check':
        return this.handleHealthCheck();

      case 'agent_workflow_guide':
        if (this.bridge.isConnected()) {
          return this.editorCall('agent_workflow_guide', args);
        }
        return jsonResult(this.offlineWorkflowGuide(pick(args, 'topic') || 'production'));

      case 'get_connection_status':
        return jsonResult({
          server_version: SERVER_VERSION,
          lite_mode: LITE,
          websocket_port: this.bridge.getPort(),
          editor_connected: this.bridge.isConnected(),
          clients: this.bridge.getClientCount(),
          editor_commands: this.editorMethods.size,
          hint: this.bridge.isConnected() ? 'ok' : this.offlineHint(),
        });

      case 'get_debug_output':
        return jsonResult(this.cli.getDebugOutput());

      case 'stop_project': {
        const stopped = this.cli.stopProject();
        if (this.bridge.isConnected()) {
          await this.bridge.call('stop_scene', {});
        }
        return jsonResult({
          stopped,
          message: stopped ? 'Project stopped' : 'No CLI process was running',
        });
      }

      case 'call_editor': {
        const method = pick(args, 'method');
        if (!method) return textResult('method is required', true);
        const params = (args.params as Record<string, unknown>) ?? {};
        return this.editorCall(method, params);
      }

      case 'list_mcp_commands':
        if (this.bridge.isConnected()) {
          return this.editorCall('list_mcp_commands', {});
        }
        return textResult(this.offlineHint(), true);

      case 'launch_editor':
        return this.handleLaunchEditor(args);

      case 'run_project':
        return this.handleRunProject(args);

      case 'get_godot_version':
        return this.handleGetVersion();

      case 'list_projects':
        return this.handleListProjects(args);

      case 'get_project_info':
        return this.handleProjectInfo(args);

      case 'create_scene':
        return this.handleCreateScene(args);

      case 'add_node':
        return this.handleAddNode(args);

      case 'load_sprite':
        return this.handleLoadSprite(args);

      case 'export_mesh_library':
        return this.handleExportMeshLibrary(args);

      case 'save_scene':
        return this.handleSaveScene(args);

      case 'get_uid':
        return this.handleGetUid(args);

      case 'update_project_uids':
        return this.handleUpdateUids(args);

      default:
        if (this.bridge.isConnected()) {
          return this.editorCall(name, args);
        }
        if (LITE_EDITOR_TOOLS.some((t) => t.name === name) || EDITOR_PREFERRED.has(name)) {
          return textResult(`${name}: ${this.offlineHint()}`, true);
        }
        throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
    }
  }

  private async handleHealthCheck() {
    const base = {
      server_version: SERVER_VERSION,
      lite_mode: LITE,
      websocket_port: this.bridge.getPort(),
      editor_connected: this.bridge.isConnected(),
      clients: this.bridge.getClientCount(),
      discovered_commands: this.editorMethods.size,
      ready_for_agent_production: false as boolean,
      issues: [] as Array<{ severity: string; message: string; suggestion?: string }>,
      agent_hint: 'Use agent_workflow_guide for the production loop.',
    };

    let godotVersion: string | null = null;
    try {
      godotVersion = await this.cli.getVersion();
    } catch (err) {
      base.issues.push({
        severity: 'warning',
        message: `GODOT_PATH / CLI not available: ${err instanceof Error ? err.message : String(err)}`,
        suggestion: 'Set GODOT_PATH to your Godot 4 executable',
      });
    }
    if (godotVersion) {
      (base as Record<string, unknown>).godot_cli_version = godotVersion;
    }

    if (!this.bridge.isConnected()) {
      base.issues.push({
        severity: 'warning',
        message: 'Editor plugin not connected',
        suggestion: this.offlineHint(),
      });
      base.ready_for_agent_production = false;
      return jsonResult(base);
    }

    const plugin = await this.bridge.call('health_check', {}, 15_000);
    if (plugin.ok && plugin.result && typeof plugin.result === 'object') {
      const merged = {
        ...base,
        ...(plugin.result as object),
        server_version: SERVER_VERSION,
        lite_mode: LITE,
        editor_connected: true,
      };
      const pr = plugin.result as { ready_for_agent_production?: boolean; issues?: unknown[] };
      merged.ready_for_agent_production = pr.ready_for_agent_production === true;
      return jsonResult(merged);
    }

    base.issues.push({
      severity: 'error',
      message: 'Plugin connected but health_check failed',
      suggestion: plugin.ok ? undefined : String((plugin as { error?: { message?: string } }).error?.message),
    });
    return jsonResult(base, true);
  }

  private offlineWorkflowGuide(topic: string) {
    return {
      purpose: 'Agent-driven game production with Godot MCP (offline summary)',
      topic,
      principles: [
        'Agents work headless as if using the Godot IDE; MCP surfaces human dock workflows.',
        'Connect the editor plugin for production quality (UndoRedo, import, playtest, screenshots).',
        'Explore before mutate.',
        'Keep writes under res://.',
        'Loop: scaffold → import → build → wire → playtest → fix.',
      ],
      production_loop: [
        'health_check / agent_production_status',
        'scaffold_project_defaults (new projects)',
        'stage_files_into_res / ensure_imported',
        'get_project_info / get_filesystem_tree / open_scene',
        'create_scene / add_node / create_script / attach_script',
        'wire_signal_to_new_method',
        'save_scene / validate_script',
        'playtest_report (or play_scene → screenshot/errors)',
        'simulate_action → stop_scene → fix',
      ],
      note: this.offlineHint(),
    };
  }

  private async editorCall(method: string, params: Record<string, unknown>) {
    if (!this.bridge.isConnected()) {
      return textResult(`${method}: ${this.offlineHint()}`, true);
    }
    const res = await this.bridge.call(method, params);
    if (res.ok) {
      return jsonResult(res.result);
    }
    const msg = res.error.message + (res.error.data ? `\n${JSON.stringify(res.error.data)}` : '');
    return textResult(msg, true);
  }

  private async preferEditor(method: string, params: Record<string, unknown>) {
    if (this.bridge.isConnected() && EDITOR_PREFERRED.has(method)) {
      return this.editorCall(method, params);
    }
    return null;
  }

  private async handleLaunchEditor(args: Record<string, unknown>) {
    const projectPath = pick(args, 'project_path', 'projectPath', 'path');
    if (!projectPath) return textResult('project_path is required', true);
    try {
      await this.cli.launchEditor(projectPath);
      return jsonResult({ project_path: projectPath, message: 'Godot editor launched' });
    } catch (err) {
      if (this.bridge.isConnected()) {
        return this.editorCall('launch_editor', { project_path: projectPath });
      }
      return textResult(err instanceof Error ? err.message : String(err), true);
    }
  }

  private async handleRunProject(args: Record<string, unknown>) {
    const projectPath = pick(args, 'project_path', 'projectPath');
    if (!projectPath) return textResult('project_path is required', true);
    const scene = pick(args, 'scene') || undefined;

    if (this.bridge.isConnected()) {
      const info = await this.bridge.call('get_project_info', {});
      if (info.ok && info.result && typeof info.result === 'object') {
        const openPath = String((info.result as { project_path?: string }).project_path || '')
          .replace(/\\/g, '/')
          .replace(/\/$/, '');
        const want = projectPath.replace(/\\/g, '/').replace(/\/$/, '');
        if (openPath && (openPath === want || openPath.endsWith(want) || want.endsWith(openPath))) {
          const playParams: Record<string, unknown> = { mode: scene ? 'custom' : 'main' };
          if (scene) playParams.path = scene.startsWith('res://') ? scene : `res://${scene}`;
          return this.editorCall('play_scene', playParams);
        }
      }
    }

    await this.cli.runProject(projectPath, scene);
    return jsonResult({ project_path: projectPath, scene: scene ?? null, message: 'Project started' });
  }

  private async handleGetVersion() {
    const viaEditor = await this.preferEditor('get_godot_version', {});
    if (viaEditor) return viaEditor;
    try {
      const version = await this.cli.getVersion();
      return textResult(version);
    } catch (err) {
      return textResult(err instanceof Error ? err.message : String(err), true);
    }
  }

  private async handleListProjects(args: Record<string, unknown>) {
    const directory = pick(args, 'directory');
    if (!directory) return textResult('directory is required', true);
    const recursive = args.recursive === true;
    try {
      const projects = this.cli.findProjects(directory, recursive);
      return jsonResult({ directory, recursive, count: projects.length, projects });
    } catch (err) {
      if (this.bridge.isConnected()) {
        return this.editorCall('list_projects', { directory, recursive });
      }
      return textResult(err instanceof Error ? err.message : String(err), true);
    }
  }

  private async handleProjectInfo(args: Record<string, unknown>) {
    const viaEditor = await this.preferEditor('get_project_info', args);
    if (viaEditor) return viaEditor;

    const projectPath = pick(args, 'project_path', 'projectPath');
    if (!projectPath) {
      return textResult('project_path is required when editor is not connected', true);
    }
    const projectFile = join(projectPath, 'project.godot');
    if (!existsSync(projectFile)) {
      return textResult(`Not a valid Godot project: ${projectPath}`, true);
    }
    const content = readFileSync(projectFile, 'utf8');
    const nameMatch = content.match(/config\/name="?([^"\n]+)"?/);
    let version = 'unknown';
    try {
      version = await this.cli.getVersion();
    } catch {
      /* ignore */
    }
    return jsonResult({
      project_path: projectPath,
      project_name: nameMatch?.[1] ?? '',
      godot_version: version,
      source: 'cli',
    });
  }

  private async handleCreateScene(args: Record<string, unknown>) {
    const path = pick(args, 'path', 'scene_path', 'scenePath') || '';
    const rootType = pick(args, 'root_type', 'root_node_type', 'rootNodeType') || 'Node2D';

    if (this.bridge.isConnected() && path) {
      return this.editorCall('create_scene', {
        path: path.startsWith('res://') ? path : `res://${path}`,
        root_type: rootType,
      });
    }

    const projectPath = pick(args, 'project_path', 'projectPath');
    if (!projectPath || !path) {
      return textResult('project_path and scene path are required for headless create_scene', true);
    }
    const out = await this.cli.runOperation(projectPath, 'create_scene', {
      scene_path: path,
      root_node_type: rootType,
    });
    return textResult(out || 'Scene created');
  }

  private async handleAddNode(args: Record<string, unknown>) {
    if (this.bridge.isConnected()) {
      const type = pick(args, 'type', 'node_type', 'nodeType');
      const name = pick(args, 'name', 'node_name', 'nodeName') || type;
      const parent = pick(args, 'parent_path', 'parent_node_path', 'parentNodePath') || '.';
      if (!type) return textResult('type / node_type is required', true);
      const scenePath = pick(args, 'scene_path', 'scenePath');
      if (scenePath) {
        await this.bridge.call('open_scene', {
          path: scenePath.startsWith('res://') ? scenePath : `res://${scenePath}`,
        });
      }
      return this.editorCall('add_node', {
        type,
        name,
        parent_path: parent,
        properties: (args.properties as Record<string, unknown>) ?? {},
      });
    }

    const projectPath = pick(args, 'project_path', 'projectPath');
    const scenePath = pick(args, 'scene_path', 'scenePath');
    const nodeType = pick(args, 'node_type', 'nodeType', 'type');
    const nodeName = pick(args, 'node_name', 'nodeName', 'name');
    if (!projectPath || !scenePath || !nodeType || !nodeName) {
      return textResult(
        'project_path, scene_path, node_type, node_name required for headless add_node',
        true,
      );
    }
    const out = await this.cli.runOperation(projectPath, 'add_node', {
      scene_path: scenePath,
      parent_node_path: pick(args, 'parent_node_path', 'parentNodePath', 'parent_path') || 'root',
      node_type: nodeType,
      node_name: nodeName,
      properties: args.properties ?? {},
    });
    return textResult(out || 'Node added');
  }

  private async handleLoadSprite(args: Record<string, unknown>) {
    const nodePath = pick(args, 'node_path', 'nodePath');
    const texturePath = pick(args, 'texture_path', 'texturePath');
    const scenePath = pick(args, 'scene_path', 'scenePath');

    if (this.bridge.isConnected()) {
      if (!nodePath || !texturePath) return textResult('node_path and texture_path required', true);
      return this.editorCall('load_sprite', {
        node_path: nodePath,
        texture_path: texturePath,
        scene_path: scenePath || undefined,
      });
    }

    const projectPath = pick(args, 'project_path', 'projectPath');
    if (!projectPath || !scenePath || !nodePath || !texturePath) {
      return textResult(
        'project_path, scene_path, node_path, texture_path required for headless load_sprite',
        true,
      );
    }
    const out = await this.cli.runOperation(projectPath, 'load_sprite', {
      scene_path: scenePath,
      node_path: nodePath,
      texture_path: texturePath,
    });
    return textResult(out || 'Sprite loaded');
  }

  private async handleExportMeshLibrary(args: Record<string, unknown>) {
    const scenePath = pick(args, 'scene_path', 'scenePath');
    const outputPath = pick(args, 'output_path', 'outputPath');
    const meshItemNames = (args.mesh_item_names ?? args.meshItemNames) as string[] | undefined;

    if (this.bridge.isConnected()) {
      if (!scenePath || !outputPath) return textResult('scene_path and output_path required', true);
      return this.editorCall('export_mesh_library', {
        scene_path: scenePath,
        output_path: outputPath,
        mesh_item_names: meshItemNames ?? [],
      });
    }

    const projectPath = pick(args, 'project_path', 'projectPath');
    if (!projectPath || !scenePath || !outputPath) {
      return textResult('project_path, scene_path, output_path required for headless export', true);
    }
    const out = await this.cli.runOperation(projectPath, 'export_mesh_library', {
      scene_path: scenePath,
      output_path: outputPath,
      mesh_item_names: meshItemNames ?? [],
    });
    return textResult(out || 'MeshLibrary exported');
  }

  private async handleSaveScene(args: Record<string, unknown>) {
    if (this.bridge.isConnected()) {
      return this.editorCall('save_scene', args);
    }
    const projectPath = pick(args, 'project_path', 'projectPath');
    const scenePath = pick(args, 'scene_path', 'scenePath');
    if (!projectPath || !scenePath) {
      return textResult('project_path and scene_path required for headless save_scene', true);
    }
    const params: Record<string, unknown> = { scene_path: scenePath };
    const newPath = pick(args, 'new_path', 'newPath');
    if (newPath) params.new_path = newPath;
    const out = await this.cli.runOperation(projectPath, 'save_scene', params);
    return textResult(out || 'Scene saved');
  }

  private async handleGetUid(args: Record<string, unknown>) {
    if (this.bridge.isConnected()) {
      return this.editorCall('get_uid', {
        file_path: pick(args, 'file_path', 'filePath', 'path'),
        path: pick(args, 'path', 'file_path', 'filePath'),
      });
    }
    const projectPath = pick(args, 'project_path', 'projectPath');
    const filePath = pick(args, 'file_path', 'filePath', 'path');
    if (!projectPath || !filePath) {
      return textResult('project_path and file_path required for headless get_uid', true);
    }
    const out = await this.cli.runOperation(projectPath, 'get_uid', { file_path: filePath });
    return textResult(out);
  }

  private async handleUpdateUids(args: Record<string, unknown>) {
    if (this.bridge.isConnected()) {
      return this.editorCall('update_project_uids', {
        path: pick(args, 'path') || 'res://',
        include_addons: args.include_addons === true,
      });
    }
    const projectPath = pick(args, 'project_path', 'projectPath');
    if (!projectPath) {
      return textResult('project_path required for headless update_project_uids', true);
    }
    const out = await this.cli.runOperation(projectPath, 'resave_resources', {
      project_path: 'res://',
    });
    return textResult(out || 'UIDs updated');
  }

  async start(): Promise<void> {
    try {
      await this.bridge.start();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[SERVER] Failed to bind WebSocket ports 6505-6509: ${message}`);
      console.error('[SERVER] CLI tools still work; editor bridge disabled until a port is free.');
    }

    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error(
      `[SERVER] Godot MCP Pro open server v${SERVER_VERSION} ready (WS port ${this.bridge.getPort()}${LITE ? ', lite' : ''})`,
    );
  }
}

const server = new GodotMcpProServer();
server.start().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
