# IDE parity for agents

Goal: a Grok (or any) agent uses Godot MCP to do **what a human does in the editor** — assemble, tune numbers, playtest, fix — continuously expanded toward full SDK/docs surface.

## Session

```
agent_ensure_ready project_path=…
list_mcp_commands / call_editor for any gap
agent_workflow_guide topic=production|humanoid|level|animation|audio|editor
```

## Major planes

| Human dock / workflow | MCP path |
|----------------------|----------|
| Scene / Inspector | node/scene tools + `list_property_info` / `update_property` |
| Animation | transfer + Bezier Cartesian + libraries |
| FileSystem | search/stage/import + `list_resources_by_type` + open path |
| Resource move/rename | `find_files_referencing` / `remap_resource_references` / deps |
| 2D TileMap | tilemap_* / tileset_* |
| 3D GridMap | gridmap_* |
| Mesh → collision | `mesh_create_trimesh_static_body` / convex (Mesh menu) |
| CSG greybox | setup_csg_* + `csg_set_operation` + `csg_bake_to_mesh_instance` |
| Terrain (height) | `create_heightmap_terrain` |
| Large world | `stream_load_chunk` / StreamManager |
| MultiMesh props | multimesh_* |
| Character / interaction | humanoid_* |
| Level greybox | greybox_* / validate_level_playable |
| Navigation | navigation_* |
| Audio / music | audio_* / music_* |
| Viewport focus | `editor_focus_node` / `editor_frame_selection` (F key) |
| Play / QA | `playtest_report` + **`playtest_sequence`** (inputs+asserts) + runtime TCP |
| Scene health | `audit_scene_tree` / `list_scene_signals` / `validate_all_scenes` |
| Export | export_* / verify_export_ready |
| Curves | curve_* / bezier_* |
| Mesh LODs | `mesh_generate_lods` / `set_visibility_range` / `setup_lod_mesh_instances` |
| Lightmap UV2 | `mesh_lightmap_unwrap` / `batch_prepare_lightmap_meshes` / `lightmap_bake_prepare` |
| Movie Maker | `play_with_movie_maker` / `capture_play_session` |
| Nav path debug | `navigation_query_path` / `draw_debug_path` / `navigation_set_debug_enabled` |
| AnimationTree graph | `create_simple_locomotion_tree` / `export_animation_tree_graph` / blend-space recipes |
| Quality packs | `apply_lod_distance_preset` / `apply_lightmap_quality_preset` / `apply_platform_render_pack` |
| Agent pipelines | `list_agent_pipelines` / `pipeline_*` multi-step recipes |
| Live nav path | `navigation_live_path` (play → query → draw) |
| Particles / VFX | `set_particle_process_params` / attractors / turbulence |
| Interaction | `setup_interaction_zone` / prompt UI / `bind_interaction_action` |
| Export signing | `get_export_signing_checklist` / Android keystore helpers |
| HTTP + encrypted IO | `create_http_client_script` / `encrypted_file_*` |
| Physics debug | `editor_raycast` / `set_collision_debug_visible` |
| 3D structure | VisibleOnScreen*, RemoteTransform, WorldBoundary, Occluder, Marker |
| Project hygiene | `analyze_project_best_practices` |

## Universal escape hatches

- **`call_editor`** — any of 800+ registered plugin methods  
- **`describe_class` / `list_class_*`** — full ClassDB  
- **`call_node_method` / `execute_editor_script`** — long-tail APIs  
- **`batch_call_editor`** — multi-step dock work  

## Expansion rule

If it appears in Godot docs/ClassDB as data (numbers, resources, nodes), expose it. Prefer composed recipes (humanoid, level) for agent reliability, not fewer tools.

## Related

- [HEADLESS_AGENT.md](HEADLESS_AGENT.md)  
- [HUMANOID_AND_LEVELS.md](HUMANOID_AND_LEVELS.md)  
- [ANIMATION_FINE_TUNE.md](ANIMATION_FINE_TUNE.md)  
- [CURVES_AND_BEZIER.md](CURVES_AND_BEZIER.md)  
- [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md)  
