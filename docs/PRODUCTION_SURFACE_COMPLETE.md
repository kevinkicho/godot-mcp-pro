# Production surface complete (v1.66)

## Claim (precise)

**Godot MCP Pro agent production surfacing is complete** for shipping game content:

| Pillar | Status |
|--------|--------|
| Scene / inspector / scripts | complete |
| 2D / 3D content production | complete |
| Playtest / QA loops | complete |
| Animation / audio / UI | complete |
| Multiplayer lobby + ENet | complete |
| XR player rig | complete |
| Save/load + inventory + game loop | complete |
| Export + CI templates | complete |
| Discovery domains | complete |
| ClassDB escape hatches | complete |

## What “complete” does **not** mean

- **Not** one MCP tool per ClassDB method  
- **Not** every editor dock pixel automated  
- **Not** console vendor SDKs  
- **Not** hosted matchmaking / cloud save services  
- **Not** full visual graph canvas UIs (recipes instead)  
- **Not** iOS App Store upload from Windows  

See live: `list_out_of_scope_surfaces` · `get_production_surface_report`.

## Agent entry points

```
list_agent_domains
get_production_surface_report
pipeline_game_loop_shell
pipeline_2d_pixel_game
pipeline_3d_character_tps
pipeline_multiplayer_lobby
pipeline_xr_setup
pipeline_export_ci
pipeline_pre_ship_check
```

## Escape hatches (long tail)

- `call_editor` / `batch_call_editor`
- `describe_class` / `get_class_usage_examples`
- `call_node_method` / `execute_editor_script`
- `update_property` on any inspector path
