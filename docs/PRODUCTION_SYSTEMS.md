# Production systems

Higher-level scaffolds for **modern game production** — characters, AI, UI, quests, multiplayer, VFX, settings.  
These generate scripts/scenes under `res://` and optionally register autoloads. Prefer them over hand-writing the same boilerplate each project.

## Character & movement

Module: `character_system_commands`

| Tool (examples) | Purpose |
|-----------------|---------|
| Character controller scaffolds | 2D/3D player templates with movement hooks |
| State / interaction helpers | Interactable patterns, common player scripts |

Use with `create_input_map_preset` and physics setup tools for a playable baseline.

## AI

Module: `ai_system_commands`

| Tool | Purpose |
|------|---------|
| `setup_ai_agent_2d` / `setup_ai_agent_3d` | Agent node scaffolding |
| `create_chase_ai_script` / `create_patrol_ai_script` | Common AI behaviors |
| `setup_detection_area` | Detection / aggro volumes |
| `create_gameplay_state_machine_script` | Gameplay FSM (not AnimationTree) |
| `create_interactable_script` | Interact targets |
| `list_ai_templates` | Enumerate available AI templates |

## Behavior trees

Module: `behavior_tree_commands`

Scaffolds BT-style scripts and tree resources for more structured AI than simple chase/patrol.

## Game UI

Module: `game_ui_system_commands`

HUD / menu scaffolds: health bars, pause menus, dialogue shells, progress UI — as scripts + scenes agents can wire into gameplay.

## Quests & dialogue

| Module | Focus |
|--------|--------|
| `quest_system_commands` | Quest definitions, progress, reward hooks |
| `dialogue_commands` | Dialogue resources / runners |

## Multiplayer

| Module | Focus |
|--------|--------|
| `multiplayer_commands` | Editor-side multiplayer project setup |
| `multiplayer_runtime_commands` | Runtime sync helpers / spawn patterns |
| `webrtc_multiplayer_commands` | WebRTC peer scaffolding |

Always test with multiple instances or headless peers; use [RUNTIME_PROBE.md](RUNTIME_PROBE.md) for live asserts.

## Settings & save

Module: `settings_save_commands`

- Game settings resources  
- Save/load managers (often paired with `gameplay_template` SaveManager / EventBus)

## VFX & modern rendering

| Module | Focus |
|--------|--------|
| `vfx_shader_commands` | Effect shaders / VFX scripts |
| `modern_render_commands` | Rendering features / environment helpers |
| `shader_commands` / `visual_shader_commands` | Shader authoring |
| `particle_commands` | GPUParticles 2D/3D |

## Import (2D / 3D)

| Module | Focus |
|--------|--------|
| `import_commands` | Import dock parity, wait, reimport |
| `import_3d_commands` | GLTF/GLB-oriented workflows |

After staging files: `scan_filesystem` → `wait_for_import` / `ensure_imported`.

## Gameplay templates

Module: `gameplay_template_commands`

Reusable patterns: **SaveManager**, **EventBus**, object pools, camera shake, scene flow helpers.

## Plugin scaffolding

Module: `plugin_scaffold_commands`

Generate a minimal `addons/<name>/` editor plugin (cfg + plugin.gd + optional dock).

## Recommended composition

```
scaffold_project_defaults
  → create_input_map_preset
  → character + camera + collision
  → AI or quest systems as needed
  → game UI + settings/save
  → playtest_report / run_session + screenshots/video
```

## Related

- [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md)  
- [COMMAND_SURFACE.md](COMMAND_SURFACE.md)  
- [../SURFACE_REGISTRY.md](../SURFACE_REGISTRY.md) for exact tool names  
