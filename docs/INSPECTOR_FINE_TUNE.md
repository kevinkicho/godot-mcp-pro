# Inspector fine-tune — full node & parameter control

Goal: agents can **discover and set every inspector-visible detail** on any node (and nested resources), matching what a human can do in the Godot Inspector — without claiming one MCP tool per ClassDB method.

Plugin **v1.39+**.

## Table of contents

1. [Guarantee](#guarantee)
2. [Read path (discover)](#read-path-discover)
3. [Write path (tune)](#write-path-tune)
4. [Nested resources](#nested-resources)
5. [Methods & ClassDB](#methods--classdb)
6. [Runtime (play mode)](#runtime-play-mode)
7. [Value formats](#value-formats)
8. [Recommended agent loop](#recommended-agent-loop)

---

## Guarantee

| Capability | Tool(s) |
|------------|---------|
| List every editor property + type/hint/enum/range | `list_property_info` |
| Expand sub-resources (shape, material, mesh…) | `list_property_info recurse_resources=true` |
| Find a field by name | `search_properties` |
| Read one field + metadata | `get_property` |
| Set one / many fields (UndoRedo) | `update_property` / `update_properties` |
| Revert to default | `reset_property` |
| Clear resource slot | `clear_property` / `remove_resource` |
| Create typed resource in slot | `add_resource` (+ `resource_properties`) |
| Call node methods | `list_node_methods` → `call_node_method` |
| Full engine class reference | `describe_class` / `list_class_*` |
| Script `@export` vars | Appear in `list_property_info` after attach; edit via `edit_script` |

**Not** covered 1:1: every ClassDB method as its own MCP tool — use `call_node_method` or `execute_editor_script`.

---

## Read path (discover)

```
inspect_node node_path=Player deep=true
list_property_info node_path=Player recurse_resources=true
list_property_info node_path=Player property_path=shape
search_properties node_path=Player query=collision
get_property node_path=Player property=motion_mode
describe_class class_name=CharacterBody2D include_inherited=true
```

Useful flags on `list_property_info`:

| Param | Purpose |
|-------|---------|
| `only_editable` | Default true — inspector-visible only |
| `include_internal` | Engine internals |
| `include_headers` | Category/group headers |
| `recurse_resources` | Nested Resource properties with dotted `path` |
| `max_depth` | Recursion depth (default 2) |
| `filter` | Substring on name/path |
| `property_path` | Catalog a resource slot as root |
| `max` | Cap result size |

Each property entry may include: `type`, `hint`, `enum_options`, `range`/`range_min`/`max`/`step`, `usage_flags`, `can_revert`, `nested_tunable`, `object_class`.

---

## Write path (tune)

```
update_property node_path=Player property=position value={"x":100,"y":200}
update_property node_path=Player property=motion_mode value=MOTION_MODE_FLOATING
update_properties node_path=Player properties={
  "scale": {"x":2,"y":2},
  "modulate": "#ff8800"
}
reset_property node_path=Player property=position
clear_property node_path=Mesh property=material_override
```

All sets go through **UndoRedo** (Ctrl+Z in editor).

---

## Nested resources

```
add_resource node_path=Hurtbox/CollisionShape2D property=shape resource_type=CircleShape2D resource_properties={radius:16}
update_property node_path=Hurtbox/CollisionShape2D property=shape.radius value=24
list_property_info node_path=Hurtbox/CollisionShape2D property_path=shape
```

Dotted / slash / colon paths are accepted: `shape.radius`, `shape/radius`.

---

## Methods & ClassDB

```
list_node_methods node_path=Anim filter=play
call_node_method node_path=Anim method=play args=["run"]
describe_class class_name=AnimationPlayer
list_class_properties class_name=GPUParticles3D include_inherited=true
```

---

## Runtime (play mode)

While playing:

```
get_game_node_properties node_path=... properties=[position, shape.radius] with_info=true
set_game_node_property node_path=... property=shape.radius value=20
assert_node_state …
```

Nested property sets are supported on the run plane (TCP/file IPC).

---

## Value formats

| Type | Accepted forms |
|------|----------------|
| Vector2/3/4 | `{"x", "y", …}`, `"Vector3(1,2,3)"`, `[1,2,3]` |
| Color | `{"r","g","b","a"}`, `"#rrggbb"`, `"Color(…)"` |
| Transform2D/3D | dict with `origin` / `basis` / `euler` / `scale` |
| Quaternion | `{x,y,z,w}` or `{euler:{…}}` degrees |
| Enum | integer **or name** from `enum_options` |
| Resource | `res://…` / `uid://…` path, or `add_resource` |
| Node ref | path string for `PROPERTY_HINT_NODE_TYPE` |
| Arrays | JSON arrays (packed arrays supported) |

---

## Recommended agent loop

```
get_scene_tree / select_nodes
  → inspect_node deep=true  OR  list_property_info recurse_resources=true
  → (optional) describe_class for unknown types
  → update_property / update_properties / add_resource
  → save_scene
  → playtest_report / get_game_screenshot
```

Topic guide: `agent_workflow_guide` with `topic: "inspector"`.

---

## Related

- [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md)
- [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md)
- [COMMAND_SURFACE.md](COMMAND_SURFACE.md)
