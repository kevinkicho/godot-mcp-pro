# Animation fine-tune from examples

**Yes — agents can use this MCP to copy example animations and fine-tune them**, the same way a human uses the Animation dock + library paste + track path edits.

## Table of contents

1. [Answer](#answer)
2. [Recommended agent flow](#recommended-agent-flow)
3. [Core tools](#core-tools)
4. [Worked example](#worked-example)
5. [Related surfaces](#related-surfaces)

---

## Answer

| Question | Answer |
|----------|--------|
| Can agent **read** an example clip’s tracks/keys? | **Yes** — `dump_animation` / `get_animation_info` |
| Can agent **copy** example → target player? | **Yes** — `apply_example_animation` / `copy_animation_to_player` |
| From another **scene file**? | **Yes** — `example_scene_path` or `extract_animations_from_scene` |
| Fix hierarchy path mismatch? | **Yes** — `remap_animation_track_paths` |
| Change speed / timing? | **Yes** — `scale_animation_time`, `offset_animation_keys`, `crop_animation` |
| Nudge individual keys? | **Yes** — `set_animation_keyframe`, `set_bezier_key` |
| Verify vs example? | **Yes** — `compare_animations`, `sample_animation_at_time` |
| Playtest? | **Yes** — `animation_player_play` + `playtest_report` / screenshots |

Also use **`list_property_info`** on the AnimationPlayer for inspector properties (autoplay, speed, callback mode).

---

## Recommended agent flow

```
agent_ensure_ready
  → list_animations node_path=Example/Anim   OR extract_animations_from_scene
  → dump_animation node_path=… animation=Walk include_keys=true
  → apply_example_animation
        example_scene_path=res://examples/hero.tscn
        source_animation=Walk
        target_node_path=Player/AnimationPlayer
        target_animation=Walk
        from_prefix=Armature/Skeleton3D
        to_prefix=Model/Skeleton3D
        scale=1.0
  → compare_animations source_… target_…
  → set_animation_keyframe …   # fine-tune
  → animation_player_play + playtest_report
  → save_scene
```

Topic guide: `agent_workflow_guide topic=animation`

---

## Core tools

| Tool | Role |
|------|------|
| `list_animation_fine_tune_tools` | Flow cheat-sheet |
| `dump_animation` | Full tracks+keys dump |
| `extract_animations_from_scene` | List/copy from example `.tscn` |
| `apply_example_animation` | One-shot copy + remap + scale |
| `copy_animation_to_player` | Same-scene player→player |
| `copy_animation_track` | Single track |
| `remap_animation_track_paths` | Prefix/exact path rewrite |
| `compare_animations` | Diff paths/keys/length |
| `scale_animation_time` / `offset_animation_keys` / `crop_animation` | Timing |
| `sample_animation_at_time` | Pose sample at `t` |
| `set_animation_keyframe` / `set_bezier_key` | Per-key fine-tune |
| `save_animation_resource` / `load_animation_resource` | `.res` library assets |
| `animation_player_play` / seek / stop | Playback |

---

## Worked example

**User:** “Make the player walk animation match `res://examples/npc_walk.tscn` but slightly faster and retargeted to our skeleton.”

```
1. extract_animations_from_scene scene_path=res://examples/npc_walk.tscn
2. apply_example_animation
     example_scene_path=res://examples/npc_walk.tscn
     source_animation=walk
     target_node_path=Player/AnimationPlayer
     target_animation=walk
     from_prefix=Root/Armature
     to_prefix=Player/Model
     scale=0.85
3. compare_animations …
4. sample_animation_at_time time=0.5
5. set_animation_keyframe on foot bone tracks if needed
6. animation_player_play animation=walk
7. playtest_report / get_game_screenshot
```

---

## Related surfaces

- AnimationTree: `create_animation_tree`, `travel_animation_state`, blend spaces  
- Skeleton: `list_skeleton_bones`, `set_bone_pose`, `create_bone_map`  
- Inspector: `list_property_info` on player/tree nodes  
- Import: glTF animation import flags via import tools  

---

## Honesty

- Full visual Bezier curve GUI is not replicated; **handles are set numerically** via `set_bezier_key`.  
- Full importer Retarget wizard UI is partial; use **BoneMap + remap paths** + pose tools.  
- Escape hatch: `call_editor` / `execute_editor_script` for edge cases.
