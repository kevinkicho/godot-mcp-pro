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
| 2D TileMap | tilemap_* / tileset_* |
| 3D GridMap | gridmap_* |
| Terrain (height) | `create_heightmap_terrain` |
| Large world | `stream_load_chunk` / StreamManager |
| MultiMesh props | multimesh_* |
| Character / interaction | humanoid_* |
| Level greybox | greybox_* / validate_level_playable |
| Navigation | navigation_* |
| Audio / music | audio_* / music_* |
| Play | play_main/current/custom + playtest_report + runtime TCP |
| Export | export_* / verify_export_ready |
| Curves | curve_* / bezier_* |

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
