import type { ToolDef } from './tool-types.js';
import { emptyProps } from './tool-types.js';

export const LITE_EDITOR_TOOLS: ToolDef[] = [
  {
    name: 'agent_ensure_ready',
    description:
      'Session start: launch editor if needed, ensure runtime autoloads, open main scene. Prefer before production work.',
    inputSchema: {
      type: 'object',
      properties: {
        project_path: { type: 'string' },
        wait_ms: { type: 'number' },
        ensure_runtime_autoloads: { type: 'boolean' },
        open_main_if_empty: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'batch_call_editor',
    description: 'Run multiple plugin methods in one request: calls=[{method,params}]',
    inputSchema: {
      type: 'object',
      properties: {
        calls: { type: 'array', items: { type: 'object' } },
        stop_on_error: { type: 'boolean' },
      },
      required: ['calls'],
    },
  },
  {
    name: 'agent_production_status',
    description:
      'Dashboard: plugin version, command count, open scene, import scanning, play state, recommended production loop. Prefer after health_check.',
    inputSchema: emptyProps,
  },
  {
    name: 'scaffold_project_defaults',
    description:
      'Human first-hour project setup: folders, viewport/stretch, physics layer names, input map preset, main scene shell. Call once on new projects.',
    inputSchema: {
      type: 'object',
      properties: {
        genre: { type: 'string', description: '2d | 3d | ui | generic' },
        project_name: { type: 'string' },
        viewport_width: { type: 'number' },
        viewport_height: { type: 'number' },
        main_scene: { type: 'string', description: 'res://scenes/main.tscn' },
        root_type: { type: 'string', description: 'Node2D | Node3D | Control (auto from genre)' },
        input_preset: { type: 'string', description: 'platformer_2d | topdown_2d | fps_basic | ui_menu' },
        setup_input: { type: 'boolean' },
        force_main_scene: { type: 'boolean' },
        folders: { type: 'array', items: { type: 'string' } },
      },
      required: [],
    },
  },
  {
    name: 'create_input_map_preset',
    description:
      'Apply a named InputMap pack (WASD/jump/shoot or FPS) to Project Settings + live InputMap — human Project → Input Map dock.',
    inputSchema: {
      type: 'object',
      properties: {
        preset: { type: 'string', description: 'platformer_2d | topdown_2d | fps_basic | ui_menu' },
        actions: { type: 'object', description: 'Custom action→events map (alternative to preset)' },
        deadzone: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'stage_files_into_res',
    description:
      'Copy OS/files into res:// (batch). Human "drop into FileSystem dock". Optionally waits for import.',
    inputSchema: {
      type: 'object',
      properties: {
        files: {
          type: 'array',
          description: 'Array of {from, to} or source path strings (uses dest_dir + filename)',
          items: {},
        },
        dest_dir: { type: 'string', description: 'Default res://assets' },
        wait_import: { type: 'boolean' },
        timeout_sec: { type: 'number' },
        reimport: { type: 'boolean' },
      },
      required: ['files'],
    },
  },
  {
    name: 'ensure_imported',
    description:
      'Scan/wait until res:// paths are ResourceLoader-ready (Import dock wait). Use after copying assets.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        paths: { type: 'array', items: { type: 'string' } },
        timeout_sec: { type: 'number' },
        reimport: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'import_paths',
    description:
      'One-shot asset pipeline: if files[] present → stage_files_into_res; else ensure_imported. Prefer for agent asset intake.',
    inputSchema: {
      type: 'object',
      properties: {
        files: { type: 'array', items: {} },
        path: { type: 'string' },
        paths: { type: 'array', items: { type: 'string' } },
        dest_dir: { type: 'string' },
        timeout_sec: { type: 'number' },
        reimport: { type: 'boolean' },
        wait_import: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'wire_signal_to_new_method',
    description:
      'Human Signal dock: connect source signal → create method on target script (creates script if needed) + persistent connection.',
    inputSchema: {
      type: 'object',
      properties: {
        source_path: { type: 'string', description: 'Node path of signal emitter' },
        signal_name: { type: 'string', description: 'e.g. pressed, body_entered' },
        target_path: { type: 'string', description: 'Node that receives the method' },
        method_name: { type: 'string', description: 'Default _on_<source>_<signal>' },
        script_path: { type: 'string', description: 'If target has no script' },
        method_args: { type: 'string', description: 'Override param list; else inferred from signal' },
        print_debug: { type: 'boolean' },
        deferred: { type: 'boolean' },
        force: { type: 'boolean' },
      },
      required: ['source_path', 'signal_name', 'target_path'],
    },
  },
  {
    name: 'playtest_report',
    description:
      'Human "hit Play, glance at Output": play main/current/custom, settle, collect debugger errors, optional game tree/asserts/screenshot, then stop.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string', description: 'main | current | custom' },
        path: { type: 'string', description: 'Scene path when mode=custom' },
        settle_sec: { type: 'number', description: 'Wait after play starts (default 1.5)' },
        stop_after: { type: 'boolean', description: 'Stop play after report (default true)' },
        screenshot: { type: 'boolean' },
        include_screenshot_data: {
          type: 'boolean',
          description: 'Include base64 image (large). Default false — path/meta only',
        },
        asserts: {
          type: 'array',
          description: '[{node_path, property, equals?}] runtime checks via game IPC',
          items: { type: 'object' },
        },
        max_depth: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'playtest_sequence',
    description:
      'Closed-loop playtest: play scene, run ordered steps (wait/action/key/mouse/assert/screenshot), stop. Human "play and press keys" as one call.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string', description: 'main | current | custom' },
        path: { type: 'string' },
        settle_sec: { type: 'number' },
        stop_after: { type: 'boolean' },
        stop_on_fail: { type: 'boolean' },
        steps: {
          type: 'array',
          description:
            '[{type:wait|action|key|mouse_click|assert|screenshot|get_tree, ...}]',
          items: { type: 'object' },
        },
      },
      required: ['steps'],
    },
  },
  {
    name: 'mesh_create_trimesh_static_body',
    description:
      'MeshInstance3D Mesh menu: Create Trimesh Static Body (StaticBody3D + ConcavePolygonShape).',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        body_name: { type: 'string' },
        collision_layer: { type: 'number' },
        collision_mask: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'mesh_create_convex_collision',
    description: 'Create convex CollisionShape3D sibling from MeshInstance3D mesh.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        name: { type: 'string' },
        clean: { type: 'boolean' },
        simplify: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'remap_resource_references',
    description:
      'Rewrite res:// references after move/rename (dry_run first). Text .tscn/.tres/.gd files.',
    inputSchema: {
      type: 'object',
      properties: {
        from: { type: 'string' },
        to: { type: 'string' },
        dry_run: { type: 'boolean' },
        search_root: { type: 'string' },
        force: { type: 'boolean' },
      },
      required: ['from', 'to'],
    },
  },
  {
    name: 'audit_scene_tree',
    description:
      'Open-scene health: node counts, missing scripts, empty collision shapes, cameras/lights stats.',
    inputSchema: {
      type: 'object',
      properties: { max_depth: { type: 'number' } },
      required: [],
    },
  },
  {
    name: 'editor_focus_node',
    description: 'Select node and frame editor viewport (F-key parity for 3D).',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'csg_bake_to_mesh_instance',
    description: 'Bake CSGShape3D to MeshInstance3D; optional trimesh/convex StaticBody.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        name: { type: 'string' },
        add_collision: { type: 'boolean' },
        collision_mode: { type: 'string', description: 'trimesh | convex' },
        hide_csg: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'mesh_generate_lods',
    description: 'Generate mesh LODs (ImporterMesh path) on MeshInstance3D.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        normal_merge_angle: { type: 'number' },
        normal_split_angle: { type: 'number' },
        save_path: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'lightmap_bake_prepare',
    description: 'Batch UV2 unwrap + gi_mode static + ensure LightmapGI; optional request_bake.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        texel_size: { type: 'number' },
        only_missing_uv2: { type: 'boolean' },
        add_lightmap_gi: { type: 'boolean' },
        request_bake: { type: 'boolean' },
        max: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'capture_play_session',
    description: 'Play scene, capture frames at fps, optional FFmpeg video (movie-maker fallback).',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string' },
        path: { type: 'string' },
        duration_sec: { type: 'number' },
        fps: { type: 'number' },
        frames_dir: { type: 'string' },
        make_video: { type: 'boolean' },
        output_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'navigation_query_path',
    description: 'Query NavigationServer path between from/to (prefer while playing after bake).',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string', description: '3d | 2d' },
        from: { type: 'object' },
        to: { type: 'object' },
        optimize: { type: 'boolean' },
      },
      required: ['from', 'to'],
    },
  },
  {
    name: 'create_simple_locomotion_tree',
    description: 'AnimationTree recipe: Idle/Walk/Run (+ optional Jump) state machine.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        anim_player: { type: 'string' },
        idle: { type: 'string' },
        walk: { type: 'string' },
        run: { type: 'string' },
        jump: { type: 'string' },
        xfade_time: { type: 'number' },
        active: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'list_agent_pipelines',
    description: 'List multi-step production pipelines (lighting, LODs, nav, greybox, locomotion).',
    inputSchema: emptyProps,
  },
  {
    name: 'pipeline_prepare_level_lighting',
    description: 'Pipeline: batch UV2 + lightmap quality preset + optional bake.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        quality: { type: 'string', description: 'draft|medium|high|ultra|mobile' },
        texel_size: { type: 'number' },
        request_bake: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'pipeline_greybox_to_playable',
    description: 'Pipeline: greybox room → optional collision/nav → playtest_report.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        size: { type: 'object' },
        setup_nav: { type: 'boolean' },
        playtest: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'apply_platform_render_pack',
    description: 'LOD + lightmap + SDFGI pack for mobile|desktop|high_end.',
    inputSchema: {
      type: 'object',
      properties: {
        pack: { type: 'string' },
        source_mesh_path: { type: 'string' },
        node_path: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'navigation_live_path',
    description: 'Play if needed, query nav path, draw debug path, optional stop.',
    inputSchema: {
      type: 'object',
      properties: {
        from: { type: 'object' },
        to: { type: 'object' },
        mode: { type: 'string' },
        auto_play: { type: 'boolean' },
        draw: { type: 'boolean' },
        stop_after: { type: 'boolean' },
      },
      required: ['from', 'to'],
    },
  },
  {
    name: 'setup_interaction_zone',
    description: 'Area2D/3D interaction zone (use/talk/pickup) with shape + script meta.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        kind: { type: 'string', description: 'use|talk|pickup|trigger' },
        is_3d: { type: 'boolean' },
        radius: { type: 'number' },
        prompt: { type: 'string' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'set_particle_process_params',
    description: 'Bulk ParticleProcessMaterial / particle node numerical params.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        amount: { type: 'number' },
        lifetime: { type: 'number' },
        direction: { type: 'object' },
        gravity: { type: 'object' },
        emission_shape: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'get_export_signing_checklist',
    description: 'Platform export signing checklist (Android/iOS/desktop/web).',
    inputSchema: {
      type: 'object',
      properties: { platform: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'analyze_project_best_practices',
    description: 'Project hygiene: main scene, autoloads, layers, input, export presets.',
    inputSchema: emptyProps,
  },
  {
    name: 'create_http_client_script',
    description: 'HTTP GET/POST JSON service script; optional autoload.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'extract_strings_from_open_scene',
    description: 'Extract UI/text strings from the open scene for localization.',
    inputSchema: {
      type: 'object',
      properties: {
        include_node_names: { type: 'boolean' },
        min_length: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'export_translation_csv',
    description: 'Write locale CSV (keys + locale columns) from open scene or string list.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        locales: { type: 'array', items: { type: 'string' } },
        from_open_scene: { type: 'boolean' },
        from_project_scan: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'tilemap_fill_terrain_rect',
    description: 'Fill a tilemap rect with terrain connect (auto-tile).',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        x0: { type: 'number' },
        y0: { type: 'number' },
        x1: { type: 'number' },
        y1: { type: 'number' },
        terrain_set: { type: 'number' },
        terrain: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'list_import_option_schema',
    description: 'Documented import params for texture|scene_3d|audio|font|csv.',
    inputSchema: {
      type: 'object',
      properties: { type: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'setup_path_follow',
    description: 'Add PathFollow2D/3D under a Path node with progress/loop options.',
    inputSchema: {
      type: 'object',
      properties: {
        path_node: { type: 'string' },
        parent_path: { type: 'string' },
        progress_ratio: { type: 'number' },
        loop: { type: 'boolean' },
        rotation_mode: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'set_hinge_joint_limits',
    description: 'Configure HingeJoint3D angular limits (degrees by default).',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        limit_enabled: { type: 'boolean' },
        limit_upper: { type: 'number' },
        limit_lower: { type: 'number' },
        motor_enabled: { type: 'boolean' },
        radians: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'generate_ragdoll_from_skeleton',
    description: 'Auto-create PhysicalBone3D capsules (+ optional simulator) from Skeleton3D.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        use_simulator: { type: 'boolean' },
        shape: { type: 'string' },
        radius_scale: { type: 'number' },
        max_bones: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'set_xr_passthrough_settings',
    description: 'OpenXR blend/passthrough-related project settings (device-dependent).',
    inputSchema: {
      type: 'object',
      properties: {
        openxr_enabled: { type: 'boolean' },
        environment_blend_mode: { type: 'string', description: 'opaque|additive|alpha|passthrough' },
        submit_depth_buffer: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_vehicle_body',
    description: 'VehicleBody3D + chassis collision + four VehicleWheel3D recipe.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        mass: { type: 'number' },
        add_wheels: { type: 'boolean' },
        wheel_radius: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'tileset_create_tiles_in_region',
    description: 'Create TileSet atlas tiles for a grid region (x0..x1, y0..y1).',
    inputSchema: {
      type: 'object',
      properties: {
        tileset_path: { type: 'string' },
        source_id: { type: 'number' },
        x0: { type: 'number' },
        y0: { type: 'number' },
        x1: { type: 'number' },
        y1: { type: 'number' },
      },
      required: ['tileset_path'],
    },
  },
  {
    name: 'create_shader_include_library_preset',
    description: 'Write common/math/noise/tonemap .gdshaderinc library under shaders/includes.',
    inputSchema: {
      type: 'object',
      properties: { dir: { type: 'string' }, overwrite: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'setup_tab_container',
    description: 'TabContainer with optional pages array for UI shells.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        pages: { type: 'array', items: {} },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'create_interest_manager_script',
    description: 'AOI/interest multiplayer helper script; optional autoload.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_skeleton_ik',
    description: 'Add SkeletonIK3D under a Skeleton3D with root/tip bones.',
    inputSchema: {
      type: 'object',
      properties: {
        skeleton_path: { type: 'string' },
        root_bone: { type: 'string' },
        tip_bone: { type: 'string' },
        target_node: { type: 'string' },
        start: { type: 'boolean' },
      },
      required: ['skeleton_path'],
    },
  },
  {
    name: 'setup_timer',
    description: 'Add Timer node with wait_time/one_shot/autostart.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        wait_time: { type: 'number' },
        one_shot: { type: 'boolean' },
        autostart: { type: 'boolean' },
      },
      required: [],
    },
  },
  // ── Modern game systems (sophisticated games need these composed tools) ──
  {
    name: 'setup_character_2d',
    description:
      'Full CharacterBody2D stack: collision + optional sprite/camera + platformer|topdown controller script. Prefer over assembling nodes by hand.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        name: { type: 'string' },
        controller: { type: 'string', description: 'platformer | topdown | none' },
        shape: { type: 'string', description: 'capsule | circle | rect' },
        add_sprite: { type: 'boolean' },
        add_camera: { type: 'boolean' },
        texture_path: { type: 'string' },
        script_path: { type: 'string' },
        speed: { type: 'number' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_character_3d',
    description:
      'Full CharacterBody3D stack: capsule collision + mesh + FPS controller (Head/Camera) script.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        name: { type: 'string' },
        controller: { type: 'string', description: 'fps | none' },
        add_camera: { type: 'boolean' },
        add_mesh: { type: 'boolean' },
        speed: { type: 'number' },
        script_path: { type: 'string' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_ai_agent_2d',
    description:
      'Enemy CharacterBody2D + NavigationAgent2D + chase|patrol AI script + optional detection area.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        name: { type: 'string' },
        behavior: { type: 'string', description: 'chase | patrol | none' },
        speed: { type: 'number' },
        target_group: { type: 'string', description: 'Default player' },
        add_detection: { type: 'boolean' },
        detect_radius: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'setup_ai_agent_3d',
    description: 'Enemy CharacterBody3D + NavigationAgent3D + chase|patrol AI script.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        name: { type: 'string' },
        behavior: { type: 'string', description: 'chase | patrol | none' },
        speed: { type: 'number' },
        target_group: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'setup_hitbox',
    description: 'Damage-dealing Area2D/3D with optional damage script (combat hitbox).',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        dimension: { type: 'string', description: '2d | 3d' },
        damage: { type: 'number' },
        radius: { type: 'number' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'setup_hurtbox',
    description: 'Damage-receiving Area2D/3D (combat hurtbox for HealthComponent targets).',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        dimension: { type: 'string' },
        radius: { type: 'number' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'setup_hud',
    description: 'CanvasLayer HUD: health label/bar + score with set_health/set_score API.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        max_health: { type: 'number' },
        attach_script: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_pause_menu',
    description: 'Always-process pause overlay (dimmer + resume/quit). Uses pause/ui_cancel actions.',
    inputSchema: {
      type: 'object',
      properties: { parent_path: { type: 'string' }, layer: { type: 'number' } },
      required: [],
    },
  },
  {
    name: 'setup_inventory_ui',
    description: 'Inventory grid UI (slot panels) with toggle + set_item API.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        columns: { type: 'number' },
        slots: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'setup_dialogue_box_ui',
    description: 'Bottom dialogue panel with show_lines([{speaker,text}]) API.',
    inputSchema: {
      type: 'object',
      properties: { parent_path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'apply_environment_preset',
    description:
      'One-shot modern WorldEnvironment look: cinematic|outdoor_day|outdoor_night|indoor|stylized|horror|clean (glow/SSAO/SSR/SDFGI/fog).',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        preset: { type: 'string' },
        sdfgi: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_camera_follow_2d',
    description: 'Camera2D that follows a target node (smoothing + optional limits).',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        target_path: { type: 'string' },
        smoothing: { type: 'boolean' },
        zoom: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'setup_third_person_camera',
    description: 'SpringArm3D + Camera3D pivot with mouse-look script for third-person games.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        arm_length: { type: 'number' },
        height: { type: 'number' },
        fov: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'create_health_component_script',
    description: 'HealthComponent (class_name) with take_damage/heal and health_changed/died signals.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        max_health: { type: 'number' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_game_state_script',
    description: 'GameState autoload: score, flags, pause helpers.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_audio_manager_script',
    description: 'AudioManager autoload: play_sfx + music crossfade; ensures SFX/Music buses.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'list_character_templates',
    description: 'List character/combat template tools available for modern game scaffolding.',
    inputSchema: emptyProps,
  },
  {
    name: 'list_ai_templates',
    description: 'List AI/NPC template tools (chase, patrol, FSM, interactable).',
    inputSchema: emptyProps,
  },
  {
    name: 'list_game_ui_templates',
    description: 'List game UI template tools (HUD, pause, inventory, dialogue, audio).',
    inputSchema: emptyProps,
  },
  {
    name: 'list_render_presets',
    description: 'List environment presets and camera system tools.',
    inputSchema: emptyProps,
  },
  // ── 3D import depth / quests / multiplayer runtime ──
  {
    name: 'list_imported_scene_contents',
    description: 'Inventory MeshInstance3D/Skeleton/AnimationPlayer inside an imported .glb/.gltf/.tscn.',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string', description: 'res:// model path' } },
      required: ['path'],
    },
  },
  {
    name: 'extract_meshes_from_scene',
    description: 'Save unique meshes from an imported 3D scene into res://assets/meshes (or dest_dir).',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        dest_dir: { type: 'string' },
        name_filter: { type: 'string' },
        text: { type: 'boolean', description: 'Save as .tres instead of .res' },
      },
      required: ['path'],
    },
  },
  {
    name: 'instance_scene_as_inherited',
    description: 'Create a New Inherited Scene (.tscn) from imported glTF/PackedScene (human Scene → New Inherited Scene).',
    inputSchema: {
      type: 'object',
      properties: {
        source_path: { type: 'string' },
        path: { type: 'string', description: 'Alias for source_path' },
        save_path: { type: 'string' },
        open: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_scene_from_gltf',
    description: 'Turn imported glTF into inherited or fully editable .tscn.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        save_path: { type: 'string' },
        mode: { type: 'string', description: 'inherited | editable' },
        open: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: ['path'],
    },
  },
  {
    name: 'set_gltf_import_flags',
    description: 'Set glTF/FBX .import flags (animations, lods, tangents, root_type) and reimport.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        import_animations: { type: 'boolean' },
        fps: { type: 'number' },
        ensure_tangents: { type: 'boolean' },
        generate_lods: { type: 'boolean' },
        create_shadow_meshes: { type: 'boolean' },
        root_type: { type: 'string' },
        reimport: { type: 'boolean' },
        extra: { type: 'object' },
      },
      required: ['path'],
    },
  },
  {
    name: 'create_quest_resource',
    description: 'JSON quest with objectives/rewards/next_quests for QuestLog.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        id: { type: 'string' },
        title: { type: 'string' },
        description: { type: 'string' },
        objectives: { type: 'array' },
        rewards: { type: 'object' },
        auto_start: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_quest_log_script',
    description: 'QuestLog autoload: load_quest_file, start_quest, report(type,target), progress signals.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_dialogue_graph_resource',
    description: 'Node-keyed dialogue graph JSON with choices, quest_start, set_flag.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        start: { type: 'string' },
        nodes: { type: 'object' },
        lines: { type: 'array' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'validate_dialogue_graph',
    description: 'Validate dialogue JSON: missing next links, unreachable nodes.',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
  {
    name: 'create_multiplayer_game_manager_script',
    description: 'MultiplayerManager autoload: ENet host/join, roster, start_game RPC scene change.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        port: { type: 'number' },
        max_clients: { type: 'number' },
        game_scene: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'create_multiplayer_lobby_ui',
    description: 'Lobby UI: name/address/port, Host/Join/Start, player list (needs MultiplayerManager).',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        port: { type: 'number' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_multiplayer_player_scene',
    description: 'Networked player .tscn with MultiplayerSynchronizer (position) + authority-only input.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        is_3d: { type: 'boolean' },
        script_path: { type: 'string' },
        speed: { type: 'number' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_multiplayer_spawn_stack',
    description: 'MultiplayerSpawner + spawn markers + host spawn script for player pawns.',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        player_scene: { type: 'string' },
        spawn_point_count: { type: 'number' },
        is_3d: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'list_3d_import_tools',
    description: 'List 3D import-depth tools and recommended pipeline.',
    inputSchema: emptyProps,
  },
  {
    name: 'list_quest_recipes',
    description: 'List quest/dialogue graph recipes.',
    inputSchema: emptyProps,
  },
  {
    name: 'list_multiplayer_recipes',
    description: 'List multiplayer host/join/spawn recipes.',
    inputSchema: emptyProps,
  },
  // ── v1.32 systems ──
  {
    name: 'create_webrtc_multiplayer_template',
    description: 'WebRTC multiplayer peer helper (needs signaling + WebRTC-enabled Godot).',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' }, overwrite: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'create_signaling_server_script',
    description: 'Lightweight WebSocket signaling server for WebRTC offer/answer/ICE relay.',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' }, port: { type: 'number' }, overwrite: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'create_matchmaking_client_script',
    description: 'Matchmaking client: join rooms and relay WebRTC signals.',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' }, overwrite: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'create_input_buffer_netcode_script',
    description: 'Delay-based input-buffer netcode (not full GGPO rollback).',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        input_delay_frames: { type: 'number' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_behavior_tree_on_node',
    description: 'Attach BT runner + example JSON tree to an AI node (selector/sequence/action).',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        tree_path: { type: 'string' },
        name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'create_behavior_tree_resource',
    description: 'JSON behavior tree (selector/sequence/condition/action).',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        name: { type: 'string' },
        tree: { type: 'object' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'export_dialogue_graph_mermaid',
    description: 'Export dialogue JSON graph to Mermaid flowchart for visualization.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        output_path: { type: 'string' },
        write_file: { type: 'boolean' },
      },
      required: ['path'],
    },
  },
  {
    name: 'add_dialogue_graph_node',
    description: 'Add/update a node in a dialogue graph JSON (programmatic graph editor).',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        id: { type: 'string' },
        speaker: { type: 'string' },
        text: { type: 'string' },
        next: { type: 'string' },
        choices: { type: 'array' },
        node: { type: 'object' },
        as_start: { type: 'boolean' },
      },
      required: ['path', 'id'],
    },
  },
  {
    name: 'list_scene_import_options',
    description: 'Dump .import params for glTF/FBX/scene assets (advanced import dock parity).',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
  {
    name: 'set_fbx_import_flags',
    description: 'Set FBX/scene import flags and reimport.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        import_animations: { type: 'boolean' },
        generate_lods: { type: 'boolean' },
        generate_tangents: { type: 'boolean' },
        root_type: { type: 'string' },
        extra: { type: 'object' },
        reimport: { type: 'boolean' },
      },
      required: ['path'],
    },
  },
  {
    name: 'export_and_verify',
    description: 'Run headless export then verify output file exists/size.',
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
    name: 'create_shader_preset',
    description:
      'Write a polished shader preset (flash_white, outline_2d, dissolve, hologram, fresnel_glow, toon_simple…).',
    inputSchema: {
      type: 'object',
      properties: {
        preset: { type: 'string' },
        path: { type: 'string' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'apply_canvas_shader_to_node',
    description: 'Apply canvas_item shader preset to a CanvasItem node.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        preset: { type: 'string' },
        shader_path: { type: 'string' },
        params: { type: 'object' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'setup_screen_fade_overlay',
    description: 'Fullscreen fade overlay with fade_to_black / fade_from_black API.',
    inputSchema: {
      type: 'object',
      properties: { parent_path: { type: 'string' }, layer: { type: 'number' } },
      required: [],
    },
  },
  {
    name: 'create_settings_manager_script',
    description: 'SettingsManager autoload: volume, fullscreen, vsync, locale — user://settings.cfg.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_settings_menu',
    description: 'Settings UI (volume sliders, fullscreen, vsync) bound to SettingsManager.',
    inputSchema: {
      type: 'object',
      properties: { parent_path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'create_enhanced_save_manager_script',
    description: 'Multi-slot SaveManager with metadata + autosave.',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        add_autoload: { type: 'boolean' },
        overwrite: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_save_slot_menu',
    description: 'Save/Load slot UI (3 slots) for SaveManager.',
    inputSchema: {
      type: 'object',
      properties: { parent_path: { type: 'string' } },
      required: [],
    },
  },
  {
    name: 'list_webrtc_recipes',
    description: 'WebRTC, matchmaking, and netcode recipe list.',
    inputSchema: emptyProps,
  },
  {
    name: 'list_behavior_tree_recipes',
    description: 'Behavior tree node types and setup flow.',
    inputSchema: emptyProps,
  },
  {
    name: 'list_shader_presets',
    description: 'Available VFX/shader presets.',
    inputSchema: emptyProps,
  },
  {
    name: 'list_settings_save_recipes',
    description: 'Settings menu + save slot recipes.',
    inputSchema: emptyProps,
  },
  // ── Native run plane (1.33) ──
  {
    name: 'run_ping_runtime',
    description: 'Ping game runtime (TCP preferred). Same as runtime_ping via editor when connected.',
    inputSchema: emptyProps,
  },
  {
    name: 'ensure_runtime_autoloads',
    description:
      'Permanently add MCPGameInspector/Input/Screenshot autoloads so CLI/export runs stay probeable on TCP 6510-6514.',
    inputSchema: {
      type: 'object',
      properties: { permanent: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'run_session_start',
    description:
      'Start native run session: play main|current|custom, wait settle, optional video record. Prefer over bare play_scene for agent loops.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string', description: 'main | current | custom' },
        path: { type: 'string' },
        settle_sec: { type: 'number' },
        record: { type: 'boolean', description: 'Start video frame recording' },
        restart: { type: 'boolean' },
        fps: { type: 'number' },
        track_nodes: { type: 'array' },
      },
      required: [],
    },
  },
  {
    name: 'run_session_stop',
    description: 'Stop play session; optionally stop video record first.',
    inputSchema: {
      type: 'object',
      properties: { stop_record: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'run_session_status',
    description: 'Is game playing? Channel health, video recording, fps, paused.',
    inputSchema: emptyProps,
  },
  {
    name: 'run_record_start',
    description:
      'Start in-engine video capture (PNG sequence + events.jsonl under user://mcp_recordings/).',
    inputSchema: {
      type: 'object',
      properties: {
        session_id: { type: 'string' },
        fps: { type: 'number' },
        half_resolution: { type: 'boolean' },
        max_frames: { type: 'number' },
        track_nodes: { type: 'array', description: '[{node_path, properties}]' },
      },
      required: [],
    },
  },
  {
    name: 'run_record_stop',
    description: 'Stop video capture; optionally encode session.mp4 via FFmpeg.',
    inputSchema: {
      type: 'object',
      properties: { encode: { type: 'boolean' } },
      required: [],
    },
  },
  {
    name: 'run_log_event',
    description: 'Append timed event to run log/video sidecar (markers for clip extraction).',
    inputSchema: {
      type: 'object',
      properties: {
        type: { type: 'string' },
        message: { type: 'string' },
        level: { type: 'string' },
        data: { type: 'object' },
      },
      required: [],
    },
  },
  {
    name: 'run_capture_timeline',
    description:
      'Sample node properties over duration_sec (structured time series; optional images). Deep motion probe without full video.',
    inputSchema: {
      type: 'object',
      properties: {
        duration_sec: { type: 'number' },
        interval_sec: { type: 'number' },
        nodes: { type: 'array', description: '[{node_path, properties:[]}]' },
        node_path: { type: 'string' },
        properties: { type: 'array' },
        include_images: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'run_find_nodes',
    description: 'Find nodes in the RUNNING game by group|type|name|path|script.',
    inputSchema: {
      type: 'object',
      properties: {
        by: { type: 'string' },
        query: { type: 'string' },
        max: { type: 'number' },
      },
      required: ['query'],
    },
  },
  {
    name: 'run_probe_report',
    description:
      'One-shot native probe: play → status/tree/debugger errors/screenshot/asserts/optional record → stop.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: { type: 'string' },
        path: { type: 'string' },
        record: { type: 'boolean' },
        encode: { type: 'boolean' },
        asserts: { type: 'array' },
        stop_after: { type: 'boolean' },
        settle_sec: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'media_find_ffmpeg',
    description: 'Locate system FFmpeg (PATH or FFMPEG_PATH). Required for video encode/clip/keyframes.',
    inputSchema: emptyProps,
  },
  {
    name: 'media_frames_to_video',
    description: 'Encode frame_%05d.png sequence dir to mp4 via FFmpeg.',
    inputSchema: {
      type: 'object',
      properties: {
        frames_dir: { type: 'string' },
        fps: { type: 'number' },
        output_path: { type: 'string' },
      },
      required: ['frames_dir'],
    },
  },
  {
    name: 'media_extract_keyframes',
    description: 'Extract keyframe PNGs from a video for VLM review (FFmpeg).',
    inputSchema: {
      type: 'object',
      properties: {
        video_path: { type: 'string' },
        fps: { type: 'number', description: 'Keyframes per second (default 1)' },
        output_dir: { type: 'string' },
      },
      required: ['video_path'],
    },
  },
  {
    name: 'media_clip_video',
    description: 'Cut a time range from a video (FFmpeg) — e.g. around assert failure.',
    inputSchema: {
      type: 'object',
      properties: {
        video_path: { type: 'string' },
        start_sec: { type: 'number' },
        duration_sec: { type: 'number' },
        end_sec: { type: 'number' },
        output_path: { type: 'string' },
      },
      required: ['video_path'],
    },
  },
  {
    name: 'media_contact_sheet',
    description: 'Build a grid/contact sheet image from video for one multimodal glance.',
    inputSchema: {
      type: 'object',
      properties: {
        video_path: { type: 'string' },
        columns: { type: 'number' },
        rows: { type: 'number' },
        output_path: { type: 'string' },
      },
      required: ['video_path'],
    },
  },
  {
    name: 'detect_test_frameworks',
    description: 'Detect GUT / GdUnit4 installed in the project.',
    inputSchema: emptyProps,
  },
  {
    name: 'run_gut_tests',
    description: 'Run GUT tests headlessly (project must have GUT addon). Does not reimplement GUT.',
    inputSchema: {
      type: 'object',
      properties: {
        test_dir: { type: 'string' },
        prefix: { type: 'string' },
        extra_args: { type: 'array' },
      },
      required: [],
    },
  },
  {
    name: 'run_gdunit_tests',
    description: 'Run GdUnit4 CLI if installed (version-dependent script path).',
    inputSchema: {
      type: 'object',
      properties: {
        script: { type: 'string' },
        extra_args: { type: 'array' },
      },
      required: [],
    },
  },
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
      'Set one node property (full inspector fine-tune). Nested paths: shape.radius, material_override.albedo_color. Enums by name. Types: Vector2/3/4, Color, Transform2D/3D, Quaternion, res://, arrays, bools, numbers.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property: { type: 'string', description: 'Name or nested path e.g. shape.radius' },
        value: {},
      },
      required: ['node_path', 'property', 'value'],
    },
  },
  {
    name: 'update_properties',
    description: 'Batch set many properties on one node (multi-field inspector edit). Paths may be nested.',
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
    name: 'get_property',
    description:
      'Read one property with full metadata (type, enum options, range, can_revert, current value). Prefer before update_property.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        property: { type: 'string', description: 'Name or nested path' },
      },
      required: ['node_path', 'property'],
    },
  },
  {
    name: 'list_property_info',
    description:
      'Full inspector catalog: types, enums, ranges, usage flags, nested resource fields. Use recurse_resources=true to expand sub-resources. filter= substring. property_path= to catalog a resource slot.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        only_editable: { type: 'boolean' },
        include_internal: { type: 'boolean' },
        include_headers: { type: 'boolean', description: 'Include category/group headers' },
        recurse_resources: { type: 'boolean', description: 'Expand Resource sub-properties (shape.*, material.*)' },
        max_depth: { type: 'number' },
        filter: { type: 'string', description: 'Name substring filter' },
        property_path: { type: 'string', description: 'Catalog a nested resource e.g. shape or material_override' },
        max: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'search_properties',
    description: 'Find properties by name substring on a node (recurses resources by default)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        query: { type: 'string' },
        recurse_resources: { type: 'boolean' },
      },
      required: ['node_path', 'query'],
    },
  },
  {
    name: 'reset_property',
    description: 'Revert a property to editor default (inspector Revert) when property_can_revert',
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
    name: 'inspect_node',
    description:
      'Full human-like inspection: properties, signals+connections, groups, script, meta. deep=true adds nested property_info; include_methods=true samples methods.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        deep: { type: 'boolean' },
        include_methods: { type: 'boolean' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'list_node_methods',
    description: 'List callable methods on a scene node (for call_node_method). filter= substring.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        filter: { type: 'string' },
        include_private: { type: 'boolean' },
        max: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'call_node_method',
    description:
      'Call a method on a scene node with args (structured alternative to execute_editor_script). Discover via list_node_methods / describe_class.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        method: { type: 'string' },
        args: { type: 'array', items: {} },
      },
      required: ['node_path', 'method'],
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
    name: 'describe_class',
    description:
      'ClassDB / docs class reference for any engine type: methods, signals, properties, enums, inheritance. Essential for fine-tuning unknown node types.',
    inputSchema: {
      type: 'object',
      properties: {
        class_name: { type: 'string', description: 'e.g. CharacterBody3D, GPUParticles2D' },
        include_inherited: { type: 'boolean' },
      },
      required: ['class_name'],
    },
  },
  {
    name: 'add_resource',
    description:
      'Create and assign a Resource on a node property (e.g. CollisionShape2D.shape = RectangleShape2D). Nested property paths supported. Pass resource_properties to set fields on create.',
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
    name: 'list_animation_fine_tune_tools',
    description: 'List example→target animation transfer tools and recommended agent flow',
    inputSchema: emptyProps,
  },
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
    name: 'dump_animation',
    description:
      'Full dump of a clip (tracks+keys) for agent comparison with an example animation. Prefer before fine-tune.',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        include_keys: { type: 'boolean' },
        max_keys_per_track: { type: 'number' },
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'apply_example_animation',
    description:
      'Copy example clip onto target AnimationPlayer (from open scene player or example_scene_path). Optional path remap + time scale/offset.',
    inputSchema: {
      type: 'object',
      properties: {
        example_scene_path: { type: 'string', description: 'res:// example .tscn with AnimationPlayer' },
        source_node_path: { type: 'string' },
        source_animation: { type: 'string' },
        example_animation: { type: 'string' },
        target_node_path: { type: 'string' },
        target_animation: { type: 'string' },
        from_prefix: { type: 'string' },
        to_prefix: { type: 'string' },
        replacements: { type: 'object' },
        scale: { type: 'number' },
        offset: { type: 'number' },
      },
      required: ['target_node_path'],
    },
  },
  {
    name: 'compare_animations',
    description: 'Diff example vs target: track paths, key counts, length',
    inputSchema: {
      type: 'object',
      properties: {
        source_node_path: { type: 'string' },
        source_animation: { type: 'string' },
        target_node_path: { type: 'string' },
        target_animation: { type: 'string' },
      },
      required: ['source_node_path', 'source_animation', 'target_animation'],
    },
  },
  {
    name: 'copy_animation_to_player',
    description: 'Duplicate a clip from one AnimationPlayer to another (same open scene)',
    inputSchema: {
      type: 'object',
      properties: {
        source_node_path: { type: 'string' },
        source_animation: { type: 'string' },
        target_node_path: { type: 'string' },
        target_animation: { type: 'string' },
        overwrite: { type: 'boolean' },
      },
      required: ['source_node_path', 'source_animation', 'target_node_path'],
    },
  },
  {
    name: 'remap_animation_track_paths',
    description: 'Rewrite track NodePaths after copy (example hierarchy → target hierarchy)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        from_prefix: { type: 'string' },
        to_prefix: { type: 'string' },
        replacements: { type: 'object' },
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'scale_animation_time',
    description: 'Scale key times + length (e.g. scale=0.5 = 2× speed)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        scale: { type: 'number' },
      },
      required: ['node_path', 'animation', 'scale'],
    },
  },
  {
    name: 'sample_animation_at_time',
    description: 'Sample interpolated track values at time t (match example pose)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        time: { type: 'number' },
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'extract_animations_from_scene',
    description: 'Instantiate example .tscn and list AnimationPlayer clips; optional copy into open scene',
    inputSchema: {
      type: 'object',
      properties: {
        scene_path: { type: 'string' },
        copy_to_node_path: { type: 'string' },
        copy_animation: { type: 'string' },
        target_animation: { type: 'string' },
      },
      required: ['scene_path'],
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
    description: 'Insert/update a key on a value/transform track (fine-tune after copying example)',
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
    name: 'bezier_list_keys_cartesian',
    description:
      'List Bezier track keys as Cartesian anchors (x=time,y=value) plus handle endpoints for agent plane mapping',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        track_index: { type: 'number' },
        track_path: { type: 'string' },
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'bezier_set_keys_batch',
    description:
      'Write Bezier keys from plane data: keys=[{x|time,y|value,in_handle,out_handle|in_endpoint,out_endpoint}]',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        track_index: { type: 'number' },
        track_path: { type: 'string' },
        keys: { type: 'array' },
        clear: { type: 'boolean' },
      },
      required: ['node_path', 'animation', 'keys'],
    },
  },
  {
    name: 'bezier_sample_dense',
    description: 'Dense polyline of a Bezier track (shape analysis before fine-tune)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        animation: { type: 'string' },
        track_index: { type: 'number' },
        samples: { type: 'number' },
        start: { type: 'number' },
        end: { type: 'number' },
      },
      required: ['node_path', 'animation'],
    },
  },
  {
    name: 'curve2d_get_points',
    description: 'Curve2D control points + in/out handle world endpoints',
    inputSchema: {
      type: 'object',
      properties: { path: { type: 'string' } },
      required: ['path'],
    },
  },
  {
    name: 'curve2d_set_points',
    description: 'Set Curve2D points from Cartesian position/in/out data',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string' },
        points: { type: 'array' },
      },
      required: ['path', 'points'],
    },
  },
  {
    name: 'path_set_curve_points',
    description: 'Replace Path2D/Path3D curve from Cartesian control points',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        points: { type: 'array' },
      },
      required: ['node_path', 'points'],
    },
  },
  {
    name: 'list_curve_sdk_tools',
    description: 'Inventory of Curve/Bezier/Path MCP tools for full numerical fine-tune',
    inputSchema: emptyProps,
  },
  {
    name: 'setup_humanoid_actor',
    description: 'Humanoid CharacterBody3D stack: capsule, model instance, AnimationPlayer, interaction Area',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        name: { type: 'string' },
        model_scene: { type: 'string' },
        with_interaction_area: { type: 'boolean' },
        interaction_radius: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'validate_humanoid_rig',
    description: 'Check skeleton, animations, bone names for humanoid readiness',
    inputSchema: {
      type: 'object',
      properties: { node_path: { type: 'string' } },
      required: ['node_path'],
    },
  },
  {
    name: 'bind_interaction',
    description: 'Wire Area3D talk/use interaction with prompt + input action',
    inputSchema: {
      type: 'object',
      properties: {
        actor_path: { type: 'string' },
        area_path: { type: 'string' },
        prompt: { type: 'string' },
        action: { type: 'string' },
        kind: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'greybox_room',
    description: 'CSG greybox room (floor + walls) with optional spawn marker',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        width: { type: 'number' },
        depth: { type: 'number' },
        height: { type: 'number' },
        ceiling: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'validate_level_playable',
    description: 'Check spawn/goal markers, navigation region, collision presence',
    inputSchema: {
      type: 'object',
      properties: {
        spawn_name: { type: 'string' },
        goal_name: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'gridmap_set_cell',
    description: 'Set a GridMap cell item (3D tile paint)',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        x: { type: 'number' },
        y: { type: 'number' },
        z: { type: 'number' },
        item: { type: 'number' },
        orientation: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'gridmap_fill_rect',
    description: 'Fill a GridMap axis-aligned region with an item',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        x0: { type: 'number' },
        y0: { type: 'number' },
        z0: { type: 'number' },
        x1: { type: 'number' },
        y1: { type: 'number' },
        z1: { type: 'number' },
        item: { type: 'number' },
      },
      required: ['node_path'],
    },
  },
  {
    name: 'place_prop_scatter',
    description: 'Seeded scatter of scene instances or box meshes in a region',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        scene_path: { type: 'string' },
        count: { type: 'number' },
        seed: { type: 'number' },
        min_x: { type: 'number' },
        max_x: { type: 'number' },
        min_z: { type: 'number' },
        max_z: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'create_heightmap_terrain',
    description: 'Build heightfield MeshInstance3D terrain from noise or heights array (+ optional collision)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        resolution_x: { type: 'number' },
        resolution_z: { type: 'number' },
        size_x: { type: 'number' },
        size_z: { type: 'number' },
        height_scale: { type: 'number' },
        seed: { type: 'number' },
        with_collision: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'stream_load_chunk',
    description: 'Instance a level chunk PackedScene under Chunks/ for large-world streaming',
    inputSchema: {
      type: 'object',
      properties: {
        scene_path: { type: 'string' },
        id: { type: 'string' },
        parent_path: { type: 'string' },
        position: { type: 'object' },
      },
      required: ['scene_path'],
    },
  },
  {
    name: 'create_music_controller_script',
    description: 'Interactive BGM controller with crossfade states (explore/combat/…)',
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
    name: 'play_main_scene',
    description: 'Play project main scene (Editor Play button)',
    inputSchema: emptyProps,
  },
  {
    name: 'play_current_scene',
    description: 'Play currently edited scene',
    inputSchema: emptyProps,
  },
  {
    name: 'get_editor_workspace_info',
    description: 'Open scenes, play state, main scene path',
    inputSchema: emptyProps,
  },
  {
    name: 'list_resources_by_type',
    description: 'Browse res:// by extension or resource class (FileSystem filter)',
    inputSchema: {
      type: 'object',
      properties: {
        extension: { type: 'string' },
        type: { type: 'string' },
        path: { type: 'string' },
        max: { type: 'number' },
      },
      required: [],
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
  // ── 1.28 ──
  {
    name: 'setup_line_edit',
    description: 'Create LineEdit (text field)',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        text: { type: 'string' },
        placeholder: { type: 'string' },
      },
      required: [],
    },
  },
  {
    name: 'setup_check_box',
    description: 'Create CheckBox control',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        text: { type: 'string' },
        pressed: { type: 'boolean' },
      },
      required: [],
    },
  },
  {
    name: 'setup_audio_stream_player_2d',
    description: 'Add AudioStreamPlayer2D with optional stream and polyphony',
    inputSchema: {
      type: 'object',
      properties: {
        parent_path: { type: 'string' },
        stream_path: { type: 'string' },
        max_polyphony: { type: 'number' },
        volume_db: { type: 'number' },
      },
      required: [],
    },
  },
  {
    name: 'set_layer_names',
    description: 'Name physics/render/navigation layers (kind + names map)',
    inputSchema: {
      type: 'object',
      properties: {
        kind: { type: 'string', description: '2d_physics|3d_physics|2d_render|3d_render|…' },
        names: { type: 'object' },
      },
      required: ['kind', 'names'],
    },
  },
  {
    name: 'set_control_tooltip',
    description: 'Set Control.tooltip_text',
    inputSchema: {
      type: 'object',
      properties: {
        node_path: { type: 'string' },
        tooltip: { type: 'string' },
      },
      required: ['node_path'],
    },
  },
];

/** Tools that should prefer the live editor plugin when connected */

