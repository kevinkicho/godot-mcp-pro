# Humanoid interaction & level design

Agent-first verticals for playable characters, **avatar identity**, and structural level work.

## Humanoid interaction

| Tool | Role |
|------|------|
| `setup_humanoid_actor` | Body + capsule + model + AnimationPlayer + interaction Area |
| `validate_humanoid_rig` | Skeleton/anim/bone-name checks |
| `create_bone_map_preset` | mixamo / rpm / humanoid name maps |
| `apply_locomotion_set` | Ensure idle/walk/run/jump clip names (+ optional AnimationTree shell) |
| `bind_interaction` | Talk/use Area + prompt + input action |
| `list_humanoid_recipes` | Flow inventory |

## Avatar identity (v1.67)

| Tool | Role |
|------|------|
| `setup_avatar_slot_rig` | Slot holders + BoneAttachments (head/hair/weapons/…) |
| `equip_avatar_item` / `unequip_avatar_slot` | Instance gear into a slot |
| `apply_avatar_loadout` / `export_avatar_loadout` | JSON/config round-trip |
| `set_avatar_body_scale` | Proportions |
| `create_avatar_config_resource` | Saveable AvatarConfig |

## Mesh / face / materials

| Tool | Role |
|------|------|
| `list_mesh_surfaces` / `set_surface_override_material` | Per-surface materials |
| `list_blend_shapes` / `batch_set_blend_shapes` | Morph targets |
| `apply_face_pose_preset` | smile/blink/angry/… (name-fuzzy) |
| `apply_skin_tone` / `apply_avatar_material_pack` | Look identity |
| `get_mesh_skin_info` | Skin binds + skeleton path |

## Retarget / import depth

| Tool | Role |
|------|------|
| `prepare_mixamo_character_import` / `prepare_rpm_character_import` | Import presets |
| `build_bone_map_from_skeleton` / `validate_bone_map_coverage` | BoneMap quality |
| `retarget_report_for_character` | Composite health score |
| `set_bone_rest` / `copy_skeleton_rest` / `apply_pose_as_rest` | Rest authorship |

**Also use:** `apply_example_animation`, Bezier/curve tools, dialogue/quest, hitbox/hurtbox, AI agents.

```
prepare_mixamo_character_import path=res://models/hero.glb
pipeline_character_from_gltf gltf_path=res://models/hero.glb profile=mixamo
setup_avatar_slot_rig node_path=Humanoid
equip_avatar_item node_path=Humanoid slot=hair scene_path=res://items/hair_01.tscn
list_blend_shapes node_path=Humanoid/Model/Body
apply_face_pose_preset node_path=… preset=smile
apply_skin_tone node_path=… tone=medium
retarget_report_for_character node_path=Humanoid
playtest_report
```

## Level design

| Tool | Role |
|------|------|
| `greybox_room` / `greybox_corridor` | CSG blockout |
| `place_prop_scatter` | Seeded prop scatter |
| `stamp_scene_instances` | Exact multi-place |
| `validate_level_playable` | Spawn/goal/nav/collision checks |
| `level_playtest_route` | Waypoint list + agent steps |
| GridMap: `gridmap_set_cell`, `fill_rect`, `paint_line`, `get_used_cells`, … | 3D cell paint |
| MultiMesh: `setup_multimesh_instance`, `multimesh_scatter`, … | Dense props |
| TileMap tools | 2D levels |

```
greybox_room width=20 depth=20
setup_navigation_region + bake_navigation_mesh
place_prop_scatter count=30 scene_path=res://props/crate.tscn
validate_level_playable
level_playtest_route
playtest_report
```

## Animation libraries

| Tool | Role |
|------|------|
| `create_animation_library_resource` | Empty pack |
| `animation_library_import_from_scene` | Pull clips from example `.tscn` |
| `animation_library_merge_from_player` | From open AnimationPlayer |
| `animation_library_rename_clip` | idle/walk/run naming |
| `animation_library_assign_to_player` | Attach pack |

## Closed-loop verification

Always: mutate → `playtest_report` / `run_record_*` / `assert_node_state` / screenshots → `list_property_info` → tune numbers.

## Related

- [ANIMATION_FINE_TUNE.md](ANIMATION_FINE_TUNE.md)  
- [CURVES_AND_BEZIER.md](CURVES_AND_BEZIER.md)  
- [HEADLESS_AGENT.md](HEADLESS_AGENT.md)  
