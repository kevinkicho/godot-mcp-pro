# Command modules layout (v1.65+)

Command modules are **auto-discovered recursively** as `**/*_commands.gd`.

Prefer **~5–22 modules per domain** so folders stay manageable.

```
commands/
  base_command.gd     # shared base (not a module)
  agent/              # discovery, pipelines, surface closure
  ai/                 # utility AI, BT, AI agents
  animation/          # AnimationPlayer/Tree, skeleton, retarget
  audio/
  assets/             # import, resources, materials, textures
  rendering/          # GI, LOD, lightmap, environment, compositor
  2d/                 # tiles, pixel, mesh2d, scene_2d, sprite frames
  3d/                 # scene3d, CSG, vehicles, terrain, multimesh
  scene/              # scene graph, pack, flow, camera, node_*
  editor/             # editor docks, workspace, focus
  project/            # project settings, display, groups, autoload
  input/              # input map, joypad, record
  scripting/          # scripts, ClassDB, C#, curves, migration, IO
  physics/
  navigation/
  network/
  export/
  qa_runtime/
  shaders_vfx/
  ui_gameplay/
  xr/
```

## Rules

1. Name: `*_commands.gd` with `get_commands() -> Dictionary`.
2. Extend `res://addons/godot_mcp/commands/base_command.gd`.
3. Prefer base helpers: `parse_vec2`, `parse_color`, `list_tools_payload`, `save_resource_to_res`.
4. Shared pure parsers: `utils/mcp_params.gd`.
5. Rebalance: `.\scripts\organize-command-modules.ps1`
6. Registry: `.\scripts\export-surface-registry.ps1`

## Merge policy

- Prefer one module per cohesive feature surface.
- Merge thin `*_depth` siblings when they only add a few commands to the parent.
- Avoid mega-files (>800 lines); split by concern instead.

## Discovery

- `list_command_domains` / `list_command_modules domain=scene`
- `list_agent_domains` (workflow map; orthogonal to filesystem domains)
