# Curves & Bezier — full numerical SDK surface

Agents fine-tune curves by **control points and handles in Cartesian space**, not by dragging a GUI. That is enough for identifying focal points, extrema, and mapping them onto Godot’s data model.

## Table of contents

1. [Principle](#principle)
2. [Animation Bezier tracks](#animation-bezier-tracks)
3. [Curve / Curve2D / Curve3D resources](#curve--curve2d--curve3d-resources)
4. [Path2D / Path3D](#path2d--path3d)
5. [Agent workflow](#agent-workflow)

---

## Principle

| Godot data | Agent representation |
|------------|----------------------|
| Bezier key | Anchor `(time, value)` + in/out handle offsets |
| Handle endpoints | `(time + in.x, value + in.y)` absolute plane points |
| Curve2D/3D | Position + in/out vectors; `in_world` / `out_world` endpoints |
| Dense shape | `bezier_sample_dense` / `curve*_sample_polyline` |

No tool is withheld because “humans drag points.” If ClassDB exposes the numbers, MCP exposes the numbers.

---

## Animation Bezier tracks

| Tool | Purpose |
|------|---------|
| `bezier_list_keys_cartesian` | All keys as anchors + handle endpoints on time×value plane |
| `bezier_set_keys_batch` | Write many keys from `{time/x, value/y, in, out}` or absolute endpoints |
| `bezier_sample_dense` | Dense polyline of the track for shape analysis |
| `bezier_set_handle_mode` | free / linear / balanced / mirrored (+ explicit handles) |
| `bezier_remove_key` | Delete by index or time |
| `set_bezier_key` / `get_bezier_key_info` | Single-key API |

**Plane:** `x = time (seconds)`, `y = property value`.

```
bezier_list_keys_cartesian node_path=… animation=… track_index=0
  → identify peaks at anchors / handle endpoints
bezier_set_keys_batch keys=[
  {x:0, y:0, in:{x:-0.1,y:0}, out:{x:0.2,y:0.5}},
  {x:0.5, y:1, in_endpoint:{x:0.3,y:1}, out_endpoint:{x:0.7,y:1}},
  …
]
bezier_sample_dense samples=64
```

---

## Curve / Curve2D / Curve3D resources

| Tool | Purpose |
|------|---------|
| `create_curve_resource` / `curve_set_points` / `curve_get_points` | 1D Curve |
| `curve_sample` / `curve_sample_baked` | Evaluate / dense 1D polyline |
| `create_curve2d_resource` / `curve2d_*` | 2D paths |
| `create_curve3d_resource` / `curve3d_*` | 3D paths |
| `list_curve_sdk_tools` | Inventory |

Point formats accept arrays or dicts with `position`, `in`/`out` handles.

---

## Path2D / Path3D

| Tool | Purpose |
|------|---------|
| `path_get_curve_points` | Live node curve + world handle endpoints |
| `path_set_curve_points` | Replace Path curve from Cartesian points |
| `setup_path_2d` / `setup_path_3d` | Create path nodes |

---

## Agent workflow

```
1. bezier_sample_dense / curve2d_sample_polyline  → understand shape
2. bezier_list_keys_cartesian / curve*_get_points → focal control points
3. Compute new anchors/handles (agent reasoning)
4. bezier_set_keys_batch / curve*_set_points / path_set_curve_points
5. playtest / sample again
```

Example animation copy still uses `apply_example_animation` then Bezier tools for per-track polish.

---

## Related

- [ANIMATION_FINE_TUNE.md](ANIMATION_FINE_TUNE.md)  
- [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md)  
- Godot docs: Curve, Curve2D, Curve3D, Animation tracks  
