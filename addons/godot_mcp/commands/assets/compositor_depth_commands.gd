@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Compositor / post-fx stack depth for WorldEnvironment.


func get_commands() -> Dictionary:
	return {
		"setup_compositor_on_environment": _setup_compositor_on_environment,
		"compositor_list_effects": _compositor_list_effects,
		"compositor_clear_effects": _compositor_clear_effects,
		"list_compositor_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_compositor", "add_compositor_effect", "apply_environment_preset", "configure_glow"],
	})


func _find_world_env(path: String = "") -> WorldEnvironment:
	var root := get_edited_root()
	if root == null:
		return null
	if not path.is_empty():
		var n := find_node_by_path(path)
		if n is WorldEnvironment:
			return n as WorldEnvironment
	return _find_we(root)


func _find_we(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n as WorldEnvironment
	for c in n.get_children():
		var f := _find_we(c)
		if f:
			return f
	return null


func _setup_compositor_on_environment(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var we := _find_world_env(optional_string(params, "node_path", ""))
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		we.environment = Environment.new()
		var parent := find_node_by_path(optional_string(params, "parent_path", "."))
		if parent == null:
			parent = root
		add_child_with_undo(parent, we, root, "MCP: WorldEnvironment for compositor")
	if we.environment == null:
		we.environment = Environment.new()
	var comp := Compositor.new()
	# Optional effect class names
	var effects: Array = params.get("effects", [])
	var added: Array = []
	if effects is Array:
		for e in effects:
			var cname := str(e)
			if not cname.begins_with("CompositorEffect") and ClassDB.class_exists("CompositorEffect" + cname):
				cname = "CompositorEffect" + cname
			if ClassDB.class_exists(cname):
				var eff = ClassDB.instantiate(cname)
				if eff:
					comp.compositor_effects.append(eff)
					added.append(cname)
	we.compositor = comp
	mark_current_scene_unsaved()
	return success({
		"world_environment": str(root.get_path_to(we)),
		"effects_added": added,
		"hint": "add_compositor_effect for more; effect classes are version-dependent",
	})


func _compositor_list_effects(params: Dictionary) -> Dictionary:
	var we := _find_world_env(optional_string(params, "node_path", ""))
	if we == null or we.compositor == null:
		return success({"effects": [], "count": 0})
	var out: Array = []
	for eff in we.compositor.compositor_effects:
		if eff:
			out.append({"class": eff.get_class()})
	return success({"effects": out, "count": out.size()})


func _compositor_clear_effects(params: Dictionary) -> Dictionary:
	var we := _find_world_env(optional_string(params, "node_path", ""))
	if we == null:
		return error_not_found("WorldEnvironment")
	if we.compositor:
		we.compositor.compositor_effects.clear()
	mark_current_scene_unsaved()
	return success({"cleared": true})
