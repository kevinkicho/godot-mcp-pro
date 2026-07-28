# Godot MCP vs Official Docs — Gap Analysis

Source map: [godotengine/godot-docs](https://github.com/godotengine/godot-docs) (`tutorials/`, `getting_started/`, class reference intent).  
Compared against this fork’s plugin command surface (~**354** registered methods, **v1.20.0**).

**Goal:** agent-driven game production that feels like a human using the editor — not 1:1 with every docs page.

**Honesty:** Older notes/tools claimed “100% docs surface.” That meant “every top-level tutorial folder has *some* tool path,” including ClassDB-only escapes — **not** full SDK or human-dock parity. Use `list_docs_coverage` (honest statuses + `gaps`) and `DOCS_SURFACE_100.md`.

---

## How to read this

| Coverage | Meaning |
|----------|---------|
| **Strong** | Dedicated tools; agents can do the workflow end-to-end |
| **Partial** | Some tools; missing steps, discovery, or depth |
| **Weak / missing** | Docs-area workflow not really agent-operable |
| **Out of scope** | Better as engine/user responsibility, not MCP |

**Also important:** Many plugin tools only appear after `list_mcp_commands` / full mode / `call_editor`. Grok’s default list is intentionally thinner (lite + schemas). **Capability exists ≠ agents discover it.**

---

## Summary heatmap (docs topic → MCP)

| Docs area ([tutorials/](https://github.com/godotengine/godot-docs/tree/master/tutorials)) | Coverage | Notes |
|------------|----------|--------|
| Editor (scene tree, inspector, selection) | **Strong** (1.17.1) | `inspect_node`, `list_property_info`, `update_propert(y\|ies)`, signals, meta |
| Scripting (GDScript edit/attach/validate) | **Strong** | create/edit/read/attach/validate; weak on C#, GDExtension |
| Scenes / instancing | **Strong** | create/open/save/instance/play/stop |
| Project settings / autoload | **Strong** | get/set settings, add/remove autoload |
| Input Map | **Partial** | set/get actions; no full event list UX, no joypad wizard |
| 2D | **Partial** | nodes + tilemap + sprites; no tile-set authoring, no light occluders tooling |
| 3D | **Partial** | mesh primitives, lights, camera, env, gridmap, materials; no glTF import prefs, skeleton, CSG deep tools |
| Animation | **Strong** (1.19) | Player tracks/keys/libraries/RESET/playback; Tree travel/blend spaces; Skeleton inspect/pose; thin on visual Bezier curve UI + BoneMap retarget wizard |
| Physics | **Partial** | body/collision/layers/raycast; no joints, areas helpers, soft body, vehicle |
| Navigation | **Partial** | region/agent/bake; no 2D nav polish, no path debug draw |
| Audio | **Partial** | buses/players/effects; no audio bus layout save as resource, no interactive music |
| Shaders | **Partial** | create/edit/assign/params; no visual shader, no shader globals UI |
| UI / Theme | **Partial** | anchors, theme overrides; no Control focus neighbors, no container size flags depth |
| Particles | **Partial** | create/material/presets; no sub-emitters, trails depth |
| Export | **Partial** | list presets, get export *command*; no full automated export run everywhere |
| Performance / profiling | **Partial** | monitors; no profiler UI, no debugger breakpoints |
| Assets pipeline / import | **Weak** | reimport, `.import` edit, texture compress modes, 3D import dialog |
| Networking | **Weak** | multiplayer spawner, ENet/WebRTC setup |
| I18n | **Weak** | CSV/PO import, locale switch tooling |
| IO / save games | **Weak** | FileAccess/ConfigFile helpers beyond generic scripts |
| XR | **Weak / out of scope** for most agents |
| Plugins / editor plugins authoring | **Weak** | we *are* a plugin; not a plugin factory |
| Math / low-level | **Out of scope** | scripts cover this |
| Platform (iOS/Web/console) | **Weak** except Android deploy basics |

---

## 1. Strong (aligned with docs “human basics”)

These map well to [getting_started](https://github.com/godotengine/godot-docs/tree/master/getting_started) + core editor docs:

| Human docs workflow | MCP tools |
|---------------------|-----------|
| Open project / run | `launch_editor`, `play_scene`, `run_project`, `stop_scene` |
| Scene tree | `get_scene_tree`, `add_node`, `delete_node`, `move_node`, `rename_node`, `duplicate_node`, `select_nodes` |
| Inspector | `inspect_node`, `list_property_info`, `get_node_properties`, `update_property`, `update_properties`, `clear_property` |
| Resources on nodes | `add_resource`, `remove_resource`, `read/edit/create_resource` |
| Signals | `connect_signal`, `disconnect_signal`, `get_signals`, `find_signal_connections`, `analyze_signal_flow` |
| Scripts | `create_script`, `edit_script`, `read_script`, `attach_script`, `validate_script` |
| Groups | `set_node_groups`, `get_node_groups`, `find_nodes_in_group` |
| Autoloads | `add_autoload`, `remove_autoload` |
| Project Settings | `get_project_settings`, `set_project_setting` |
| Playtest / debug | screenshots, `get_editor_errors`, `simulate_*`, runtime tree/properties |

This is enough for a large fraction of **agent-driven content production**.

---

## 2. Partial — high value gaps for agents

### A. Assets pipeline ([tutorials/assets_pipeline](https://github.com/godotengine/godot-docs/tree/master/tutorials/assets_pipeline))

Docs emphasize: drop files → import → configure `.import` → reimport.

| Missing MCP capability | Why agents need it |
|------------------------|--------------------|
| **Read/write `.import` options** | Texture compression, mipmaps, 3D import flags |
| **`reimport_files` / wait for import** | After copying assets into `res://` |
| **Import progress / filesystem dock refresh guarantee** | We have `reload_project` / scan; not “wait until imported” |
| **Create ImageTexture / AtlasTexture helpers** | Common 2D pipeline |
| **Import scene as inherited / extract meshes** | 3D production |

**Workaround today:** copy files into project + `reload_project`; edit scripts/scenes that reference `res://` paths.

### B. Animation ([tutorials/animation](https://github.com/godotengine/godot-docs/tree/master/tutorials/animation))

| Have (1.19 human surface) | Still thin |
|------|---------|
| Clips, libraries, RESET, all track types, method/audio/playback keys | Visual Bezier handle editor |
| Play/seek/queue/autoplay/speed, root motion track | Full BoneMap / retarget wizard UI |
| AnimationTree: states, transitions, travel, blend 1D/2D points, parameters | Nested blend-tree connection graph polish |
| SpriteFrames create/add frame/assign | — |
| Skeleton3D list/get/set/reset bone pose | BoneAttachment helpers |

### C. Physics ([tutorials/physics](https://github.com/godotengine/godot-docs/tree/master/tutorials/physics))

| Have | Missing |
|------|---------|
| setup body/collision/layers/raycast | Joints (Pin/Hinge/Generic6DOF) |
| | Area2D/3D monitoring helpers |
| | CharacterBody templates (move_and_slide setup beyond raw script) |
| | SoftBody, VehicleBody, PhysicalBone |
| | Shape cast / test_move debug |

### D. 2D / TileMap ([tutorials/2d](https://github.com/godotengine/godot-docs/tree/master/tutorials/2d))

| Have | Missing |
|------|---------|
| tilemap set/fill/clear/query | **TileSet authoring** (sources, atlas, collision polygons on tiles) |
| | Parallax, Camera2D limits helpers |
| | LightOccluder2D / CanvasModulate tooling |
| | NavigationRegion2D bake parity |

### E. UI ([tutorials/ui](https://github.com/godotengine/godot-docs/tree/master/tutorials/ui))

| Have | Missing |
|------|---------|
| anchors, theme color/font/stylebox | Size flags, focus neighbors, tab order |
| | Theme resource full edit (types, icons) beyond overrides |
| | Control min size / expand ratios as first-class |
| | RichTextBBCode helpers, ItemList/Tree population |

### F. Input ([tutorials/inputs](https://github.com/godotengine/godot-docs/tree/master/tutorials/inputs))

| Have | Missing |
|------|---------|
| set/get InputMap actions, simulate | Remove actions, list all events on action |
| | Joypad mapping, action strength deadzones as structured tools |
| | Shortcut resources |

### G. Export ([tutorials/export](https://github.com/godotengine/godot-docs/tree/master/tutorials/export))

| Have | Missing |
|------|---------|
| list presets, suggest export command, Android deploy | Reliable headless export completion + log capture as first-class tool |
| | Create/edit export presets |
| | iOS/Web/console specialty |

### H. Scripting depth ([tutorials/scripting](https://github.com/godotengine/godot-docs/tree/master/tutorials/scripting))

| Have | Missing |
|------|---------|
| GDScript CRUD | **C#** project files / scripts |
| | **Global class** registration visibility tools |
| | **Scene unique names** (`%Name`) set/get |
| | **Tool scripts** / `@tool` enable helpers |
| | Custom resources as first-class class_name workflows |
| | Debugger: breakpoints, step, call stack (beyond auto-continue) |

### I. Rendering ([tutorials/rendering](https://github.com/godotengine/godot-docs/tree/master/tutorials/rendering))

| Have | Missing |
|------|---------|
| environment, lights, material 3D basics | Compositor effects, GI (VoxelGI/SDFGI) setup tools |
| | Decals, reflection probes, lightmaps bake |
| | Render layers / cull masks structured helpers |

### J. Networking ([tutorials/networking](https://github.com/godotengine/godot-docs/tree/master/tutorials/networking))

| Have | Missing |
|------|---------|
| essentially none dedicated | MultiplayerAPI, MultiplayerSpawner/Synchronizer setup |
| | High-level multiplayer templates |

### K. I18n ([tutorials/i18n](https://github.com/godotengine/godot-docs/tree/master/tutorials/i18n))

| Missing | CSV/PO translation import, locale test, extract strings |

### L. IO / save ([tutorials/io](https://github.com/godotengine/godot-docs/tree/master/tutorials/io))

| Missing | Structured ConfigFile/JSON save helpers; user:// browser |

---

## 3. Agent *product* gaps (not just engine features)

These matter as much as missing tools:

| Gap | Issue |
|-----|--------|
| **Discovery** | ~200 plugin methods; agents see ~40–70 unless full mode + connection |
| **Schemas** | Most full-mode tools still free-form `call_editor` |
| **Class reference** | No MCP access to Godot **class docs** (methods/signals of `CharacterBody3D`, etc.) |
| **Examples / recipes** | Docs tutorials ≠ agent playbooks per domain |
| **Import timing** | Agents copy assets then edit scenes before import finishes |
| **Undo awareness** | Tools use UndoRedo but agents don’t get “undo stack” visibility |
| **Multi-scene editing** | Cross-scene batch exists; open-many / tabs weak |
| **Editor state** | Bottom dock, filesystem selection, drag-drop import not modeled |

---

## 4. Recommended priority (agent production, project-neutral)

### P0 — Unblocks everyday “human editor” work — largely done in 1.29

1. **Asset import control** — `ensure_imported` / `stage_files_into_res` / `import_paths` + reimport/wait/options  
2. **Property/schema discovery** — `list_property_info` + `describe_class`  
3. **InputMap completeness** — `create_input_map_preset` + set/remove/list events  
4. **Expose inspector tools in default tool list** — lite set + production macros always listed  
5. **Wait for filesystem** — `wait_for_import` / `ensure_imported`  
6. **Scaffold + signal wire + playtest macro** — `scaffold_project_defaults` / `wire_signal_to_new_method` / `playtest_report`  

### P1 — Production depth

7. **TileSet authoring** (atlas source, tile paint depth)  
8. **3D import depth** (extract meshes, inherited import scenes)  
9. **Physics joints + Area helpers**  
10. **Genre scaffolds** (platformer/fps templates beyond defaults)  

### P2 — Verticals

11. Networking multiplayer helpers  
12. I18n import  
13. GI / lightmap bake  
14. C# scripts  
15. XR  

### Explicit non-goals (for MCP)

- Replacing the Godot class reference browser entirely  
- Full visual shader graph  
- Full Animation editor GUI  
- Building the engine / custom modules  

Agents should use **scripts + `execute_editor_script` (guarded)** for long-tail APIs.

---

## 5. Coverage score (rough)

Relative to “human making a typical 2D/3D game from docs tutorials”:

| Layer | Score |
|-------|-------|
| Scene / node / inspector / signals / scripts | **~85%** |
| Playtest / debug loop | **~85%** (`playtest_report` macro) |
| 2D/3D content depth (tiles, anim, physics joints) | **~45–60%** |
| Assets import pipeline | **~70%** (`ensure_imported` / stage / presets) |
| Multiplayer / i18n / XR | **~15–30%** |
| Agent discovery of existing tools | **~70%** (lite schemas + macros + list_mcp_commands) |

---

## 6. Suggested next build (if we implement gaps)

Project-neutral package, not game-specific:

1. `describe_class` — ClassDB property/method/signal list (docs API substitute)  
2. `reimport_resources` + `wait_for_import`  
3. `get/set_import_option` for `.import`  
4. `input_map_remove_action` / `input_map_list_events`  
5. `set_scene_unique_name` / unique name query  
6. TileSet minimal authoring (one source + atlas region + optional collision)  
7. Schema pack for top 80 production tools (always listed, not only after discovery)

---

## References

- Docs repo: https://github.com/godotengine/godot-docs  
- Tutorial index: `tutorials/index.rst`  
- Editor inspector: `tutorials/editor/inspector_dock.rst`  
- Import: `tutorials/assets_pipeline/import_process.rst`  
- This fork command surface: `addons/godot_mcp/commands/*.gd`
