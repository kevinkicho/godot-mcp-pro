# Command modules layout (v1.64+ refactor)

Command modules are **auto-discovered recursively** as `**/*_commands.gd`.

```
commands/
  base_command.gd          # shared base (not a module)
  agent/                   # agent, discovery, pipelines, surface closure
  animation/               # AnimationPlayer/Tree, skeleton, retarget
  audio/
  assets/                  # import, resources, materials, textures
  2d/                      # tiles, pixel, mesh2d, lights2d, …
  3d/                      # scene3d, GI, LOD, vehicles, …
  core/                    # scene/node/editor/project/input/…
  export/                  # export, CI, Android/iOS, plugins, GDExtension
  navigation/
  network/                 # multiplayer, WebRTC, HTTP
  physics/
  qa_runtime/              # playtest, debugger, profiling, media
  shaders_vfx/
  ui_gameplay/             # UI, theme, dialogue, quests, inventory, saves
  xr/
```

## Rules

1. File name: `*_commands.gd` with `get_commands() -> Dictionary`.
2. Extend `res://addons/godot_mcp/commands/base_command.gd`.
3. Prefer `parse_vec2` / `parse_color` / `save_resource_to_res` / `list_tools_payload` on base.
4. Shared pure helpers: `utils/mcp_params.gd`.
5. Re-bucket: `.\scripts\organize-command-modules.ps1`
6. Registry: `.\scripts\export-surface-registry.ps1`

## Discovery

- `list_command_domains` — filesystem domains  
- `list_command_modules domain=animation`  
- `list_agent_domains` — agent workflow domains (orthogonal map)  
