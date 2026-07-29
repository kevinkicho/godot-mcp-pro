# Surface expansion (v1.40)

How we keep closing the gap between **Godot docs / SDK tutorials** and **agent-accessible MCP tools**.

## Philosophy

1. **Workflow tools** for tutorial folders (not one tool per ClassDB method).  
2. **Fine-tune everything** on nodes via inspector tools (v1.39).  
3. **Expand verticals** that were partial/thin (v1.40 list below).  
4. **Honesty** in `list_docs_coverage` gaps when engine UI has no plugin API.

## v1.40 modules & tools

| Docs / gap area | New tools |
|-----------------|-----------|
| Rendering / GI | `configure_sdfgi`, `ssao`, `ssr`, `glow`, `ssil`, `set_mesh_lightmap_params`, `list_gi_tools` |
| Inputs / joypad | `create_joypad_input_map_preset`, `add_joypad_binding`, `list_joypads`, deadzone/strength |
| I18n extract | `extract_translatable_strings`, `export_pot_template` |
| Theme resource | `theme_set_type_*`, `theme_list_types`, `theme_get_type_info`, `assign_theme_to_control` |
| Encrypted saves | `create_encrypted_save_manager_script` |
| Animation | `set_bezier_key`, `get_bezier_key_info`, `apply_bone_map_to_skeleton` |
| GDExtension | `clone_godot_cpp`, `setup_gdextension_full` |
| Migrating | `scan_godot3_patterns`, `apply_migration_replacements`, `get_migration_guide` |
| Performance | `export_performance_report`, `get_gpu_profiling_hints` |
| WebRTC | `create_webrtc_ice_config_script` |

## Agent recipes

### Polish a 3D look
```
apply_environment_preset preset=outdoor_day
configure_sdfgi enabled=true
configure_ssao intensity=2.0
set_mesh_lightmap_params node_path=... gi_mode=static
add_lightmap_gi → request_lightmap_bake
```

### Gamepad-ready InputMap
```
create_input_map_preset preset=platformer_2d
create_joypad_input_map_preset preset=platformer merge=true
list_joypads
```

### Localization pass
```
extract_translatable_strings path=res://
export_pot_template path=res://locale/messages.pot
load_csv_translations …
```

### GDExtension
```
setup_gdextension_full name=myext clone_godot_cpp=true build=false
# then run_gdextension_scons_build when toolchain ready
```

### Godot 3 script cleanup
```
scan_godot3_patterns path=res://
apply_migration_replacements dry_run=true
apply_migration_replacements dry_run=false
```

## Still not 100% SDK

- GPU frame debugger **graph** (engine UI only)  
- Full Animation Retargeting **importer** UI  
- Commercial matchmaking / TURN hosting  
- Console platform SDKs  
- One MCP tool per ClassDB method  

Escape hatches: `describe_class`, `call_node_method`, `execute_editor_script`, `list_property_info recurse_resources=true`.

## Related

- [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md)  
- [INSPECTOR_FINE_TUNE.md](INSPECTOR_FINE_TUNE.md)  
- [../GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md)  
