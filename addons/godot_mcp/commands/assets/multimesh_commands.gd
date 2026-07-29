@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## MultiMesh bulk placement — large prop fields without thousands of nodes.


func get_commands() -> Dictionary:
	return {
		"setup_multimesh_instance": _setup_multimesh_instance,
		"multimesh_set_transforms": _multimesh_set_transforms,
		"multimesh_scatter": _multimesh_scatter,
		"multimesh_get_info": _multimesh_get_info,
	}


func _setup_multimesh_instance(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = optional_string(params, "name", "MultiMeshInstance3D")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var count: int = clampi(optional_int(params, "instance_count", 10), 1, 100000)
	mm.instance_count = count
	# Mesh
	var mesh_path: String = optional_string(params, "mesh_path", "")
	if not mesh_path.is_empty():
		if not mesh_path.begins_with("res://"):
			mesh_path = "res://" + mesh_path.trim_prefix("/")
		if ResourceLoader.exists(mesh_path):
			var m = load(mesh_path)
			if m is Mesh:
				mm.mesh = m
	if mm.mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(
			float(params.get("box_x", 0.5)),
			float(params.get("box_y", 0.5)),
			float(params.get("box_z", 0.5))
		)
		mm.mesh = box
	mmi.multimesh = mm
	add_child_with_undo(parent, mmi, root, "MCP: MultiMesh")
	# Identity transforms
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(i * 1.0, 0, 0)))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(mmi)),
		"instance_count": count,
		"mesh": mm.mesh.get_class() if mm.mesh else "",
	})


func _multimesh_set_transforms(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MultiMeshInstance3D):
		return error_not_found("MultiMeshInstance3D")
	var mmi: MultiMeshInstance3D = node
	var mm: MultiMesh = mmi.multimesh
	if mm == null:
		return error_internal("No MultiMesh resource")
	var transforms: Array = params.get("transforms", params.get("positions", []))
	if not transforms is Array or transforms.is_empty():
		return error_invalid_params("transforms/positions array required")
	if mm.instance_count < transforms.size():
		mm.instance_count = transforms.size()
	var n := 0
	for i in transforms.size():
		var t: Transform3D = Transform3D.IDENTITY
		var item = transforms[i]
		if item is Dictionary:
			var pos := Vector3(float(item.get("x", 0)), float(item.get("y", 0)), float(item.get("z", 0)))
			var yaw := float(item.get("yaw", item.get("rotation_y", 0)))
			var basis := Basis(Vector3.UP, deg_to_rad(yaw))
			if item.has("scale"):
				var s = item["scale"]
				if s is Dictionary:
					basis = basis.scaled(Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1))))
				else:
					basis = basis.scaled(Vector3.ONE * float(s))
			t = Transform3D(basis, pos)
		elif item is Array and item.size() >= 3:
			t = Transform3D(Basis.IDENTITY, Vector3(float(item[0]), float(item[1]), float(item[2])))
		mm.set_instance_transform(i, t)
		n += 1
	mark_current_scene_unsaved()
	return success({"updated": n, "instance_count": mm.instance_count})


func _multimesh_scatter(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MultiMeshInstance3D):
		return error_not_found("MultiMeshInstance3D — call setup_multimesh_instance first")
	var mmi: MultiMeshInstance3D = node
	var mm: MultiMesh = mmi.multimesh
	if mm == null:
		return error_internal("No MultiMesh")
	var count: int = clampi(optional_int(params, "count", mm.instance_count), 1, 100000)
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = optional_int(params, "seed", 1)
	var min_p := Vector3(float(params.get("min_x", -10)), float(params.get("min_y", 0)), float(params.get("min_z", -10)))
	var max_p := Vector3(float(params.get("max_x", 10)), float(params.get("max_y", 0)), float(params.get("max_z", 10)))
	for i in count:
		var pos := Vector3(
			rng.randf_range(min_p.x, max_p.x),
			rng.randf_range(min_p.y, max_p.y),
			rng.randf_range(min_p.z, max_p.z)
		)
		var yaw := rng.randf_range(0, TAU) if optional_bool(params, "random_yaw", true) else 0.0
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), pos))
	mark_current_scene_unsaved()
	return success({"instance_count": count, "seed": rng.seed})


func _multimesh_get_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MultiMeshInstance3D):
		return error_not_found("MultiMeshInstance3D")
	var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
	if mm == null:
		return success({"has_multimesh": false})
	return success({
		"instance_count": mm.instance_count,
		"visible_instance_count": mm.visible_instance_count,
		"mesh": mm.mesh.resource_path if mm.mesh else mm.mesh.get_class() if mm.mesh else "",
		"transform_format": mm.transform_format,
	})
