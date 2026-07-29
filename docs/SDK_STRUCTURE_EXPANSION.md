# Godot SDK / docs → MCP structural expansion

**As of:** v1.54 · Official tutorials index (Godot 4.x docs) · live `list_docs_coverage` + `get_agent_capability_map`

## What we audited

Official [Tutorials](https://docs.godotengine.org/en/stable/tutorials/index.html) topics plus structural ClassDB systems agents need for real games (not one tool per method).

## Critical structural surfaces (priority)

| Structure | Why agents need it | MCP path (v1.49+) | Status |
|-----------|--------------------|-------------------|--------|
| **Scene tree + inspector** | Compose any content | node/*, list_property_info, call_node_method | strong |
| **Resources + deps** | Move/rename without breaks | resource_graph_*, remap_resource_references | strong |
| **Physics bodies/shapes** | Collision is gameplay law | physics_*, mesh_collision_*, physics_debug_* | strong |
| **Navigation maps** | AI pathing | navigation_*, nav_debug_*, navigation_live_path | strong |
| **Rendering / GI / LOD** | Ship visual quality | lightmap_*, lod_*, quality_preset_*, render_gi_* | strong |
| **Particles / VFX** | Juice + feedback | particle_*, particle_depth_* | **expanded 1.49** |
| **Interaction zones** | Use/talk/pickup loops | interaction_zone_* | **new 1.49** |
| **HTTP + encrypted IO** | Online + secure saves | http_io_*, io_* | **expanded 1.49** |
| **Export signing** | Store ship blockers | export_signing_* | **new 1.49** |
| **Visibility / streaming structure** | Perf culling | structure_3d_*, scene_stream_* | **expanded 1.49** |
| **Animation graphs** | Character motion | animation_tree_* graph recipes | strong |
| **Best practices checks** | Hygiene before ship | best_practices_* | **new 1.49** |
| **i18n CSV + scene extract** | Localization pipeline | i18n_csv_* | **expanded 1.50** |
| **TileSet terrain peering** | 2D auto-tile structure | tileset_terrain_depth_* | **expanded 1.50** |
| **Import option schemas** | Asset pipeline discovery | import_schema_* | **new 1.50** |
| **PathFollow** | Dolly / platforms | path_follow_* | **new 1.50** |
| **AudioStreamGenerator** | Procedural audio | audio_generator_* | **new 1.50** |
| **Display/window** | Platform window settings | display_window_* | **new 1.50** |
| **Joint limits** | Physics constraints | joint_limit_* | **new 1.50** |
| **Ragdoll from skeleton** | Death/physics characters | ragdoll_* | **new 1.51** |
| **XR passthrough / layers** | MR / AR blend | xr_passthrough_* | **new 1.51** |
| **TileSet atlas regions** | 2D atlas authoring | tileset_atlas_depth_* | **new 1.51** |
| **SoftBody / vehicle stacks** | Soft cloth + cars | softbody_depth_*, vehicle_depth_* | **new 1.51** |
| **SpriteFrames depth** | 2D clip edit | sprite_frames_depth_* | **new 1.51** |
| **Shader includes** | Shared GLSL libraries | shader_include_* | **new 1.52** |
| **UI container depth** | Tabs/splits/flow/viewport | ui_container_depth_* | **new 1.52** |
| **Multiplayer interest** | AOI / visibility / bandwidth | multiplayer_interest_* | **new 1.52** |
| **Skeleton IK** | Procedural limbs/look-at | skeleton_ik_* | **new 1.52** |
| **Cameras** | 2D/3D view control | camera_depth_* | **new 1.53** |
| **2D lighting stack** | Modulate + occluders | light_2d_depth_* | **new 1.53** |
| **Async resources** | Threaded loads | async_resource_* | **new 1.53** |
| **StyleBox / theme boxes** | UI chrome | stylebox_* | **new 1.53** |
| **Utility AI / GOAP** | Decision recipes | utility_ai_* | **new 1.53** |
| **ClassDB long tail** | Anything else | describe_class, execute_editor_script, call_editor | strong (lookup) |

## Docs areas still intentionally partial

| Area | Why partial | Agent workaround |
|------|-------------|------------------|
| Console platforms | Vendor SDKs | Out of scope |
| iOS codesign on Windows | Needs macOS/Xcode | Checklist only via export_signing |
| Full VisualShader node catalog | Huge UI surface | visual_shader_* + describe_class |
| Cloud saves / matchmaking hosts | Third-party services | Templates only |
| One tool per ClassDB method | Unmaintainable | describe_class + call_node_method |

## Expansion rule (keep using)

1. Prefer **workflow recipes** (pipelines) over raw ClassDB dumps.  
2. Expose **numbers and resources** agents can set without a GUI.  
3. Keep **escape hatches**: `call_editor`, `execute_editor_script`, `describe_class`.  
4. Refresh with `.\scripts\export-surface-registry.ps1` + `list_docs_coverage`.  
5. **Discovery first:** `list_agent_domains` → `list_tools_by_domain` → `get_tool_examples` (v1.54).  

## v1.54 roadmap delivery

| Wave | Status |
|------|--------|
| 1 Discovery index / search / examples | **shipped** (`discovery_commands`) |
| 2 Playtest fix loop | **shipped** (`playtest_fix_commands`) |
| 3 glTF character + retarget pipeline | **shipped** (`retarget_pipeline_commands`) |
| 4 Theme type depth + dialogue graph CRUD | **shipped** |
| 5 Debugger intel + performance budgets | **shipped** |
| 6 VisualShader presets + tile custom data | **shipped** |

## Related

- [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md)  
- [IDE_PARITY.md](IDE_PARITY.md)  
- [GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md)  
