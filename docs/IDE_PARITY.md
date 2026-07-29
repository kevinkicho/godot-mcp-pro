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
| 2D TileMap | tilemap_* / tileset_* / scenes-as-tiles / patterns / `tilemap_stamp_pattern` |
| 2D Skeleton / IK | `setup_skeleton_2d` / `add_bone_2d` / `setup_two_bone_ik_2d` |
| 2D Mesh | `setup_mesh_instance_2d` / `convert_sprite_to_mesh_instance_2d` / MultiMesh2D |
| Pixel project pack | `apply_pixel_2d_project_preset` (stretch, nearest, snap, AA) |
| Shape resources | `create_shape_resource` / `setup_collision_from_shape_resource` |
| Custom `_draw` | `setup_canvas_draw_node` / canvas draw recipes |
| SubViewport minimap | `setup_subviewport_2d_world` + `setup_viewport_texture_rect` |
| Scene instances | `instance_packed_scene` / `set_editable_instance` / make local |
| TileMapLayer stacks | `setup_tilemap_layer_stack` |
| 2D pipelines | `pipeline_2d_pixel_game` / `pipeline_2d_tilemap_level` |
| AStar grid pathfinding | `setup_astar_grid_controller` / AStar2D·3D scripts |
| PBR materials | `create_standard_material_3d` / `assign_material_3d_to_mesh` |
| LabelSettings / fonts | `create_label_settings` / `create_font_file_resource` |
| Pre-ship gate | `pipeline_pre_ship_check` |
| Coverage % | [COVERAGE_SCORECARD.md](COVERAGE_SCORECARD.md) |
| CharacterBody motion | `apply_character_body_preset` / `set_character_body_motion` |
| TPS SpringArm rig | `setup_third_person_camera_rig` |
| Environment / Sky / Fog | `create_environment_resource` / `create_procedural_sky` / `setup_fog_volume` |
| ENet multiplayer | `create_enet_multiplayer_script` / `pipeline_multiplayer_enet` |
| Audio bus FX typed | `add_audio_bus_effect_typed` |
| Pack branch as scene | `pack_node_as_scene` / `pack_selection_as_scene` |
| InputMap JSON I/O | `export_input_map_json` / `import_input_map_json` |
| Named collision layers | `set_collision_layers_by_name` / mask by name |
| Find by class | `find_nodes_by_class` / name pattern / `reorder_node` |
| Camera limits from map | `set_camera_2d_limits_from_tilemap` |
| Make resource unique | `make_resource_unique` |
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
