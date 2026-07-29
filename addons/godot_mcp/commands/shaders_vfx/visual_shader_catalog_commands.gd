@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## VisualShader catalog + agent-friendly graph recipes (beyond basic presets).


func get_commands() -> Dictionary:
	return {
		"list_visual_shader_node_catalog": _list_catalog,
		"visual_shader_add_nodes_batch": _add_nodes_batch,
		"visual_shader_preset_toon": _preset_toon,
		"visual_shader_preset_emission_pulse": _preset_pulse,
		"visual_shader_preset_scroll_uv": _preset_scroll,
		"visual_shader_preset_triplanar": _preset_triplanar,
		"visual_shader_preset_outline_fresnel": _preset_outline,
		"list_visual_shader_catalog_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"create_visual_shader", "visual_shader_add_node", "visual_shader_connect",
			"visual_shader_add_preset_pbr", "assign_visual_shader_material",
		],
	})


func _list_catalog(_params: Dictionary) -> Dictionary:
	## Map friendly names → ClassDB type for agents.
	var catalog := {
		"constants": {
			"float_constant": "VisualShaderNodeFloatConstant",
			"int_constant": "VisualShaderNodeIntConstant",
			"vec2_constant": "VisualShaderNodeVec2Constant",
			"vec3_constant": "VisualShaderNodeVec3Constant",
			"vec4_constant": "VisualShaderNodeVec4Constant",
			"color_constant": "VisualShaderNodeColorConstant",
			"boolean_constant": "VisualShaderNodeBooleanConstant",
		},
		"ops": {
			"float_op": "VisualShaderNodeFloatOp",
			"vector_op": "VisualShaderNodeVectorOp",
			"color_op": "VisualShaderNodeColorOp",
			"int_op": "VisualShaderNodeIntOp",
			"transform_op": "VisualShaderNodeTransformOp",
			"compare": "VisualShaderNodeCompare",
			"switch": "VisualShaderNodeSwitch",
		},
		"funcs": {
			"float_func": "VisualShaderNodeFloatFunc",
			"vector_func": "VisualShaderNodeVectorFunc",
			"color_func": "VisualShaderNodeColorFunc",
			"clamp": "VisualShaderNodeClamp",
			"mix": "VisualShaderNodeMix",
			"smoothstep": "VisualShaderNodeSmoothStep",
			"step": "VisualShaderNodeStep",
			"remap": "VisualShaderNodeRemap",
			"dot": "VisualShaderNodeDotProduct",
			"fresnel": "VisualShaderNodeFresnel",
			"faceforward": "VisualShaderNodeFaceForward",
			"refract": "VisualShaderNodeRefract",
			"derivative_func": "VisualShaderNodeDerivativeFunc",
		},
		"inputs": {
			"input": "VisualShaderNodeInput",
			"uv": "VisualShaderNodeInput",
			"time": "VisualShaderNodeInput",
			"normal": "VisualShaderNodeInput",
			"vertex": "VisualShaderNodeInput",
			"color": "VisualShaderNodeInput",
		},
		"textures": {
			"texture": "VisualShaderNodeTexture",
			"texture2d": "VisualShaderNodeTexture",
			"cubemap": "VisualShaderNodeCubemap",
			"texture3d": "VisualShaderNodeTexture3D",
			"curve_texture": "VisualShaderNodeCurveTexture",
			"sample3d": "VisualShaderNodeSample3D",
		},
		"vector": {
			"vector_compose": "VisualShaderNodeVectorCompose",
			"vector_decompose": "VisualShaderNodeVectorDecompose",
			"vector_len": "VisualShaderNodeVectorLen",
			"vector_distance": "VisualShaderNodeVectorDistance",
			"outer_product": "VisualShaderNodeOuterProduct",
		},
		"utility": {
			"output": "VisualShaderNodeOutput",
			"expression": "VisualShaderNodeExpression",
			"global_expression": "VisualShaderNodeGlobalExpression",
			"parameter": "VisualShaderNodeParameter",
			"parameter_ref": "VisualShaderNodeParameterRef",
			"comment": "VisualShaderNodeComment",
			"frame": "VisualShaderNodeFrame",
			"group": "VisualShaderNodeGroupBase",
			"custom": "VisualShaderNodeCustom",
		},
	}
	# Also scan ClassDB for VisualShaderNode*
	var classdb_nodes: Array = []
	if ClassDB.class_exists("VisualShaderNode"):
		for c in ClassDB.get_class_list():
			if str(c).begins_with("VisualShaderNode") and str(c) != "VisualShaderNode":
				classdb_nodes.append(str(c))
	classdb_nodes.sort()
	return success({
		"catalog": catalog,
		"classdb_visual_shader_nodes": classdb_nodes,
		"classdb_count": classdb_nodes.size(),
		"usage": "visual_shader_add_node path=… type=float_op|VisualShaderNodeFloatOp",
		"presets": [
			"visual_shader_preset_toon",
			"visual_shader_preset_emission_pulse",
			"visual_shader_preset_scroll_uv",
			"visual_shader_preset_triplanar",
			"visual_shader_preset_outline_fresnel",
			"visual_shader_add_preset_pbr",
			"visual_shader_add_preset_unshaded_color",
			"visual_shader_add_preset_dissolve",
		],
	})


func _resolve_type(type_name: String) -> String:
	var t := type_name.strip_edges()
	if ClassDB.class_exists(t):
		return t
	var map := {
		"float": "VisualShaderNodeFloatConstant",
		"float_constant": "VisualShaderNodeFloatConstant",
		"float_op": "VisualShaderNodeFloatOp",
		"float_func": "VisualShaderNodeFloatFunc",
		"vec3": "VisualShaderNodeVec3Constant",
		"vec3_op": "VisualShaderNodeVectorOp",
		"vector_op": "VisualShaderNodeVectorOp",
		"vector_func": "VisualShaderNodeVectorFunc",
		"color": "VisualShaderNodeColorConstant",
		"color_op": "VisualShaderNodeColorOp",
		"mix": "VisualShaderNodeMix",
		"clamp": "VisualShaderNodeClamp",
		"fresnel": "VisualShaderNodeFresnel",
		"dot": "VisualShaderNodeDotProduct",
		"texture": "VisualShaderNodeTexture",
		"input": "VisualShaderNodeInput",
		"output": "VisualShaderNodeOutput",
		"time": "VisualShaderNodeInput",
		"uv": "VisualShaderNodeInput",
		"compare": "VisualShaderNodeCompare",
		"smoothstep": "VisualShaderNodeSmoothStep",
		"vector_compose": "VisualShaderNodeVectorCompose",
		"vector_decompose": "VisualShaderNodeVectorDecompose",
		"expression": "VisualShaderNodeExpression",
		"parameter": "VisualShaderNodeParameter",
	}
	var key := t.to_lower()
	if map.has(key):
		return map[key]
	# Try prefix
	var guess := "VisualShaderNode" + t.capitalize().replace(" ", "")
	if ClassDB.class_exists(guess):
		return guess
	return t


func _load_vs(path: String) -> Array:
	if not ResourceLoader.exists(path):
		return [null, error_not_found(path)]
	var r = load(path)
	if not (r is VisualShader):
		return [null, error_internal("Not a VisualShader")]
	return [r as VisualShader, null]


func _add_node(vs: VisualShader, type_name: String, pos: Vector2) -> int:
	var cls := _resolve_type(type_name)
	if not ClassDB.class_exists(cls):
		return -1
	var node: VisualShaderNode = ClassDB.instantiate(cls)
	if node == null:
		return -1
	# Common input name setup
	if cls == "VisualShaderNodeInput" and type_name.to_lower() in ["time", "uv", "normal", "vertex", "color"]:
		var iname := type_name.to_upper() if type_name.to_lower() != "uv" else "UV"
		if type_name.to_lower() == "time":
			iname = "TIME"
		if "input_name" in node:
			node.set("input_name", iname)
	var id: int = vs.get_valid_node_id()
	vs.add_node(VisualShader.TYPE_FRAGMENT, node, pos, id)
	return id


func _add_nodes_batch(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var loaded := _load_vs(res[0])
	if loaded[1] != null:
		return loaded[1]
	var vs: VisualShader = loaded[0]
	if not params.has("nodes") or not (params["nodes"] is Array):
		return error_invalid_params("nodes: [{type, x, y, id?}] required")
	var created: Array = []
	for item in params["nodes"]:
		if not item is Dictionary:
			continue
		var type_n: String = str(item.get("type", "float"))
		var pos := Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
		var id := _add_node(vs, type_n, pos)
		if id >= 0:
			created.append({"id": id, "type": _resolve_type(type_n)})
			if item.has("properties") and item["properties"] is Dictionary:
				var node: VisualShaderNode = vs.get_node(VisualShader.TYPE_FRAGMENT, id)
				if node:
					for pk in item["properties"]:
						if str(pk) in node:
							node.set(str(pk), item["properties"][pk])
	# Optional connections: [{from_id, from_port, to_id, to_port}]
	var connections: Array = []
	if params.has("connections") and params["connections"] is Array:
		for c in params["connections"]:
			if not c is Dictionary:
				continue
			var from_id := int(c.get("from_id", c.get("from", -1)))
			var to_id := int(c.get("to_id", c.get("to", -1)))
			var from_port := int(c.get("from_port", 0))
			var to_port := int(c.get("to_port", 0))
			if from_id >= 0 and to_id >= 0:
				vs.connect_nodes(VisualShader.TYPE_FRAGMENT, from_id, from_port, to_id, to_port)
				connections.append(c)
	var err := ResourceSaver.save(vs, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"nodes_added": created,
		"connections": connections.size(),
	})


func _save_vs(vs: VisualShader, path: String) -> Dictionary:
	var err := ResourceSaver.save(vs, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return {}


func _ensure_vs(params: Dictionary) -> Array:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res
	var path: String = res[0]
	if ResourceLoader.exists(path):
		var loaded := _load_vs(path)
		return [path, loaded[0], loaded[1]]
	var vs := VisualShader.new()
	vs.set_mode(VisualShader.MODE_SPATIAL)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return [null, null, derr]
	ResourceSaver.save(vs, path)
	return [path, vs, null]


func _preset_toon(params: Dictionary) -> Dictionary:
	var e := _ensure_vs(params)
	if e[2] != null:
		return e[2]
	var path: String = e[0]
	var vs: VisualShader = e[1]
	var albedo := _add_node(vs, "color_constant", Vector2(-300, 0))
	var steps := _add_node(vs, "float_constant", Vector2(-300, 120))
	var n := _add_node(vs, "input", Vector2(-300, 240))
	# set normal input
	var nnode = vs.get_node(VisualShader.TYPE_FRAGMENT, n)
	if nnode and "input_name" in nnode:
		nnode.set("input_name", "NORMAL")
	var light_dir := _add_node(vs, "vec3", Vector2(-300, 360))
	var dotn := _add_node(vs, "dot", Vector2(-100, 200))
	var clampn := _add_node(vs, "clamp", Vector2(50, 200))
	var mul := _add_node(vs, "vector_op", Vector2(200, 50))
	# Wire what we can; agents refine in editor
	if albedo >= 0 and mul >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, albedo, 0, mul, 0)
	if n >= 0 and light_dir >= 0 and dotn >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, n, 0, dotn, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, light_dir, 0, dotn, 1)
	if dotn >= 0 and clampn >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, dotn, 0, clampn, 0)
	var se := _save_vs(vs, path)
	if not se.is_empty():
		return se
	return success({
		"path": path,
		"preset": "toon_scaffold",
		"nodes": {"albedo": albedo, "steps": steps, "normal": n, "light_dir": light_dir, "dot": dotn, "clamp": clampn, "mul": mul},
		"hint": "Connect clamp→vector mul B and mul→ALBEDO; tune light_dir constant",
	})


func _preset_pulse(params: Dictionary) -> Dictionary:
	var e := _ensure_vs(params)
	if e[2] != null:
		return e[2]
	var path: String = e[0]
	var vs: VisualShader = e[1]
	var time_id := _add_node(vs, "time", Vector2(-300, 0))
	var speed := _add_node(vs, "float_constant", Vector2(-300, 100))
	var mul := _add_node(vs, "float_op", Vector2(-100, 50))
	var sinf := _add_node(vs, "float_func", Vector2(50, 50))
	var emit_col := _add_node(vs, "color_constant", Vector2(-100, 200))
	var mulc := _add_node(vs, "vector_op", Vector2(200, 100))
	if time_id >= 0 and speed >= 0 and mul >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, time_id, 0, mul, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, speed, 0, mul, 1)
	if mul >= 0 and sinf >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, mul, 0, sinf, 0)
		var snode = vs.get_node(VisualShader.TYPE_FRAGMENT, sinf)
		if snode and "function" in snode:
			# SIN = often enum 0 or named
			pass
	if emit_col >= 0 and sinf >= 0 and mulc >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, emit_col, 0, mulc, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, sinf, 0, mulc, 1)
	var se := _save_vs(vs, path)
	if not se.is_empty():
		return se
	return success({
		"path": path,
		"preset": "emission_pulse",
		"hint": "Wire mulc to EMISSION; set float_func to sin; enable emission on material",
	})


func _preset_scroll(params: Dictionary) -> Dictionary:
	var e := _ensure_vs(params)
	if e[2] != null:
		return e[2]
	var path: String = e[0]
	var vs: VisualShader = e[1]
	var uv := _add_node(vs, "uv", Vector2(-300, 0))
	var time_id := _add_node(vs, "time", Vector2(-300, 120))
	var speed := _add_node(vs, "vec3", Vector2(-300, 240))
	var mul := _add_node(vs, "vector_op", Vector2(-100, 150))
	var addv := _add_node(vs, "vector_op", Vector2(50, 50))
	var tex := _add_node(vs, "texture", Vector2(200, 50))
	if time_id >= 0 and speed >= 0 and mul >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, time_id, 0, mul, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, speed, 0, mul, 1)
	if uv >= 0 and mul >= 0 and addv >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, uv, 0, addv, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, mul, 0, addv, 1)
	if addv >= 0 and tex >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, addv, 0, tex, 0)
	var se := _save_vs(vs, path)
	if not se.is_empty():
		return se
	return success({
		"path": path,
		"preset": "scroll_uv",
		"nodes": {"uv": uv, "time": time_id, "speed": speed, "texture": tex},
		"hint": "Assign texture sampler; connect texture output to ALBEDO",
	})


func _preset_triplanar(params: Dictionary) -> Dictionary:
	var e := _ensure_vs(params)
	if e[2] != null:
		return e[2]
	var path: String = e[0]
	var vs: VisualShader = e[1]
	# Scaffold: vertex/world pos inputs + three texture samples comment
	var vertex := _add_node(vs, "input", Vector2(-300, 0))
	var vnode = vs.get_node(VisualShader.TYPE_FRAGMENT, vertex)
	if vnode and "input_name" in vnode:
		vnode.set("input_name", "VERTEX")
	var tex_x := _add_node(vs, "texture", Vector2(0, -100))
	var tex_y := _add_node(vs, "texture", Vector2(0, 50))
	var tex_z := _add_node(vs, "texture", Vector2(0, 200))
	var mix1 := _add_node(vs, "mix", Vector2(200, 50))
	var comment := _add_node(vs, "comment", Vector2(-300, 300))
	var se := _save_vs(vs, path)
	if not se.is_empty():
		return se
	return success({
		"path": path,
		"preset": "triplanar_scaffold",
		"nodes": {"vertex": vertex, "tex_x": tex_x, "tex_y": tex_y, "tex_z": tex_z, "mix": mix1},
		"hint": "Complete triplanar blend with world normal weights in editor or Expression node",
	})


func _preset_outline(params: Dictionary) -> Dictionary:
	var e := _ensure_vs(params)
	if e[2] != null:
		return e[2]
	var path: String = e[0]
	var vs: VisualShader = e[1]
	var fresnel := _add_node(vs, "fresnel", Vector2(-100, 0))
	var power := _add_node(vs, "float_constant", Vector2(-300, 0))
	var outline_col := _add_node(vs, "color_constant", Vector2(-100, 150))
	var mul := _add_node(vs, "vector_op", Vector2(100, 50))
	if fresnel >= 0 and power >= 0:
		# fresnel often has power port
		pass
	if fresnel >= 0 and outline_col >= 0 and mul >= 0:
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, outline_col, 0, mul, 0)
		vs.connect_nodes(VisualShader.TYPE_FRAGMENT, fresnel, 0, mul, 1)
	var se := _save_vs(vs, path)
	if not se.is_empty():
		return se
	return success({
		"path": path,
		"preset": "outline_fresnel",
		"hint": "Connect mul to EMISSION or ALBEDO; tune fresnel power; inverted hull outline needs second pass/mesh",
	})
