@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## VisualShader graph scaffolding — create graph, add common nodes, connect, assign.


func get_commands() -> Dictionary:
	return {
		"create_visual_shader": _create_visual_shader,
		"visual_shader_add_node": _visual_shader_add_node,
		"visual_shader_connect": _visual_shader_connect,
		"visual_shader_set_node_property": _visual_shader_set_node_property,
		"visual_shader_get_info": _visual_shader_get_info,
		"assign_visual_shader_material": _assign_visual_shader_material,
		"visual_shader_add_preset_fresnel": _visual_shader_add_preset_fresnel,
	}


func _create_visual_shader(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not path.ends_with(".tres") and not path.ends_with(".res") and not path.ends_with(".vs"):
		# allow .gdshader mode visual — prefer .tres
		if not path.contains("."):
			path += ".tres"
	var mode_str: String = optional_string(params, "mode", "spatial")
	var vs := VisualShader.new()
	match mode_str:
		"canvas_item", "canvas":
			vs.mode = VisualShader.MODE_CANVAS_ITEM
		"particles":
			vs.mode = VisualShader.MODE_PARTICLES
		"sky":
			vs.mode = VisualShader.MODE_SKY
		_:
			vs.mode = VisualShader.MODE_SPATIAL
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(vs, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"mode": mode_str,
		"type": "VisualShader",
		"hint": "Use visual_shader_add_node + visual_shader_connect; open in editor for full graph UI",
	})


func _load_vs(path: String) -> VisualShader:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as VisualShader


func _type_name_to_class(type_name: String) -> String:
	## Map short names → VisualShaderNode* class names
	var t := type_name
	if t.begins_with("VisualShaderNode"):
		return t
	var map := {
		"input": "VisualShaderNodeInput",
		"output": "VisualShaderNodeOutput",
		"color": "VisualShaderNodeColorConstant",
		"color_constant": "VisualShaderNodeColorConstant",
		"color_op": "VisualShaderNodeColorOp",
		"float": "VisualShaderNodeFloatConstant",
		"float_constant": "VisualShaderNodeFloatConstant",
		"float_op": "VisualShaderNodeFloatOp",
		"vec3": "VisualShaderNodeVec3Constant",
		"vec3_constant": "VisualShaderNodeVec3Constant",
		"vec3_op": "VisualShaderNodeVectorOp",
		"vector_op": "VisualShaderNodeVectorOp",
		"texture": "VisualShaderNodeTexture",
		"texture2d": "VisualShaderNodeTexture",
		"fresnel": "VisualShaderNodeFresnel",
		"dot": "VisualShaderNodeDotProduct",
		"mix": "VisualShaderNodeMix",
		"clamp": "VisualShaderNodeClamp",
		"smoothstep": "VisualShaderNodeSmoothStep",
		"time": "VisualShaderNodeInput",  # TIME input
		"uv": "VisualShaderNodeInput",
		"normal": "VisualShaderNodeInput",
		"float_func": "VisualShaderNodeFloatFunc",
		"vector_func": "VisualShaderNodeVectorFunc",
		"scalar_op": "VisualShaderNodeFloatOp",
		"comment": "VisualShaderNodeComment",
		"group": "VisualShaderNodeGroupBase",
		"expression": "VisualShaderNodeExpression",
		"parameter": "VisualShaderNodeFloatParameter",
		"float_param": "VisualShaderNodeFloatParameter",
		"color_param": "VisualShaderNodeColorParameter",
		"texture_param": "VisualShaderNodeTexture2DParameter",
	}
	var key := t.to_lower()
	if map.has(key):
		return map[key]
	# Try prefix
	var guess := "VisualShaderNode" + t.capitalize().replace(" ", "")
	if ClassDB.class_exists(guess):
		return guess
	return t


func _visual_shader_add_node(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var type_r := require_string(params, "node_type")
	if type_r[1] != null:
		return type_r[1]
	var vs := _load_vs(res[0])
	if vs == null:
		return error_not_found("VisualShader at %s" % res[0])
	var class_name_str := _type_name_to_class(type_r[0])
	if not ClassDB.class_exists(class_name_str) or not ClassDB.can_instantiate(class_name_str):
		return error_invalid_params("Unknown VisualShader node type: %s (resolved %s)" % [type_r[0], class_name_str])
	var node: VisualShaderNode = ClassDB.instantiate(class_name_str) as VisualShaderNode
	if node == null:
		return error_internal("Failed to instantiate %s" % class_name_str)
	# Common property setup
	if node is VisualShaderNodeInput:
		var input_name: String = optional_string(params, "input_name", optional_string(params, "input", ""))
		if not input_name.is_empty():
			(node as VisualShaderNodeInput).input_name = input_name
	if node is VisualShaderNodeFloatConstant and params.has("value"):
		(node as VisualShaderNodeFloatConstant).constant = float(params["value"])
	if node is VisualShaderNodeColorConstant and params.has("color"):
		var c = params["color"]
		if c is String:
			(node as VisualShaderNodeColorConstant).constant = Color.html(c) if str(c).begins_with("#") else Color(c)
		elif c is Dictionary:
			(node as VisualShaderNodeColorConstant).constant = Color(
				float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1))
			)
	if node is VisualShaderNodeVec3Constant and params.has("value"):
		var v = params["value"]
		if v is Dictionary:
			(node as VisualShaderNodeVec3Constant).constant = Vector3(
				float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0))
			)
	var type_id: int = optional_int(params, "graph_type", VisualShader.TYPE_FRAGMENT)
	# Godot 4: TYPE_VERTEX=0, TYPE_FRAGMENT=1, TYPE_LIGHT=2, ...
	var gtype_str: String = optional_string(params, "graph", "fragment")
	match gtype_str:
		"vertex":
			type_id = VisualShader.TYPE_VERTEX
		"light":
			type_id = VisualShader.TYPE_LIGHT
		_:
			type_id = VisualShader.TYPE_FRAGMENT
	var pos := Vector2(float(params.get("x", 0)), float(params.get("y", 0)))
	var node_id: int = int(params.get("id", -1))
	if node_id < 0:
		# Auto id: find free
		node_id = 2
		while vs.has_node(type_id, node_id):
			node_id += 1
	vs.add_node(type_id, node, pos, node_id)
	var err := ResourceSaver.save(vs, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"node_id": node_id,
		"node_type": class_name_str,
		"graph": gtype_str,
		"position": {"x": pos.x, "y": pos.y},
	})


func _visual_shader_connect(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var vs := _load_vs(res[0])
	if vs == null:
		return error_not_found("VisualShader")
	var gtype_str: String = optional_string(params, "graph", "fragment")
	var type_id := VisualShader.TYPE_FRAGMENT
	match gtype_str:
		"vertex": type_id = VisualShader.TYPE_VERTEX
		"light": type_id = VisualShader.TYPE_LIGHT
		_: type_id = VisualShader.TYPE_FRAGMENT
	var from_node: int = int(params.get("from_node", params.get("from", -1)))
	var to_node: int = int(params.get("to_node", params.get("to", -1)))
	var from_port: int = int(params.get("from_port", 0))
	var to_port: int = int(params.get("to_port", 0))
	if from_node < 0 or to_node < 0:
		return error_invalid_params("from_node and to_node required")
	# Output node is typically id 0 in VisualShader
	vs.connect_nodes(type_id, from_node, from_port, to_node, to_port)
	var err := ResourceSaver.save(vs, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"from_node": from_node,
		"from_port": from_port,
		"to_node": to_node,
		"to_port": to_port,
		"graph": gtype_str,
	})


func _visual_shader_set_node_property(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var vs := _load_vs(res[0])
	if vs == null:
		return error_not_found("VisualShader")
	var node_id: int = int(params.get("node_id", -1))
	var prop_r := require_string(params, "property")
	if prop_r[1] != null:
		return prop_r[1]
	if not params.has("value"):
		return error_invalid_params("value required")
	var gtype_str: String = optional_string(params, "graph", "fragment")
	var type_id := VisualShader.TYPE_FRAGMENT
	match gtype_str:
		"vertex": type_id = VisualShader.TYPE_VERTEX
		"light": type_id = VisualShader.TYPE_LIGHT
		_: type_id = VisualShader.TYPE_FRAGMENT
	if not vs.has_node(type_id, node_id):
		return error_not_found("Node id %d" % node_id)
	var node: VisualShaderNode = vs.get_node(type_id, node_id)
	if node == null or not prop_r[0] in node:
		return error_invalid_params("Property '%s' not on node" % prop_r[0])
	node.set(prop_r[0], params["value"])
	var err := ResourceSaver.save(vs, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"node_id": node_id, "property": prop_r[0], "value": str(params["value"])})


func _visual_shader_get_info(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var vs := _load_vs(res[0])
	if vs == null:
		return error_not_found("VisualShader")
	var graphs: Array = []
	for type_id in [VisualShader.TYPE_VERTEX, VisualShader.TYPE_FRAGMENT, VisualShader.TYPE_LIGHT]:
		var nodes: Array = []
		var list: PackedInt32Array = vs.get_node_list(type_id)
		for id in list:
			var n: VisualShaderNode = vs.get_node(type_id, id)
			var pos: Vector2 = vs.get_node_position(type_id, id)
			nodes.append({
				"id": id,
				"class": n.get_class() if n else "null",
				"position": {"x": pos.x, "y": pos.y},
			})
		var conns: Array = []
		# get_node_connections if available
		if vs.has_method("get_node_connections"):
			var clist = vs.get_node_connections(type_id)
			if clist is Array:
				for c in clist:
					if c is Dictionary:
						conns.append(c)
		graphs.append({
			"type_id": type_id,
			"nodes": nodes,
			"node_count": nodes.size(),
			"connections": conns,
		})
	return success({
		"path": res[0],
		"mode": vs.mode,
		"graphs": graphs,
	})


func _assign_visual_shader_material(params: Dictionary) -> Dictionary:
	var node_r := require_string(params, "node_path")
	if node_r[1] != null:
		return node_r[1]
	var sh_r := require_res_path(params, "shader_path")
	if sh_r[1] != null:
		return sh_r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_r[0])
	if node == null:
		return error_not_found("Node")
	var vs := _load_vs(sh_r[0])
	if vs == null:
		return error_not_found("VisualShader")
	var mat := ShaderMaterial.new()
	mat.shader = vs
	var prop: String = optional_string(params, "property", "")
	if prop.is_empty():
		if node is CanvasItem:
			prop = "material"
		elif node is GeometryInstance3D or node is MeshInstance3D:
			prop = "material_override"
		else:
			prop = "material"
	if not prop in node:
		return error_invalid_params("Node has no property '%s'" % prop)
	var undo := get_undo_redo()
	undo.create_action("MCP: Assign VisualShader material")
	undo.add_do_property(node, prop, mat)
	undo.add_do_reference(mat)
	undo.add_undo_property(node, prop, node.get(prop))
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({"node_path": node_r[0], "shader_path": sh_r[0], "property": prop})


func _visual_shader_add_preset_fresnel(params: Dictionary) -> Dictionary:
	## Quick fresnel edge highlight graph on fragment: Fresnel → ALBEDO-ish via color mix.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	# Ensure file exists
	if not ResourceLoader.exists(res[0]):
		var cr := _create_visual_shader({"path": res[0], "mode": optional_string(params, "mode", "spatial")})
		if cr.has("error"):
			return cr
	var vs := _load_vs(res[0])
	if vs == null:
		return error_internal("Failed to load VisualShader")
	var type_id := VisualShader.TYPE_FRAGMENT
	# ids: 10 fresnel, 11 color, 12 float power
	var fresnel: VisualShaderNode = ClassDB.instantiate("VisualShaderNodeFresnel")
	var color_c: VisualShaderNodeColorConstant = VisualShaderNodeColorConstant.new()
	color_c.constant = Color(0.2, 0.6, 1.0)
	var power: VisualShaderNodeFloatConstant = VisualShaderNodeFloatConstant.new()
	power.constant = float(params.get("power", 3.0))
	var next_id := 10
	while vs.has_node(type_id, next_id):
		next_id += 1
	var id_fresnel := next_id
	var id_color := next_id + 1
	var id_power := next_id + 2
	vs.add_node(type_id, fresnel, Vector2(-300, 0), id_fresnel)
	vs.add_node(type_id, color_c, Vector2(-300, 160), id_color)
	vs.add_node(type_id, power, Vector2(-500, 0), id_power)
	# Connect fresnel output to OUTPUT albedo if possible (output node is usually 0)
	# Port indices vary by Godot version — try connect and ignore failure
	vs.connect_nodes(type_id, id_fresnel, 0, 0, 0)  # may map to albedo
	var err := ResourceSaver.save(vs, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"nodes_added": [id_fresnel, id_color, id_power],
		"preset": "fresnel",
		"hint": "Open VisualShader editor to fine-tune ports; connect Fresnel to Emission/Albedo as needed",
	})
