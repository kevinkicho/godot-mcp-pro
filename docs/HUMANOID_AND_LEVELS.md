# Humanoid interaction & level design

Agent-first verticals for playable characters and structural level work.

## Humanoid interaction

| Tool | Role |
|------|------|
| `setup_humanoid_actor` | Body + capsule + model + AnimationPlayer + interaction Area |
| `validate_humanoid_rig` | Skeleton/anim/bone-name checks |
| `create_bone_map_preset` | mixamo / rpm / humanoid name maps |
| `apply_locomotion_set` | Ensure idle/walk/run/jump clip names (+ optional AnimationTree shell) |
| `bind_interaction` | Talk/use Area + prompt + input action |
| `list_humanoid_recipes` | Flow inventory |

**Also use:** `apply_example_animation`, Bezier/curve tools, dialogue/quest, hitbox/hurtbox, AI agents.

```
setup_humanoid_actor model_scene=res://models/hero.tscn
validate_humanoid_rig node_path=Humanoid
create_bone_map_preset profile=mixamo
apply_locomotion_set node_path=Humanoid/AnimationPlayer
apply_example_animation …
bind_interaction actor_path=Humanoid kind=talk
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
