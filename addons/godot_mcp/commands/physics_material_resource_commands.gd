@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## PhysicsMaterial resources — friction/bounce shared across bodies.


func get_commands() -> Dictionary:
	return {
		"create_physics_material": _create,
		"assign_physics_material": _assign,
		"list_physics_material_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["set_physics_material", "setup_physics_body", "create_shape_resource"],
	})


func _create(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists", {"suggestion": "overwrite=true"})
	var mat := PhysicsMaterial.new()
	if params.has("friction"):
		mat.friction = float(params["friction"])
	if params.has("rough"):
		mat.rough = bool(params["rough"])
	if params.has("bounce"):
		mat.bounce = float(params["bounce"])
	if params.has("absorbent"):
		mat.absorbent = bool(params["absorbent"])
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(mat, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"friction": mat.friction,
		"bounce": mat.bounce,
		"rough": mat.rough,
		"absorbent": mat.absorbent,
	})


func _assign(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var mat_r := require_res_path(params, "material_path")
	if mat_r[1] != null:
		return mat_r[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not ResourceLoader.exists(mat_r[0]):
		return error_not_found(mat_r[0])
	var mat = load(mat_r[0])
	if not (mat is PhysicsMaterial):
		return error_internal("Not PhysicsMaterial")
	if "physics_material_override" in node:
		node.set("physics_material_override", mat)
	elif "physics_material" in node:
		node.set("physics_material", mat)
	else:
		return error_invalid_params("Node has no physics_material(_override) — StaticBody/RigidBody/etc.")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "material_path": mat_r[0]})
