# Command surface

The plugin registers **hundreds of commands** (see generated totals in [SURFACE_REGISTRY.md](../SURFACE_REGISTRY.md)).  
MCP clients may expose a **subset** as tools (full / lite / minimal). When connected, the full plugin surface is reachable via WebSocket and, in lite mode, via **`call_editor`**.

## Honesty

This tracks **workflow / agent production** growth — not 100% of ClassDB or every editor control.

| Resource | Purpose |
|----------|---------|
| [../SURFACE_REGISTRY.md](../SURFACE_REGISTRY.md) | Full generated command list by module |
| `list_mcp_commands` | Live enumeration (optional `surface` filter) |
| `list_surface_registry` / `list_docs_coverage` | In-editor coverage reports |
| [../GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md) | Gaps vs official docs |
| [../DOCS_SURFACE_100.md](../DOCS_SURFACE_100.md) | Docs-area → tools map |

Regenerate registry after command changes:

```powershell
.\scripts\export-surface-registry.ps1
```

## Category map (modules)

| Area | Modules (examples) | Typical tools |
|------|--------------------|---------------|
| **Agent / health** | `agent_commands` | `health_check`, `agent_workflow_guide`, `list_docs_coverage` |
| **Project / FS** | `project_commands`, `filesystem_commands`, `import_commands` | settings, tree, search, import wait |
| **Scene / nodes** | `scene_*`, `node_commands` | create/open/save, CRUD, signals, groups |
| **Scripts** | `script_commands`, `class_commands` | read/edit/validate, ClassDB |
| **Editor** | `editor_commands`, `debugger_commands` | screenshots, errors, execute script |
| **Input** | `input_commands`, `input_map_commands` | simulate key/mouse/action, Input Map |
| **Runtime / run session** | `runtime_commands`, `run_session_commands` | game tree, frames, video, timeline |
| **2D / 3D** | `scene_2d`, `scene_3d`, `physics`, `navigation` | meshes, lights, collision, nav bake |
| **Animation** | `animation_*`, `skeleton_commands` | clips, AnimationTree, bones |
| **UI / theme** | `theme_commands`, `ui_list_commands`, `game_ui_system` | themes, lists, HUD scaffolds |
| **Audio / particles / VFX** | `audio`, `particle`, `vfx_shader`, `shader` | buses, GPUParticles, shaders |
| **Multiplayer** | `multiplayer_*`, `webrtc_multiplayer` | ENet/WebRTC scaffolds |
| **Gameplay systems** | `character_system`, `ai_system`, `quest_system`, `behavior_tree`, `dialogue` | templates + scripts |
| **Production** | `production_commands`, `gameplay_template`, `settings_save` | scaffold, SaveManager, EventBus |
| **Media / tests** | `media_commands`, `test_*`, `test_framework` | FFmpeg, GUT/GdUnit |
| **Export / Android / XR** | `export_commands`, `android_commands`, `xr_commands` | presets, deploy, XR nodes |
| **Compat / coding-solo** | `compat_commands` | version, UID, launch_editor, list_mcp_commands |

Exact counts change with each release — always trust **SURFACE_REGISTRY** or `list_mcp_commands`.

## Discovery flow for agents

```
health_check
  → list_mcp_commands (or list_surface_registry)
  → agent_workflow_guide(topic=…)
  → call tools / call_editor(method, params)
```

## Adding tools

See [CONTRIBUTING.md](CONTRIBUTING.md) and [ARCHITECTURE.md](ARCHITECTURE.md).
