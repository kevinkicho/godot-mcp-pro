import type { ToolDef } from './tool-types.js';
import { emptyProps } from './tool-types.js';

export const CLI_TOOLS: ToolDef[] = [
  {
    name: 'health_check',
    description:
      'Agent production readiness check: plugin version, WebSocket clients, open scene, play state, issues. Call first when starting work or when tools fail.',
    inputSchema: emptyProps,
  },
  {
    name: 'runtime_ping',
    description:
      'Ping MCPGameInspector runtime TCP (6510-6514). Works with editor Play or standalone game that has runtime autoloads.',
    inputSchema: emptyProps,
  },
  {
    name: 'runtime_call',
    description:
      'Call a game runtime inspector command over TCP (standalone). Retries on queue_full. Optional token= or MCP_RUNTIME_TOKEN.',
    inputSchema: {
      type: 'object',
      properties: {
        command: { type: 'string' },
        params: { type: 'object' },
        port: { type: 'number' },
        timeout_ms: { type: 'number' },
        token: { type: 'string', description: 'Runtime auth token if set_runtime_token / MCP_RUNTIME_TOKEN' },
        retries: { type: 'number' },
      },
      required: ['command'],
    },
  },
  {
    name: 'set_runtime_token',
    description:
      'Set or clear project mcp/runtime_token for runtime TCP auth. Also set MCP_RUNTIME_TOKEN env for the MCP server process.',
    inputSchema: {
      type: 'object',
      properties: {
        token: { type: 'string' },
        clear: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'get_runtime_info',
    description: 'Runtime TCP status: port, queue depth, clients, auth_required.',
    inputSchema: emptyProps,
  },
  {
    name: 'web_serve_export',
    description: 'Serve a Godot HTML5 export directory on localhost (for Playwright probe).',
    inputSchema: {
      type: 'object',
      properties: {
        export_dir: { type: 'string' },
        port: { type: 'number' },
      },
      required: ['export_dir'],
    },
  },
  {
    name: 'web_serve_stop',
    description: 'Stop the static server started by web_serve_export.',
    inputSchema: emptyProps,
  },
  {
    name: 'web_playwright_probe',
    description:
      'Optional Playwright probe of a web export (screenshot/console). Requires: npm i -D playwright && npx playwright install chromium. Not for desktop Godot.',
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string' },
        export_dir: { type: 'string' },
        serve_port: { type: 'number' },
        wait_ms: { type: 'number' },
        screenshot_path: { type: 'string' },
        record_video_dir: { type: 'string' },
      },
      required: [],
    },
  },

  {
    name: 'agent_workflow_guide',
    description:
      'Project-neutral guide for agent-driven game production loops (explore → build → playtest → fix). Optional topic: production|2d|3d|ui|playtest|assets|inspector.',
    inputSchema: {
      type: 'object',
      properties: {
        topic: {
          type: 'string',
          description: 'production (default) | 2d | 3d | ui | playtest | assets | inspector',
        },
      },
      required: [],
    },
  },
  {
    name: 'get_connection_status',
    description: 'Lightweight WebSocket connection status (port, clients, discovered command count)',
    inputSchema: emptyProps,
  },
  {
    name: 'launch_editor',
    description: 'Launch the Godot editor for a project directory containing project.godot',
    inputSchema: {
      type: 'object',
      properties: {
        project_path: { type: 'string', description: 'Absolute path to Godot project root' },
        projectPath: { type: 'string', description: 'Alias for project_path' },
      },
      required: [],
    },
  },
  {
    name: 'run_project',
    description: 'Run a Godot project (editor play_scene if same project connected; else CLI process)',
    inputSchema: {
      type: 'object',
      properties: {
        project_path: { type: 'string' },
        projectPath: { type: 'string' },
        scene: { type: 'string', description: 'Optional scene path to run' },
      },
      required: [],
    },
  },
  {
    name: 'get_debug_output',
    description: 'Stdout/stderr from CLI run_project process',
    inputSchema: emptyProps,
  },
  {
    name: 'stop_project',
    description: 'Stop CLI run_project process and/or editor play_scene',
    inputSchema: emptyProps,
  },
  {
    name: 'get_godot_version',
    description: 'Installed or editor Godot version',
    inputSchema: emptyProps,
  },
  {
    name: 'list_projects',
    description: 'Find directories containing project.godot under a directory',
    inputSchema: {
      type: 'object',
      properties: {
        directory: { type: 'string' },
        recursive: { type: 'boolean' },
      },
      required: ['directory'],
    },
  },
  {
    name: 'get_project_info',
    description: 'Project metadata (name, main scene, renderer, autoloads when editor connected)',
    inputSchema: {
      type: 'object',
      properties: {
        project_path: { type: 'string' },
        projectPath: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'create_scene',
    description: 'Create a new .tscn (editor or headless). Prefer res:// path.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'res://scenes/foo.tscn' },
        scene_path: { type: 'string' },
        scenePath: { type: 'string' },
        project_path: { type: 'string', description: 'Required for headless when editor offline' },
        root_type: { type: 'string', description: 'e.g. Node2D, Node3D, Control' },
        root_node_type: { type: 'string' },
        rootNodeType: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'add_node',
    description: 'Add a node to the open or specified scene',
    inputSchema: {
      type: 'object',
      properties: {
        type: { type: 'string', description: 'Node class e.g. Sprite2D' },
        node_type: { type: 'string' },
        name: { type: 'string' },
        node_name: { type: 'string' },
        parent_path: { type: 'string', description: 'Parent path, default .' },
        parent_node_path: { type: 'string' },
        properties: { type: 'object' },
        scene_path: { type: 'string' },
        project_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'load_sprite',
    description: 'Assign a texture to Sprite2D / Sprite3D / TextureRect',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        texture_path: { type: 'string' },
        scene_path: { type: 'string' },
        project_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'export_mesh_library',
    description: 'Export a 3D scene as MeshLibrary for GridMap',
    inputSchema: {
      type: 'object',
      properties: {
        scene_path: { type: 'string' },
        output_path: { type: 'string' },
        mesh_item_names: { type: 'array', items: { type: 'string' } },
        project_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'save_scene',
    description: 'Save the current or specified scene',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        scene_path: { type: 'string' },
        project_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'get_uid',
    description: 'Get resource UID for a res:// file (Godot 4.4+)',
    inputSchema: {
      type: 'object',
      properties: {
        file_path: { type: 'string' },
        path: { type: 'string' },
        project_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'update_project_uids',
    description: 'Resave resources to refresh UIDs (skips open scenes)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'res:// subpath to scan' },
        include_addons: { type: 'boolean' },
        project_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'call_editor',
    description:
      'Call any plugin command by name when editor is connected. Use list_mcp_commands or health_check first. Preferred escape hatch in --lite mode.',
    inputSchema: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'e.g. get_scene_tree, play_scene, update_property' },
        params: { type: 'object' },
      },
      required: ['method'],
    },
  },
  {
    name: 'list_mcp_commands',
    description: 'List all registered editor plugin command names (requires connection)',
    inputSchema: emptyProps,
  },
  {
    name: 'list_docs_coverage',
    description:
      'Map of official godot-docs tutorial areas → MCP tools (100% top-level docs topic coverage)',
    inputSchema: emptyProps,
  },
  {
    name: 'describe_class',
    description:
      'Full ClassDB description of any engine class (methods, signals, properties, constants) — class reference surface',
    inputSchema: {
      type: 'object',
      properties: {
        class_name: { type: 'string', description: 'e.g. CharacterBody3D, TileMap, MultiplayerSpawner' },
        include_inherited: { type: 'boolean' },
      },
      required: ['class_name'],
    },
  },
  {
    name: 'list_classes',
    description: 'Search engine classes by name/parent (ClassDB)',
    inputSchema: {
      type: 'object',
      properties: {
        filter: { type: 'string' },
        parent: { type: 'string' },
        instantiable_only: { type: 'boolean' },
        max_results: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'reimport_files',
    description: 'Reimport res:// assets (assets pipeline)',
    inputSchema: {
      type: 'object',
      properties: { paths: { type: 'array', items: { type: 'string' } } },
      required: ['paths'],
    },
  },
  {
    name: 'wait_for_import',
    description: 'Wait until EditorFileSystem finishes scanning/importing',
    inputSchema: {
      type: 'object',
      properties: { timeout_sec: { type: 'number' } },
      required: [],
    },
  },
  {
    name: 'get_import_info',
    description: 'Read .import remap/params for a resource',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
  {
    name: 'set_import_option',
    description: 'Set a key in resource .import and optionally reimport',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        key: { type: 'string' },
        value: {},
        section: { type: 'string' },
        reimport: { type: 'boolean' },
      },
      required: ['path', 'key'],
    },
  },
  {
    name: 'scan_filesystem',
    description: 'Trigger EditorFileSystem scan',
    inputSchema: emptyProps,
  },
  {
    name: 'res_copy_file',
    description: 'Copy file into/within res:// (from OS path or res://)',
    inputSchema: {
      type: 'object',
      properties: {
        from: { type: 'string' },
        to: { type: 'string' },
      },
      required: ['from', 'to'],
    },
  },
  {
    name: 'res_write_text',
    description: 'Write a text file under res://',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        content: { type: 'string' },
        force: { type: 'boolean' },
      },
      required: ['path', 'content'],
    },
  },
  {
    name: 'remove_input_action',
    description: 'Remove an InputMap action from the project',
    inputSchema: {
      type: 'object',
      properties: { action: { type: 'string' } },
      required: ['action'],
    },
  },
  {
    name: 'tileset_create',
    description: 'Create a TileSet resource',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        tile_size: { type: 'number' },
      },
      required: ['path'],
    },
  },
  {
    name: 'tileset_add_atlas_source',
    description: 'Add atlas texture source + tiles to a TileSet',
    inputSchema: {
      type: 'object',
      properties: {
        tileset_path: { type: 'string' },
        texture_path: { type: 'string' },
        columns: { type: 'number' },
        rows: { type: 'number' },
      },
      required: ['tileset_path', 'texture_path'],
    },
  },
  {
    name: 'setup_joint',
    description: 'Add a physics joint (PinJoint2D, HingeJoint3D, …)',
    inputSchema: {
      type: 'object',
      properties: {
        joint_type: { type: 'string' },
        parent_path: { type: 'string' },
        node_a: { type: 'string' },
        node_b: { type: 'string' },
      },
      required: ['joint_type'],
    },
  },
  {
    name: 'setup_area',
    description: 'Create Area2D/Area3D with optional shape',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        dimension: { type: 'string' },
        shape_type: { type: 'string' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'set_locale',
    description: 'Set TranslationServer locale (i18n)',
    inputSchema: {
      type: 'object',
      properties: { locale: { type: 'string' } },
      required: ['locale'],
    },
  },
  {
    name: 'run_export',
    description: 'Execute a project export preset headlessly and return logs',
    inputSchema: {
      type: 'object',
      properties: {
        preset_name: { type: 'string' },
        preset_index: { type: 'number' },
        debug: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'set_scene_unique_name',
    description: 'Enable %UniqueName access for a node in its owner scene',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        enabled: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
];

/**
 * Core editor commands exposed even in --lite mode (with schemas when known).
 * Everything else is available via call_editor(method, params).
 * Headless production macros are first-class: agents should not need a human in the IDE docks.
 */

