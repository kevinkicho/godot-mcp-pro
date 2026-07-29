@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## OccluderInstance3D / occlusion culling setup for agents.


func get_commands() -> Dictionary:
	return {
		"setup_occluder_instance_3d": _setup_occluder,
		"set_occlusion_culling_project": _set_project,
		"create_box_occluder_3d": _create_box_occluder,
		"list_occlusion_culling_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_occluder_instance_3d", "set_visibility_range", "setup_lod_mesh_instances"],
	})


func _set_project(params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("enabled") or true:
		var en: bool = optional_bool(params, "enabled", true)
		ProjectSettings.set_setting("rendering/occlusion_culling/use_occlusion_culling", en)
		applied["rendering/occlusion_culling/use_occlusion_culling"] = en
	ProjectSettings.save()
	return success({
		"applied": applied,
		"hint": "Add OccluderInstance3D meshes; bake/occluders as needed in editor for complex meshes",
	})


func _create_box_occluder(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists", {"suggestion": "overwrite=true"})
	var occ := BoxOccluder3D.new()
	if params.has("size") and params["size"] is Dictionary:
		var s: Dictionary = params["size"]
		occ.size = Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1)))
	else:
		occ.size = Vector3(
			float(params.get("x", params.get("width", 1))),
			float(params.get("y", params.get("height", 1))),
			float(params.get("z", params.get("depth", 1)))
		)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(occ, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "size": {"x": occ.size.x, "y": occ.size.y, "z": occ.size.z}})


func _setup_occluder(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var oi := OccluderInstance3D.new()
	oi.name = optional_string(params, "name", "OccluderInstance3D")
	var occ_path: String = optional_string(params, "occluder_path", "")
	if not occ_path.is_empty() and ResourceLoader.exists(occ_path):
		var o = load(occ_path)
		if o is Occluder3D:
			oi.occluder = o
	else:
		var box := BoxOccluder3D.new()
		if params.has("size") and params["size"] is Dictionary:
			var s: Dictionary = params["size"]
			box.size = Vector3(float(s.get("x", 2)), float(s.get("y", 2)), float(s.get("z", 2)))
		else:
			box.size = Vector3(2, 2, 2)
		oi.occluder = box
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		oi.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	if params.has("bake_mask"):
		oi.bake_mask = int(params["bake_mask"])
	add_child_with_undo(parent, oi, root, "MCP: OccluderInstance3D")
	if optional_bool(params, "enable_project_occlusion", true):
		ProjectSettings.set_setting("rendering/occlusion_culling/use_occlusion_culling", true)
		ProjectSettings.save()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(oi)),
		"has_occluder": oi.occluder != null,
		"occluder_class": oi.occluder.get_class() if oi.occluder else "",
	})
