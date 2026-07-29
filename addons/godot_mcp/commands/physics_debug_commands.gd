@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Physics debug visibility + structural cast helpers (tutorials/physics).


func get_commands() -> Dictionary:
	return {
		"set_collision_debug_visible": _set_collision_debug_visible,
		"get_physics_debug_settings": _get_physics_debug_settings,
		"editor_raycast": _editor_raycast,
		"list_physics_shapes_in_scene": _list_physics_shapes_in_scene,
		"list_physics_debug_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_collision", "add_raycast", "get_collision_info", "mesh_create_trimesh_static_body"],
	})


func _set_collision_debug_visible(params: Dictionary) -> Dictionary:
	var enabled: bool = optional_bool(params, "enabled", true)
	# Project debug settings used by running game
	var keys := {
		"debug/shapes/collision/shape_color": Color(0, 0.6, 0.7, 0.42),
		"debug/shapes/collision/contact_color": Color(1, 0.2, 0.1, 0.8),
		"debug/shapes/collision/disable_collision_shape_color": Color(0.5, 0.5, 0.5, 0.3),
	}
	if ProjectSettings.has_setting("debug/shapes/collision/draw_2d_outlines"):
		ProjectSettings.set_setting("debug/shapes/collision/draw_2d_outlines", enabled)
	# Viewport debug draw while editing
	if EditorInterface.has_method("get_editor_viewport_3d"):
		var vp = EditorInterface.get_editor_viewport_3d(0)
		if vp and optional_bool(params, "viewport_wireframe", false) and "debug_draw" in vp:
			vp.set("debug_draw", Viewport.DEBUG_DRAW_WIREFRAME if enabled else Viewport.DEBUG_DRAW_DISABLED)
	# Visible collision shapes in running game: project setting
	# application/run/max_fps etc. — use debug option
	if ProjectSettings.has_setting("debug/settings/stdout/print_fps"):
		pass
	# Godot 4: "debug/shapes/collision/..." 
	ProjectSettings.set_setting("mcp/physics_debug_requested", enabled)
	ProjectSettings.save()
	# Visible collision shapes toggle is often an EditorDebugger feature;
	# also set on open scene CollisionShape visible_gizmo via notify
	var count := 0
	if optional_bool(params, "show_shape_nodes", false):
		var root := get_edited_root()
		if root:
			count = _set_shapes_visible(root, enabled)
	return success({
		"enabled": enabled,
		"shape_nodes_toggled": count,
		"hint": "In running game use Debug menu Visible Collision Shapes, or play with debug; mcp stores mcp/physics_debug_requested",
	})


func _set_shapes_visible(n: Node, vis: bool) -> int:
	var c := 0
	if n is CollisionShape2D or n is CollisionShape3D or n is CollisionPolygon2D or n is CollisionPolygon3D:
		n.visible = vis
		c += 1
	for ch in n.get_children():
		c += _set_shapes_visible(ch, vis)
	return c


func _get_physics_debug_settings(_params: Dictionary) -> Dictionary:
	var out := {}
	for k in [
		"debug/shapes/collision/shape_color",
		"debug/shapes/collision/contact_color",
		"debug/shapes/collision/draw_2d_outlines",
		"layer_names/3d_physics/layer_1",
		"layer_names/2d_physics/layer_1",
		"mcp/physics_debug_requested",
	]:
		if ProjectSettings.has_setting(k):
			out[k] = ProjectSettings.get_setting(k)
	return success({"settings": out})


func _editor_raycast(params: Dictionary) -> Dictionary:
	## Raycast in edited scene using PhysicsDirectSpaceState (needs world).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var is_3d: bool = optional_bool(params, "is_3d", true)
	if is_3d:
		if not (root is Node3D) and root.get_viewport() == null:
			return error_invalid_params("3D raycast needs Node3D scene in tree")
		var from := _v3(params.get("from", {"x": 0, "y": 10, "z": 0}))
		var to := _v3(params.get("to", {"x": 0, "y": -10, "z": 0}))
		# Prefer playing game for accurate physics
		if EditorInterface.is_playing_scene():
			var pr: Dictionary = await send_game_command("physics_raycast", {
				"from": {"x": from.x, "y": from.y, "z": from.z},
				"to": {"x": to.x, "y": to.y, "z": to.z},
			}, 5.0)
			if pr.has("result"):
				return success(pr["result"] if pr["result"] is Dictionary else {"hit": pr["result"]})
		var w3: World3D = root.get_world_3d() if root is Node3D else null
		if w3 == null and root.get_viewport():
			w3 = root.get_viewport().world_3d
		if w3 == null:
			return error_internal("No World3D — play scene for physics raycast")
		var space := w3.direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to)
		if params.has("collision_mask"):
			q.collision_mask = int(params["collision_mask"])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return success({"hit": false, "from": _dump_v3(from), "to": _dump_v3(to)})
		return success({
			"hit": true,
			"position": _dump_v3(hit.get("position", Vector3.ZERO)),
			"normal": _dump_v3(hit.get("normal", Vector3.UP)),
			"collider": str(hit["collider"].name) if hit.get("collider") is Node else str(hit.get("collider")),
			"shape": hit.get("shape", -1),
		})
	# 2D
	var from2 := _v2(params.get("from", {"x": 0, "y": 0}))
	var to2 := _v2(params.get("to", {"x": 0, "y": 100}))
	if EditorInterface.is_playing_scene():
		var pr2: Dictionary = await send_game_command("physics_raycast", {
			"mode": "2d",
			"from": {"x": from2.x, "y": from2.y},
			"to": {"x": to2.x, "y": to2.y},
		}, 5.0)
		if pr2.has("result"):
			return success(pr2["result"] if pr2["result"] is Dictionary else {"hit": pr2["result"]})
	var w2: World2D = root.get_world_2d() if root is Node2D else (root.get_viewport().world_2d if root.get_viewport() else null)
	if w2 == null:
		return error_internal("No World2D")
	var space2 := w2.direct_space_state
	var q2 := PhysicsRayQueryParameters2D.create(from2, to2)
	var hit2 := space2.intersect_ray(q2)
	if hit2.is_empty():
		return success({"hit": false})
	return success({
		"hit": true,
		"position": {"x": hit2.position.x, "y": hit2.position.y},
		"collider": str(hit2.collider.name) if hit2.collider is Node else str(hit2.collider),
	})


func _list_physics_shapes_in_scene(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var max_n: int = clampi(optional_int(params, "max", 200), 1, 1000)
	var out: Array = []
	_walk_shapes(root, root, out, max_n)
	return success({"shapes": out, "count": out.size()})


func _walk_shapes(n: Node, root: Node, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	if n is CollisionShape3D:
		var cs := n as CollisionShape3D
		out.append({
			"path": str(root.get_path_to(n)),
			"type": "CollisionShape3D",
			"shape": cs.shape.get_class() if cs.shape else null,
			"disabled": cs.disabled,
		})
	elif n is CollisionShape2D:
		var cs2 := n as CollisionShape2D
		out.append({
			"path": str(root.get_path_to(n)),
			"type": "CollisionShape2D",
			"shape": cs2.shape.get_class() if cs2.shape else null,
			"disabled": cs2.disabled,
		})
	elif n is PhysicsBody3D or n is PhysicsBody2D or n is Area3D or n is Area2D:
		out.append({
			"path": str(root.get_path_to(n)),
			"type": n.get_class(),
			"kind": "body_or_area",
		})
	for c in n.get_children():
		_walk_shapes(c, root, out, max_n)


func _v3(v: Variant) -> Vector3:
	if v is Dictionary:
		return Vector3(float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0)))
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


func _v2(v: Variant) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


func _dump_v3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}
