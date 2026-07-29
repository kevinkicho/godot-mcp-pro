# MCP ↔ Godot SDK / docs coverage analysis

**As of:** plugin **v1.38.0** · **692** registered commands · **68** modules  
**Sources:** [godotengine/godot-docs](https://github.com/godotengine/godot-docs) (`tutorials/*`, `getting_started/*`, class reference) · live map in `list_docs_coverage` · [SURFACE_REGISTRY.md](../SURFACE_REGISTRY.md)

---

## Table of contents

1. [What “coverage” means](#1-what-coverage-means)
2. [Scorecard (honest)](#2-scorecard-honest)
3. [Official tutorials folder → MCP](#3-official-tutorials-folder--mcp)
4. [Beyond tutorials (agent production surfaces)](#4-beyond-tutorials-agent-production-surfaces)
5. [Class reference / ClassDB](#5-class-reference--classdb)
6. [Three layers of mapping](#6-three-layers-of-mapping)
7. [Module ↔ docs crosswalk](#7-module--docs-crosswalk)
8. [Gaps that still matter](#8-gaps-that-still-matter)
9. [Discovery vs capability](#9-discovery-vs-capability)
10. [How to refresh this analysis](#10-how-to-refresh-this-analysis)

---

## 1. What “coverage” means

| Claim | Meaning | Our stance |
|-------|---------|------------|
| **Docs-area coverage** | Each official `tutorials/<topic>` folder has *workflow tools* so an agent can do the human tutorial path | **Primary metric** — see heatmap below |
| **ClassDB coverage** | One tool per engine method/property/signal | **Not a goal** — use `describe_class` + scripts |
| **Editor dock pixel parity** | Every button in every dock | **Not a goal** — Escape hatches: `execute_editor_script`, `call_editor` |
| **Agent discoverability** | Tools listed in MCP client by default | **Separate** from plugin capability |

Older messaging that said “100% docs surface” only meant “every top-level tutorial folder has *some* tool path,” often ClassDB-only. That metric is **retired**. Use statuses:

| Status | Weight | Meaning |
|--------|--------|---------|
| **strong** | 1.0 | End-to-end workflow tools |
| **partial** | 0.55 | Some tools; missing steps or depth |
| **thin** | 0.25 | Barely agent-operable |
| **classdb_only** | 0.35 | Lookup / scripts only; intentional for math |

Live tool: **`list_docs_coverage`** (plugin) returns the same map + `honest_depth_score_percent`.

---

## 2. Scorecard (honest)

Computed from the v1.38 `list_docs_coverage` area table (34 areas, including gameplay extras):

| Status | Count | Share of areas |
|--------|------:|---------------:|
| strong | 26 | 76% |
| partial | 6 | 18% |
| thin | 1 | 3% |
| classdb_only | 1 | 3% |

**Weighted depth score ≈ 88%**  
Formula: `(strong×1 + partial×0.55 + thin×0.25 + classdb_only×0.35) / area_count`.

### Interpretation

| Layer | Rough human-tutorial depth | Notes |
|-------|---------------------------|--------|
| Scene / node / inspector / signals / GDScript | **~90%** | Core production path |
| Assets import pipeline | **~85%** | stage / wait / `.import` / glTF extract |
| 2D + TileMap + TileSet | **~80%** | Thin on atlas GUI polish |
| 3D content + GI/probes | **~75–80%** | UV2 / LOD / full lightmap still thin |
| Animation + Skeleton | **~80%** | No visual Bezier / full retarget wizard |
| Physics | **~75%** | Joints/soft/vehicle present; viz thin |
| Networking (ENet + templates) | **~70–75%** | WebRTC partial; no commercial relay |
| XR | **~70%** | OpenXR action map tools; passthrough thin |
| Rendering advanced | **~55%** | Environment/lights/GI partial |
| Platform (iOS / console) | **~40%** | Android + export presets strongest |
| Migrating 3→4 | **~25%** | Version + search/edit only |
| Math tutorials | **N/A (classdb)** | Intentional |

**Not included in “88%”:** full ClassDB method count (~thousands of APIs). Workflow depth ≠ SDK completeness.

---

## 3. Official tutorials folder → MCP

Official index: [tutorials/](https://github.com/godotengine/godot-docs/tree/master/tutorials) (plus [getting_started](https://github.com/godotengine/godot-docs/tree/master/getting_started)).

| Godot docs area | Status | Primary MCP modules | Example tools | Remaining gaps |
|-----------------|--------|---------------------|---------------|----------------|
| **getting_started** | strong | production, agent, scene, script | `scaffold_project_defaults`, `playtest_report`, `create_scene` | — |
| **tutorials/editor** | strong | editor, debugger, node | `inspect_node`, `list_property_info`, `debugger_*`, breakpoints | Full call-stack vars; gutter list engine-limited |
| **tutorials/scripting** | strong | script, class, csharp, scene_unique | `create/edit/validate_script`, `describe_class`, C# helpers | C++ IDE debug; VisualScript N/A |
| **tutorials/2d** | strong | scene_2d, tilemap, tileset, character, material_2d | controllers, Camera2D, parallax, lights, tile paint, TileSet | Advanced atlas region GUI |
| **tutorials/3d** | strong | scene_3d, skeleton, character, import_3d, modern_render | FPS/TPS, probes, VoxelGI, CSG, BoneMap | Auto LOD; full lightmap UV2 unwrap |
| **tutorials/animation** | strong | animation, animation_tree, skeleton | tracks/keys, Tree travel, blend spaces, SpriteFrames | Visual Bezier handles; retarget wizard UI |
| **tutorials/assets_pipeline** | strong | import, import_3d, texture, filesystem | `ensure_imported`, import options, glTF extract, atlas/noise tex | Per-importer full schemas; FBX dialog parity |
| **tutorials/audio** | strong | audio | buses, effects, layout save/load, AudioManager scaffold | Interactive music graphs; generators |
| **tutorials/inputs** | strong | input, input_map | presets, list events, simulate_* | Joypad mapping wizard; strength tooling |
| **tutorials/io** | **partial** | io, settings_save, gameplay_template | res_*, ConfigFile/JSON, user://, save managers | Encrypted save helpers; HTTP as first-class IO |
| **tutorials/i18n** | strong | i18n | locale, CSV/PO load, translate | Auto-extract strings from scenes |
| **tutorials/navigation** | strong | navigation, ai_system | region/agent/bake/link/obstacle + AI chase/patrol | Path debug overlay; raw NavigationServer queries |
| **tutorials/networking** | strong | multiplayer, multiplayer_runtime | lobby, spawner/synchronizer, RPC, WebSocket template | Matchmaking/relay services; rollback netcode |
| **tutorials/performance** | strong | profiling, analysis, debugger, test | monitors, timelines, stress, scene complexity | GPU frame debugger export; CPU flame charts |
| **tutorials/physics** | strong | physics, character | body/collision/area/joint/ray/shape cast, soft, vehicle, physical bone | Joint limit UI; test_move viz; auto-ragdoll |
| **tutorials/export** | strong | export, android | create/run presets, filters, Android deploy | Signing/notarization wizards |
| **tutorials/platform** | **partial** | android, export | Android devices/deploy, Web/iOS presets | Consoles; full iOS Xcode pipeline |
| **tutorials/plugins** | **partial** | plugin_scaffold, gdextension | `create_editor_plugin`, GDExtension scaffold | Marketplace packaging; godot-cpp auto-build |
| **tutorials/rendering** | **partial** | scene_3d, modern_render, material | env, lights, probes, decals, VoxelGI, layers | SDFGI controls; compositor effects; lightmap bake automation |
| **tutorials/shaders** | strong | shader, visual_shader, vfx_shader | create/edit/globals, VisualShader nodes, VFX presets | Full VS node catalog; shader includes |
| **tutorials/ui** | strong | theme, ui_list, control_extra, container, game_ui | anchors, theme, ItemList/Tree, dialogs, HUD scaffolds | Full Theme type resource editor |
| **tutorials/xr** | strong | xr | XROrigin, controllers, OpenXR action map/bindings | Passthrough; composition layers |
| **tutorials/math** | classdb_only | (any) | `update_property`, `execute_editor_script` | Intentional — not a dock |
| **tutorials/best_practices** | **partial** | agent, analysis | `agent_workflow_guide`, `analyze_*`, `health_check` | Style guides as executable checks |
| **tutorials/migrating** | **thin** | compat, script | `get_godot_version`, search/edit | Automated 3→4 migrator |

Official folders with **no dedicated MCP area name** but still covered:

| Docs | Covered via |
|------|-------------|
| `tutorials/img` | N/A (images only) |
| Troubleshooting | `get_editor_errors`, debugger, `health_check`, playtest |

---

## 4. Beyond tutorials (agent production surfaces)

These are **not** top-level Godot tutorial folders but matter for modern agent production (mapped in `list_docs_coverage`):

| Extra surface | Status | Modules | Docs affinity |
|---------------|--------|---------|---------------|
| **gameplay_systems** | strong | character, ai, game_ui, gameplay_template | 2d/3d + scripting recipes |
| **narrative_quests** | strong | quest, dialogue | — (game design layer) |
| **ai_behavior_trees** | strong | behavior_tree, ai_system | scripting / AI patterns |
| **networking_webrtc** | partial | webrtc_multiplayer | networking (WebRTC chapter) |
| **shaders_vfx** | strong | vfx_shader, particle, shader | shaders + particles |
| **settings_save_menus** | strong | settings_save, gameplay_template | io + ui |
| **export_pipeline** | strong | export | export (overlap with tutorials/export) |
| **runtime_probe** | strong | run_session, runtime, media, test_framework | editor play + testing (human Play button) |

Runtime probe is the **playtest plane** (TCP 6510–6514 + FFmpeg + GUT/GdUnit). See [RUNTIME_PROBE.md](RUNTIME_PROBE.md).

---

## 5. Class reference / ClassDB

| Docs | Status | Tools |
|------|--------|-------|
| **classes/** (entire class reference) | **strong (lookup)** | `describe_class`, `list_classes`, `list_class_methods/signals/properties/constants`, `get_class_inheritance` |

**Honest note:** This is **lookup of any ClassDB type**, not a dedicated tool per method of every class.  
Missing vs docs site: offline RST text and official example snippets.

Escape hatches for long-tail APIs:

- `execute_editor_script` / `execute_game_script`
- `call_editor` (lite mode)
- `update_property` with type parsing

---

## 6. Three layers of mapping

```
┌─────────────────────────────────────────────────────────┐
│  Layer A — Human tutorial workflows (docs folders)      │
│  Mapped by list_docs_coverage · ~88% weighted depth     │
├─────────────────────────────────────────────────────────┤
│  Layer B — Editor + run control plane                   │
│  692 commands · 68 modules · SURFACE_REGISTRY.md        │
├─────────────────────────────────────────────────────────┤
│  Layer C — Engine ClassDB (~thousands of APIs)          │
│  describe_class + scripts · intentionally not 1:1 tools │
└─────────────────────────────────────────────────────────┘
```

Agents should:

1. Prefer **Layer A/B workflow tools** for production loops  
2. Use **Layer C** when a specific class/method is unknown  
3. Never assume MCP tools = full SDK  

---

## 7. Module ↔ docs crosswalk

| Plugin module | ~Cmds | Docs / surfaces |
|---------------|------:|-----------------|
| agent_commands | 4 | getting_started, best_practices |
| production_commands | 5 | getting_started, editor |
| project_commands | 16 | getting_started, project settings |
| filesystem_commands | 8 | assets_pipeline, editor |
| scene_commands / scene_2d / scene_3d / scene_flow / scene_unique | 10+17+23+4+4 | scenes, 2d, 3d |
| node_commands | 28 | editor, scripting |
| script_commands / class_commands / csharp_commands | 7+17+13 | scripting |
| editor_commands / debugger_commands | 13+11 | editor, performance |
| input_commands / input_map_commands | 5+6 | inputs |
| import_commands / import_3d / texture | 15+11+4 | assets_pipeline |
| animation / animation_tree / skeleton | 33+20+19 | animation, 3d |
| physics_commands | 18 | physics |
| navigation_commands | 8 | navigation |
| audio_commands | 15 | audio |
| theme / ui_list / control_extra / container | 10+15+15+8 | ui |
| shader / visual_shader / vfx_shader / particle | 9+7+10+11 | shaders, rendering |
| multiplayer / multiplayer_runtime / webrtc | 10+6+6 | networking |
| export / android | 13+3 | export, platform |
| xr_commands | 15 | xr |
| i18n_commands | 9 | i18n |
| io_commands | 8 | io |
| profiling / analysis / test / test_framework | 6+6+5+4 | performance, best practices |
| runtime / run_session / media | 19+15+6 | playtest (editor) |
| character / ai / behavior_tree / game_ui / quest / dialogue / settings_save / gameplay_template | many | production recipes |
| plugin_scaffold / gdextension | 2+4 | plugins |
| modern_render / material_2d | 6+12 | rendering, 2d |
| tilemap / tileset | 13+11 | 2d |
| compat_commands | 8 | coding-solo parity, version |
| resource / batch / tween / utility / dialogue… | various | cross-cutting |

Full names: [SURFACE_REGISTRY.md](../SURFACE_REGISTRY.md).

---

## 8. Gaps that still matter

### High impact for agents

| Gap | Docs area | Why it hurts |
|-----|-----------|--------------|
| Full lightmap / SDFGI / compositor automation | rendering | Shipping 3D look needs bake wizards |
| Joypad mapping wizard | inputs | Console/controller games |
| Auto string extraction for i18n | i18n | Localization pipelines |
| Encrypted / cloud save backends | io | Shipping save systems |
| Commercial WebRTC TURN / matchmaking | networking | Multiplayer scale-out |
| Visual Bezier + full retarget UI | animation | Cinematic polish |
| Theme type full editor | ui | Large UI skins |
| godot-cpp clone/build automation | plugins | Native extensions |
| Automated 3→4 migrator | migrating | Porting projects |
| GPU profiler / flame charts | performance | Deep perf work |

### Intentional non-goals

- Full ClassDB as individual MCP tools  
- Full VisualShader node-for-node GUI  
- Full Animation editor GUI  
- Console vendor SDKs  
- Replacing the official docs browser  

### Stale claims fixed in this analysis

| Old (v1.20 gap doc) | Now (v1.38) |
|---------------------|-------------|
| ~354 commands | **692** |
| Networking weak | **strong** (templates + runtime + partial WebRTC) |
| Import weak | **strong** |
| XR weak | **strong** (OpenXR action map) |
| Runtime “file IPC only” | **TCP primary** + file fallback |
| No quest/BT | **quest + dialogue + behavior_tree modules** |

---

## 9. Discovery vs capability

| Plane | Reality |
|-------|---------|
| Plugin register | 692 methods via `command_router` auto-discovery |
| MCP full mode | Large tool list (client-dependent limits) |
| MCP lite | Core tools + **`call_editor`** for the rest |
| Agent discovery | Prefer `health_check` → `list_mcp_commands` / `list_docs_coverage` / `agent_workflow_guide` |

**Capability exists ≠ agent sees it.** Always measure both.

Schemas: many advanced tools are free-form through the bridge; production macros + lite schemas improve discoverability for the top loop.

---

## 10. How to refresh this analysis

```powershell
# 1. Regenerate command inventory
.\scripts\export-surface-registry.ps1

# 2. In a connected Godot project, call MCP tool:
#    list_docs_coverage
#    → status_counts + honest_depth_score_percent + areas.*.gaps

# 3. Diff official folders:
#    https://github.com/godotengine/godot-docs/tree/master/tutorials
```

Update this file when:

- A tutorial folder’s status changes (e.g. rendering → strong)  
- Major modules land or retire  
- Plugin version bumps in a release that changes surface  

Also keep in sync:

- Live map: `addons/godot_mcp/commands/agent_commands.gd` → `_list_docs_coverage`  
- Root summary: [GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md)  
- Short honesty note: [DOCS_SURFACE_100.md](../DOCS_SURFACE_100.md)  

---

## Related docs

- [COMMAND_SURFACE.md](COMMAND_SURFACE.md)  
- [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md)  
- [ARCHITECTURE.md](ARCHITECTURE.md)  
- [RUNTIME_PROBE.md](RUNTIME_PROBE.md)  
- [PRODUCTION_SYSTEMS.md](PRODUCTION_SYSTEMS.md)  
