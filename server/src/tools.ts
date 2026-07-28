/**
 * MCP tool definitions for agent-driven Godot production.
 * CLI tools always available; editor tools appear when the plugin connects.
 */

export type ToolDef = {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, unknown>;
    required: string[];
  };
};

const emptyProps = {
  type: 'object' as const,
  properties: {} as Record<string, unknown>,
  required: [] as string[],
};

export const CLI_TOOLS: ToolDef[] = [
  {
    name: 'health_check',
    description:
      'Agent production readiness check: plugin version, WebSocket clients, open scene, play state, issues. Call first when starting work or when tools fail.',
    inputSchema: emptyProps,
  },
  {
    name: 'agent_workflow_guide',
    description:
      'Project-neutral guide for agent-driven game production loops (explore → build → playtest → fix). Optional topic: production|2d|3d|ui|playtest.',
    inputSchema: {
      type: 'object',
      properties: {
        topic: {
          type: 'string',
          description: 'production (default) | 2d | 3d | ui | playtest',
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
 */
export const LITE_EDITOR_TOOLS: ToolDef[] = [
  {
    name: 'get_filesystem_tree',
    description: 'Project file tree with optional filter (e.g. *.tscn, *.gd)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        filter: { type: 'string' },
        max_depth: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'get_scene_tree',
    description: 'Live node hierarchy of the currently open scene',
    inputSchema: {
      type: 'object',
      properties: { max_depth: { type: 'number' } },
      required: [],
    },
  },
  {
    name: 'open_scene',
    description: 'Open a scene in the editor',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
  {
    name: 'play_scene',
    description: 'Play main/current/custom scene in editor',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string', description: 'main | current | custom | or a res:// path' },
        path: { type: 'string', description: 'Required when mode is custom' },
      },
      required: [],
    },
  },
  {
    name: 'stop_scene',
    description: 'Stop editor play session',
    inputSchema: emptyProps,
  },
  {
    name: 'update_property',
    description:
      'Set one node property (inspector fine-tune). Supports nested paths: shape.radius, mesh, material_override. Values: Vector2(...), Color(...), res://, numbers, bools.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property: { type: 'string', description: 'Name or nested path e.g. shape.radius' },
        value: {},
      },
      required: ['node_path', 'property'],
    },
  },
  {
    name: 'update_properties',
    description: 'Batch set many properties on one node (multi-field inspector edit)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        properties: { type: 'object', description: 'Map of property path → value' },
      },
      required: ['node_path', 'properties'],
    },
  },
  {
    name: 'list_property_info',
    description:
      'Inspector catalog: property names, types, enum options, ranges, current values — use before fine-tuning',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        only_editable: { type: 'boolean' },
        include_internal: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'inspect_node',
    description:
      'Full human-like inspection: properties, signals+connections, groups, script, meta',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'get_node_properties',
    description: 'Current property values on a node (simpler than list_property_info)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        category: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'add_resource',
    description:
      'Create and assign a Resource on a node property (e.g. CollisionShape2D.shape = RectangleShape2D)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property: { type: 'string' },
        resource_type: { type: 'string', description: 'e.g. RectangleShape2D, StandardMaterial3D' },
        resource_properties: { type: 'object' },
      },
      required: ['node_path', 'property', 'resource_type'],
    },
  },
  {
    name: 'clear_property',
    description: 'Clear/null a property slot (remove mesh, material, shape, etc.)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property: { type: 'string' },
      },
      required: ['node_path', 'property'],
    },
  },
  {
    name: 'remove_resource',
    description: 'Same as clear_property for resource slots',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property: { type: 'string' },
      },
      required: ['node_path', 'property'],
    },
  },
  {
    name: 'connect_signal',
    description: 'Connect a signal from source node to target method (editor persistent)',
    inputSchema: {
      type: 'object',
      properties: {
        source_path: { type: 'string' },
        signal_name: { type: 'string' },
        target_path: { type: 'string' },
        method: { type: 'string' },
      },
      required: ['source_path', 'signal_name', 'target_path', 'method'],
    },
  },
  {
    name: 'disconnect_signal',
    description: 'Disconnect a signal connection',
    inputSchema: {
      type: 'object',
      properties: {
        source_path: { type: 'string' },
        signal_name: { type: 'string' },
        target_path: { type: 'string' },
        method: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'get_signals',
    description: 'List signals and connections on a node',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'delete_node',
    description: 'Delete a node from the open scene (UndoRedo)',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'duplicate_node',
    description: 'Duplicate a node and children',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        new_name: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'rename_node',
    description: 'Rename a node',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        new_name: { type: 'string' },
      },
      required: ['node_path', 'new_name'],
    },
  },
  {
    name: 'move_node',
    description: 'Reparent / move a node in the scene tree',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        new_parent_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'add_mesh_instance',
    description: 'Add MeshInstance3D with primitive or mesh resource',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        mesh_type: { type: 'string', description: 'box, sphere, cylinder, plane, or path' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'set_material_3d',
    description: 'Set StandardMaterial3D / PBR params on a mesh node',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        albedo: { type: 'string' },
        metallic: { type: 'number' },
        roughness: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'set_meta',
    description: 'Set metadata key on a node (like inspector Metadata)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        key: { type: 'string' },
        value: {},
      },
      required: ['node_path', 'key'],
    },
  },
  {
    name: 'list_meta',
    description: 'List all metadata on a node',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'set_node_groups',
    description: 'Set group membership on a node',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        groups: { type: 'array', items: { type: 'string' } },
      },
      required: [],
    },
  },
  {
    name: 'select_nodes',
    description: 'Select nodes in the editor (like clicking in the scene tree)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        node_paths: { type: 'array', items: { type: 'string' } },
        mode: { type: 'string', description: 'replace | add | remove' },
      },
      required: [],
    },
  },
  {
    name: 'create_script',
    description: 'Create a .gd script under res://',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        content: { type: 'string' },
        extends: { type: 'string' },
        class_name: { type: 'string' },
      },
      required: ['path'],
    },
  },
  {
    name: 'edit_script',
    description: 'Edit script via replacements or full content',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        content: { type: 'string' },
        replacements: { type: 'array' },
      },
      required: ['path'],
    },
  },
  {
    name: 'read_script',
    description: 'Read a script file',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
  {
    name: 'attach_script',
    description: 'Attach a script to a node',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        script_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'validate_script',
    description: 'Validate GDScript syntax without running',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'get_editor_errors',
    description: 'Script/runtime errors from the editor',
    inputSchema: emptyProps,
  },
  {
    name: 'get_output_log',
    description: 'Editor output panel text',
    inputSchema: emptyProps,
  },
  {
    name: 'get_game_screenshot',
    description: 'Screenshot of the running game (requires play_scene)',
    inputSchema: emptyProps,
  },
  {
    name: 'get_editor_screenshot',
    description: 'Screenshot of the editor viewport',
    inputSchema: emptyProps,
  },
  {
    name: 'get_game_scene_tree',
    description: 'Runtime scene tree while playing',
    inputSchema: emptyProps,
  },
  {
    name: 'get_game_node_properties',
    description: 'Runtime node properties while playing',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'simulate_action',
    description: 'Simulate an InputMap action in the running game',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string' },
        pressed: { type: 'boolean' },
        strength: { type: 'number' },
      },
      required: ['action'],
    },
  },
  {
    name: 'simulate_key',
    description: 'Simulate a keyboard key in the running game',
    inputSchema: {
      type: 'object',
      properties: {
        keycode: { type: 'string' },
        pressed: { type: 'boolean' },
      },
      required: ['keycode'],
    },
  },
  // ── Human animation surface (AnimationPlayer / AnimationTree / Skeleton) ──
  {
    name: 'list_animations',
    description: 'List clips on an AnimationPlayer (human Animation panel library list)',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'create_animation',
    description: 'Create a new animation clip on AnimationPlayer',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        name: { type: 'string' },
        length: { type: 'number' },
        loop_mode: { type: 'number', description: '0=none 1=linear 2=pingpong' },
      },
      required: ['node_path', 'name'],
    },
  },
  {
    name: 'add_animation_track',
    description:
      'Add track: value|position_3d|rotation_3d|scale_3d|method|bezier|audio|animation|blend_shape',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        track_type: { type: 'string' },
        track_path: { type: 'string', description: 'NodePath e.g. Sprite2D:position' },
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'set_animation_keyframe',
    description: 'Insert/update a key on a value/transform track',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        track_index: { type: 'number' },
        time: { type: 'number' },
        value: {},
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'insert_method_key',
    description: 'Call Method track key (human method track in Animation editor)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        method: { type: 'string' },
        time: { type: 'number' },
        args: { type: 'array' },
        track_path: { type: 'string' },
      },
      required: ['node_path', 'animation', 'method'],
    },
  },
  {
    name: 'insert_audio_key',
    description: 'Audio track key pointing at AudioStreamPlayer path',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        stream_path: { type: 'string' },
        track_path: { type: 'string' },
        time: { type: 'number' },
      },
      required: ['node_path', 'animation', 'stream_path', 'track_path'],
    },
  },
  {
    name: 'animation_player_play',
    description: 'Play animation on AnimationPlayer (like pressing Play)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        custom_blend: { type: 'number' },
        custom_speed: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'animation_player_stop',
    description: 'Stop AnimationPlayer',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        keep_state: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'animation_player_seek',
    description: 'Seek AnimationPlayer playhead',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        time: { type: 'number' },
        update: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'ensure_reset_animation',
    description: 'Ensure RESET animation exists; optional property_paths snapshot at t=0',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property_paths: { type: 'array', items: { type: 'string' } },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'list_animation_libraries',
    description: 'List AnimationLibrary names and clips on a player',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'create_animation_tree',
    description: 'Create AnimationTree with StateMachine root (human AnimationTree node)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string', description: 'Parent path' },
        anim_player: { type: 'string' },
        name: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'get_animation_tree_structure',
    description: 'Read AnimationTree graph: states, transitions, blend trees',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'add_state_machine_state',
    description:
      'Add state: animation|blend_tree|state_machine|blend_space_1d|blend_space_2d',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        state_name: { type: 'string' },
        state_type: { type: 'string' },
        animation: { type: 'string' },
        state_machine_path: { type: 'string' },
      },
      required: ['node_path', 'state_name'],
    },
  },
  {
    name: 'add_state_machine_transition',
    description: 'Add transition between states (switch_mode, advance_mode, xfade_time)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        from_state: { type: 'string' },
        to_state: { type: 'string' },
        switch_mode: { type: 'string', description: 'immediate|sync|at_end' },
        advance_mode: { type: 'string', description: 'disabled|enabled|auto' },
        xfade_time: { type: 'number' },
        advance_expression: { type: 'string' },
      },
      required: ['node_path', 'from_state', 'to_state'],
    },
  },
  {
    name: 'travel_animation_state',
    description: 'StateMachinePlayback.travel — like clicking a state at runtime',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        to_state: { type: 'string' },
        reset: { type: 'boolean' },
      },
      required: ['node_path', 'to_state'],
    },
  },
  {
    name: 'add_blend_space_point',
    description: 'Add animation point to BlendSpace1D/2D state',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        state_name: { type: 'string' },
        animation: { type: 'string' },
        x: { type: 'number' },
        y: { type: 'number' },
        position: { type: 'number', description: '1D position' },
      },
      required: ['node_path', 'state_name', 'animation'],
    },
  },
  {
    name: 'set_tree_parameter',
    description: 'Set AnimationTree parameters/* (blend positions, oneshot, etc.)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        parameter: { type: 'string' },
        value: {},
      },
      required: ['node_path', 'parameter'],
    },
  },
  {
    name: 'find_skeletons',
    description: 'Find Skeleton3D nodes in the open scene',
    inputSchema: emptyProps,
  },
  {
    name: 'list_skeleton_bones',
    description: 'List bones on a Skeleton3D (skeleton dock)',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'get_bone_info',
    description: 'Bone rest/pose/global pose details',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        bone_name: { type: 'string' },
        bone_index: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'set_bone_pose',
    description: 'Set bone pose position/rotation_degrees/scale (skeleton dock edit)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        bone_name: { type: 'string' },
        bone_index: { type: 'number' },
        position: { type: 'object' },
        rotation_degrees: { type: 'object' },
        scale: { type: 'object' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'sprite_frames_create',
    description: 'Create a SpriteFrames resource',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'sprite_frames_add_animation',
    description: 'Add named animation to SpriteFrames',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        animation: { type: 'string' },
        speed: { type: 'number' },
        loop: { type: 'boolean' },
      },
      required: ['path', 'animation'],
    },
  },
  {
    name: 'sprite_frames_add_frame',
    description: 'Add texture frame to SpriteFrames animation',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        animation: { type: 'string' },
        texture_path: { type: 'string' },
        duration: { type: 'number' },
      },
      required: ['path', 'animation', 'texture_path'],
    },
  },
  // ── Physics / 2D / import / bone map (1.20 human surfaces) ──
  {
    name: 'create_physics_body',
    description: 'Create CharacterBody/RigidBody/StaticBody (+ optional shape)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        body_type: { type: 'string', description: 'e.g. CharacterBody2D, RigidBody3D' },
        shape: { type: 'string', description: 'rectangle|circle|capsule|box|…' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'add_shape_cast',
    description: 'Add ShapeCast2D/3D probe',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        dimension: { type: 'string' },
        shape_type: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'set_physics_material',
    description: 'PhysicsMaterial friction/bounce on a body',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        friction: { type: 'number' },
        bounce: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'setup_camera_2d',
    description: 'Create/configure Camera2D (limits, zoom, smoothing)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        zoom: {},
        limit_left: { type: 'number' },
        limit_top: { type: 'number' },
        limit_right: { type: 'number' },
        limit_bottom: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'create_bone_map',
    description: 'Create BoneMap resource with humanoid (or other) SkeletonProfile',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        profile: { type: 'string', description: 'humanoid (default)' },
      },
      required: [],
    },
  },
  {
    name: 'auto_map_bones_by_name',
    description: 'Heuristic BoneMap: profile bone names → matching Skeleton3D bones',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'res:// BoneMap' },
        skeleton_path: { type: 'string' },
      },
      required: ['path', 'skeleton_path'],
    },
  },
  {
    name: 'apply_texture_import_preset',
    description: 'Texture .import preset: 2d_pixel|2d_smooth|vram_compressed|lossless',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        preset: { type: 'string' },
      },
      required: ['path'],
    },
  },
  {
    name: 'create_atlas_texture',
    description: 'Create AtlasTexture region resource from a base texture',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        atlas_path: { type: 'string' },
        x: { type: 'number' },
        y: { type: 'number' },
        width: { type: 'number' },
        height: { type: 'number' },
      },
      required: ['path', 'atlas_path'],
    },
  },
  {
    name: 'tileset_set_tile_collision',
    description: 'Set physics polygon on a TileSet atlas tile',
    inputSchema: {
      type: 'object',
      properties: {
        tileset_path: { type: 'string' },
        source_id: { type: 'number' },
        atlas_x: { type: 'number' },
        atlas_y: { type: 'number' },
        points: { type: 'array' },
      },
      required: ['tileset_path'],
    },
  },
  {
    name: 'set_focus_neighbors',
    description: 'Control focus neighbor paths (UI keyboard/gamepad nav)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        left: { type: 'string' },
        right: { type: 'string' },
        top: { type: 'string' },
        bottom: { type: 'string' },
        focus_mode: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'config_file_set',
    description: 'Write ConfigFile key (default user://settings.cfg)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        section: { type: 'string' },
        key: { type: 'string' },
        value: {},
      },
      required: ['section', 'key'],
    },
  },
  {
    name: 'json_write',
    description: 'Write JSON to user:// or res://',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        data: {},
        pretty: { type: 'boolean' },
      },
      required: ['path', 'data'],
    },
  },
  // ── 1.21 surfaces ──
  {
    name: 'create_export_preset',
    description: 'Create export_presets.cfg entry (Windows/Linux/Web/Android/macOS/iOS)',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        platform: { type: 'string' },
        export_path: { type: 'string' },
      },
      required: ['name'],
    },
  },
  {
    name: 'create_multiplayer_template_script',
    description: 'Write ENet host/join GDScript template under res://',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        port: { type: 'number' },
        max_clients: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'setup_navigation_link',
    description: 'Add NavigationLink2D/3D (off-mesh connection)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        dimension: { type: 'string' },
        start_position: { type: 'object' },
        end_position: { type: 'object' },
      },
      required: [],
    },
  },
  {
    name: 'tileset_add_terrain_set',
    description: 'Add TileSet terrain set for auto-tiling',
    inputSchema: {
      type: 'object',
      properties: {
        tileset_path: { type: 'string' },
        mode: { type: 'string' },
      },
      required: ['tileset_path'],
    },
  },
  {
    name: 'setup_xr_origin',
    description: 'Scaffold XROrigin3D + XRCamera3D + controllers',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        controllers: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'item_list_set_items',
    description: 'Populate ItemList from string array or {text,icon} objects',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        items: { type: 'array' },
      },
      required: ['node_path', 'items'],
    },
  },
  {
    name: 'richtext_set_bbcode',
    description: 'Set RichTextLabel BBCode/text',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        bbcode: { type: 'string' },
        text: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  // ── 1.22 debugger / visual shader / XR / 2D paths ──
  {
    name: 'debugger_get_status',
    description: 'Playing? debugger paused? recent debugger errors',
    inputSchema: emptyProps,
  },
  {
    name: 'debugger_continue',
    description: 'Press debugger Continue when paused at error/breakpoint',
    inputSchema: emptyProps,
  },
  {
    name: 'set_source_breakpoint',
    description: 'Insert GDScript `breakpoint` keyword at line or after_function',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        line: { type: 'number' },
        after_function: { type: 'string' },
      },
      required: ['path'],
    },
  },
  {
    name: 'create_visual_shader',
    description: 'Create VisualShader resource (spatial/canvas_item/particles)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        mode: { type: 'string' },
      },
      required: ['path'],
    },
  },
  {
    name: 'visual_shader_add_node',
    description: 'Add VisualShader node (fresnel, color, float, texture, input, …)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        node_type: { type: 'string' },
        graph: { type: 'string' },
        x: { type: 'number' },
        y: { type: 'number' },
        input_name: { type: 'string' },
        value: {},
      },
      required: ['path', 'node_type'],
    },
  },
  {
    name: 'create_openxr_action_map',
    description: 'Create OpenXRActionMap resource and optionally set as default',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        action_set: { type: 'string' },
        set_as_default: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_line_2d',
    description: 'Create Line2D with points/width/color',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        points: { type: 'array' },
        width: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'setup_path_2d',
    description: 'Create Path2D (+ optional PathFollow2D)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        points: { type: 'array' },
        with_follow: { type: 'boolean' },
      },
      required: [],
    },
  },
  // ── 1.23 C# / OpenXR bindings / profiler ──
  {
    name: 'get_csharp_project_info',
    description: 'Detect C#/csproj/sln, mono editor, assembly settings',
    inputSchema: emptyProps,
  },
  {
    name: 'create_csharp_script',
    description: 'Create a C# Godot partial class script under res://',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        class_name: { type: 'string' },
        extends: { type: 'string' },
        namespace: { type: 'string' },
      },
      required: ['path'],
    },
  },
  {
    name: 'ensure_csharp_csproj',
    description: 'Create Godot.NET.Sdk csproj (+ optional sln) if missing',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        target_framework: { type: 'string' },
        create_solution: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'openxr_create_default_controller_bindings',
    description: 'Scaffold OpenXR action map with poses/trigger/grip + oculus-style bindings',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        profile_path: { type: 'string' },
        set_as_default: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'capture_performance_timeline',
    description: 'Sample FPS/monitors N times (game IPC when playing)',
    inputSchema: {
      type: 'object',
      properties: {
        samples: { type: 'number' },
        interval_sec: { type: 'number' },
        prefer_game: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'get_render_info',
    description: 'Draw calls, video mem, viewport sizes (+ game monitors if playing)',
    inputSchema: {
      type: 'object',
      properties: { prefer_game: { type: 'boolean' } },
      required: [],
    },
  },
  // ── 1.24 expansion ──
  {
    name: 'create_editor_plugin',
    description: 'Scaffold EditorPlugin under res://addons/<folder>/',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        folder: { type: 'string' },
        with_dock: { type: 'boolean' },
      },
      required: ['name'],
    },
  },
  {
    name: 'create_custom_resource_script',
    description: 'Create Resource subclass with class_name + @export fields',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        class_name: { type: 'string' },
        exports: { type: 'array' },
        instance_path: { type: 'string' },
      },
      required: ['path'],
    },
  },
  {
    name: 'create_noise_texture',
    description: 'Create NoiseTexture2D (FastNoiseLite) resource',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        width: { type: 'number' },
        height: { type: 'number' },
        seed: { type: 'number' },
      },
      required: ['path'],
    },
  },
  {
    name: 'create_tween_helper_script',
    description: 'Write reusable Tween helper (fade/move/scale) under res://',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'tilemap_set_cells_terrain_connect',
    description: 'Paint TileMap terrain with auto-connect peering',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        cells: { type: 'array' },
        terrain_set: { type: 'number' },
        terrain: { type: 'number' },
      },
      required: ['node_path', 'cells'],
    },
  },
  {
    name: 'setup_subviewport',
    description: 'Create SubViewport (+ optional SubViewportContainer)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        width: { type: 'number' },
        height: { type: 'number' },
        with_container: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'run_dotnet_build',
    description: 'Run dotnet build on project csproj/sln',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        configuration: { type: 'string' },
      },
      required: [],
    },
  },
  // ── 1.25 ──
  {
    name: 'create_gdextension_project',
    description: 'Scaffold GDExtension C++ project (.gdextension, src, SConstruct stub)',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string' },
        class_name: { type: 'string' },
        folder: { type: 'string' },
      },
      required: ['name'],
    },
  },
  {
    name: 'create_dialogue_resource',
    description: 'Create JSON dialogue graph (lines + choices)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        lines: { type: 'array' },
        start: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'create_cutscene_resource',
    description: 'Create JSON cutscene step list',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        steps: { type: 'array' },
      },
      required: [],
    },
  },
  {
    name: 'apply_container_recipe',
    description: 'Layout recipe: full_rect_margin_vbox|toolbar_hbox|form_grid|scroll_list|sidebar_split|centered_panel',
    inputSchema: {
      type: 'object',
      properties: {
        recipe: { type: 'string' },
        parent_path: { type: 'string' },
      },
      required: ['recipe'],
    },
  },
  {
    name: 'setup_compositor',
    description: 'Attach Compositor to WorldEnvironment (Godot 4.3+)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'get_last_build_log',
    description: 'Last dotnet/godot C# build log with parsed errors/warnings',
    inputSchema: emptyProps,
  },
  // ── 1.26 gameplay / flow ──
  {
    name: 'create_scene_transition_script',
    description: 'Autoload-ready fade transition + change_scene helper',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        fade_time: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'create_loading_screen_scene',
    description: 'Threaded ResourceLoader loading screen scene + script',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        next_scene: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'create_save_manager_script',
    description: 'JSON save/load manager under user://saves (optional autoload)',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_signal_bus_script',
    description: 'Global EventBus autoload template',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        signals: { type: 'array' },
        add_autoload: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_object_pool_script',
    description: 'Node object pool acquire/release helper',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'setup_canvas_layer',
    description: 'Add CanvasLayer for HUD stacking',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        layer: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'run_gdextension_scons_build',
    description: 'Run scons in a GDExtension folder (needs godot-cpp + toolchain)',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string' },
        platform: { type: 'string' },
        target: { type: 'string' },
      },
      required: [],
    },
  },
  // ── 1.27 ──
  {
    name: 'set_sprite_texture',
    description: 'Assign texture on Sprite2D/3D, TextureRect, or TextureButton',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        texture_path: { type: 'string' },
      },
      required: ['node_path', 'texture_path'],
    },
  },
  {
    name: 'setup_label',
    description: 'Create a Label node with text',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        text: { type: 'string' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'setup_button',
    description: 'Create a Button node',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        text: { type: 'string' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'list_groups_in_scene',
    description: 'List non-internal groups and member node paths',
    inputSchema: emptyProps,
  },
  {
    name: 'list_autoloads',
    description: 'List project autoloads (name, path, singleton)',
    inputSchema: emptyProps,
  },
  {
    name: 'setup_spring_arm_3d',
    description: 'Add SpringArm3D (optional camera child)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        spring_length: { type: 'number' },
        with_camera: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_state_machine_script',
    description: 'Generic gameplay FSM script (enter/exit/update states)',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: [],
    },
  },
];

/** Tools that should prefer the live editor plugin when connected */
export const EDITOR_PREFERRED = new Set([
  'health_check',
  'agent_workflow_guide',
  'get_godot_version',
  'get_uid',
  'update_project_uids',
  'load_sprite',
  'export_mesh_library',
  'create_scene',
  'add_node',
  'save_scene',
  'get_project_info',
  'list_projects',
  'launch_editor',
  'list_mcp_commands',
  ...LITE_EDITOR_TOOLS.map((t) => t.name),
]);

export function parseLiteMode(argv: string[]): boolean {
  if (argv.includes('--lite') || argv.includes('--minimal')) return true;
  if (process.env.GODOT_MCP_LITE === 'true' || process.env.GODOT_MCP_LITE === '1') return true;
  return false;
}
