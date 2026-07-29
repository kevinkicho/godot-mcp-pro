@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## VisualShader common presets beyond fresnel (Wave 6).


func get_commands() -> Dictionary:
	return {
		"visual_shader_add_preset_pbr": _preset_pbr,
		"visual_shader_add_preset_unshaded_color": _preset_unshaded,
		"visual_shader_add_preset_dissolve": _preset_dissolve,
		"visual_shader_list_node_types": _list_node_types,
		"list_visual_shader_preset_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_visual_shader", "visual_shader_add_node", "visual_shader_connect", "assign_visual_shader_material"],
	})


func _list_node_types(_params: Dictionary) -> Dictionary:
	return success({
		"common_types": [
			"input", "output", "color", "float", "vec3", "texture", "fresnel",
			"float_op", "vector_op", "color_op", "mix", "smoothstep", "clamp",
			"time", "uv", "normal", "roughness", "metallic",
		],
		"hint": "Pass type to visual_shader_add_node; ClassDB VisualShaderNode* for long tail",
	})


func _load_vs(path: String) -> VisualShader:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as VisualShader


func _save_vs(vs: VisualShader, path: String) -> Error:
	return ResourceSaver.save(vs, path)


func _add_node(vs: VisualShader, class_name_str: String, pos: Vector2) -> int:
	if not ClassDB.class_exists(class_name_str):
		return -1
	var node = ClassDB.instantiate(class_name_str)
	if node == null:
		return -1
	var id := vs.get_valid_node_id()
	vs.add_node(VisualShader.TYPE_FRAGMENT, node, pos, id)
	return id


func _preset_pbr(params: Dictionary) -> Dictionary:
	## Rough PBR fragment: albedo color + metallic/roughness floats -> output.
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var vs := _load_vs(path_r[0])
	if vs == null:
		return error_not_found("VisualShader")
	var ids := {}
	ids["albedo"] = _add_node(vs, "VisualShaderNodeColorConstant", Vector2(0, 0))
	ids["metallic"] = _add_node(vs, "VisualShaderNodeFloatConstant", Vector2(0, 120))
	ids["roughness"] = _add_node(vs, "VisualShaderNodeFloatConstant", Vector2(0, 240))
	# Set defaults if possible
	var alb = vs.get_node(VisualShader.TYPE_FRAGMENT, ids["albedo"])
	if alb and "constant" in alb:
		alb.set("constant", Color(0.8, 0.8, 0.8))
	var met = vs.get_node(VisualShader.TYPE_FRAGMENT, ids["metallic"])
	if met and "constant" in met:
		met.set("constant", float(params.get("metallic", 0.0)))
	var rou = vs.get_node(VisualShader.TYPE_FRAGMENT, ids["roughness"])
	if rou and "constant" in rou:
		rou.set("constant", float(params.get("roughness", 0.5)))
	# Connect to output ports if API allows - port names vary; best-effort
	var out_id := VisualShader.NODE_OUTPUT
	if ids["albedo"] >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, ids["albedo"], 0, out_id, 0)  # often Albedo
	if ids["metallic"] >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, ids["metallic"], 0, out_id, 2)
	if ids["roughness"] >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, ids["roughness"], 0, out_id, 3)
	var err := _save_vs(vs, path_r[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": path_r[0],
		"preset": "pbr_basic",
		"node_ids": ids,
		"hint": "Open VisualShader editor to verify port wiring; ports vary by Godot version",
	})


func _preset_unshaded(params: Dictionary) -> Dictionary:
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var vs := _load_vs(path_r[0])
	if vs == null:
		return error_not_found("VisualShader")
	var cid := _add_node(vs, "VisualShaderNodeColorConstant", Vector2(0, 0))
	var node = vs.get_node(VisualShader.TYPE_FRAGMENT, cid)
	if node and "constant" in node:
		var c := str(params.get("color", "#ffffff"))
		node.set("constant", Color.html(c) if c.begins_with("#") else Color(c))
	vs.connect_nodes(VisualShader.TYPE_FRAGMENT, cid, 0, VisualShader.NODE_OUTPUT, 0)
	_save_vs(vs, path_r[0])
	return success({"path": path_r[0], "preset": "unshaded_color", "color_node": cid})


func _preset_dissolve(params: Dictionary) -> Dictionary:
	## Time + noise-ish float op scaffold (simplified).
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var vs := _load_vs(path_r[0])
	if vs == null:
		return error_not_found("VisualShader")
	var ids := {
		"time": _add_node(vs, "VisualShaderNodeInput", Vector2(-200, 0)),
		"threshold": _add_node(vs, "VisualShaderNodeFloatConstant", Vector2(-200, 150)),
		"cmp": _add_node(vs, "VisualShaderNodeCompare", Vector2(0, 50)),
	}
	var thr = vs.get_node(VisualShader.TYPE_FRAGMENT, ids["threshold"])
	if thr and "constant" in thr:
		thr.set("constant", float(params.get("threshold", 0.5)))
	var inp = vs.get_node(VisualShader.TYPE_FRAGMENT, ids["time"])
	if inp and "input_name" in inp:
		inp.set("input_name", "time")
	_save_vs(vs, path_r[0])
	return success({
		"path": path_r[0],
		"preset": "dissolve_scaffold",
		"node_ids": ids,
		"hint": "Wire compare to ALPHA clip in editor; scaffold only",
	})
