@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Decal3D parameter depth for environment dressing.


func get_commands() -> Dictionary:
	return {
		"setup_decal_3d": _setup_decal_3d,
		"set_decal_params": _set_decal_params,
		"list_decal_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_decal", "set_material_3d", "setup_environment"],
	})


func _setup_decal_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var decal := Decal.new()
	decal.name = optional_string(params, "name", "Decal")
	if params.has("size"):
		var s = params["size"]
		if s is Dictionary:
			decal.size = Vector3(float(s.get("x", 2)), float(s.get("y", 2)), float(s.get("z", 2)))
		elif s is Array and s.size() >= 3:
			decal.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
	if params.has("texture_albedo") and ResourceLoader.exists(str(params["texture_albedo"])):
		decal.texture_albedo = load(str(params["texture_albedo"]))
	if params.has("texture_normal") and ResourceLoader.exists(str(params["texture_normal"])):
		decal.texture_normal = load(str(params["texture_normal"]))
	if params.has("albedo_mix"):
		decal.albedo_mix = float(params["albedo_mix"])
	if params.has("modulate"):
		var c := str(params["modulate"])
		decal.modulate = Color.html(c) if c.begins_with("#") else Color(c)
	if params.has("cull_mask"):
		decal.cull_mask = int(params["cull_mask"])
	if params.has("position"):
		var p = params["position"]
		if p is Dictionary:
			decal.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	add_child_with_undo(parent, decal, root, "MCP: Decal")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(decal)), "size": {
		"x": decal.size.x, "y": decal.size.y, "z": decal.size.z,
	}})


func _set_decal_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or not (n is Decal):
		return error_not_found("Decal")
	var d := n as Decal
	var applied := {}
	for k in ["albedo_mix", "normal_fade", "upper_fade", "lower_fade", "emission_energy", "cull_mask", "distance_fade_enabled", "distance_fade_begin", "distance_fade_length"]:
		if params.has(k) and k in d:
			d.set(k, params[k])
			applied[k] = d.get(k)
	if params.has("size"):
		var s = params["size"]
		if s is Dictionary:
			d.size = Vector3(float(s.get("x", d.size.x)), float(s.get("y", d.size.y)), float(s.get("z", d.size.z)))
			applied["size"] = true
	if params.has("modulate"):
		var c := str(params["modulate"])
		d.modulate = Color.html(c) if c.begins_with("#") else Color(c)
		applied["modulate"] = d.modulate.to_html()
	for tex_key in ["texture_albedo", "texture_normal", "texture_orm", "texture_emission"]:
		if params.has(tex_key) and ResourceLoader.exists(str(params[tex_key])):
			d.set(tex_key, load(str(params[tex_key])))
			applied[tex_key] = str(params[tex_key])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})
