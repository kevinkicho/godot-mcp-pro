@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Auto-generate PhysicalBone3D ragdoll from Skeleton3D (physics docs gap).


func get_commands() -> Dictionary:
	return {
		"generate_ragdoll_from_skeleton": _generate_ragdoll_from_skeleton,
		"list_physical_bones": _list_physical_bones,
		"set_physical_bone_params": _set_physical_bone_params,
		"create_ragdoll_control_script": _create_ragdoll_control_script,
		"list_ragdoll_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_physical_bone_simulator", "add_physical_bone", "list_skeleton_bones", "find_skeletons"],
		"flow": [
			"generate_ragdoll_from_skeleton node_path=Skeleton3D",
			"create_ragdoll_control_script attach_to=Character",
			"At runtime: physical_bones_start_simulation",
		],
	})


func _generate_ragdoll_from_skeleton(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := find_node_by_path(r0[0])
	if sk == null or not (sk is Skeleton3D):
		return error_not_found("Skeleton3D")
	var skeleton: Skeleton3D = sk
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	# Optional bone filter: only these names (or all with parents)
	var only: Array = params.get("bones", [])
	var skip: Array = params.get("skip_bones", ["Root", "root", "Skeleton", "Armature"])
	var min_length: float = float(params.get("min_bone_length", 0.02))
	var radius_scale: float = float(params.get("radius_scale", 0.15))
	var use_simulator: bool = optional_bool(params, "use_simulator", true)

	var parent_for_bones: Node = skeleton
	var sim_path := ""
	if use_simulator and ClassDB.class_exists("PhysicalBoneSimulator3D"):
		var existing = null
		for c in skeleton.get_children():
			if c.get_class() == "PhysicalBoneSimulator3D":
				existing = c
				break
		if existing == null:
			existing = ClassDB.instantiate("PhysicalBoneSimulator3D")
			existing.name = optional_string(params, "simulator_name", "PhysicalBoneSimulator3D")
			add_child_with_undo(skeleton, existing, root, "MCP: Ragdoll simulator")
		parent_for_bones = existing
		sim_path = str(root.get_path_to(existing))

	var created: Array = []
	var bone_count := skeleton.get_bone_count()
	for i in range(bone_count):
		var bname := skeleton.get_bone_name(i)
		if str(bname) in skip:
			continue
		if only.size() > 0 and not (str(bname) in only):
			continue
		var parent_i := skeleton.get_bone_parent(i)
		# Prefer bones that have a parent (segment)
		var rest: Transform3D = skeleton.get_bone_rest(i)
		var length := rest.origin.length()
		# Estimate length toward first child if parent is root-like
		if length < min_length:
			# try child direction
			for j in range(bone_count):
				if skeleton.get_bone_parent(j) == i:
					var child_rest: Transform3D = skeleton.get_bone_rest(j)
					length = maxf(length, child_rest.origin.length())
					break
		if length < min_length:
			length = float(params.get("default_length", 0.15))
		var radius: float = clampf(length * radius_scale, 0.02, 0.2)
		if params.has("radius"):
			radius = float(params["radius"])

		if not ClassDB.class_exists("PhysicalBone3D"):
			return error_internal("PhysicalBone3D unavailable in this Godot build")
		var bone: Node = ClassDB.instantiate("PhysicalBone3D")
		bone.name = "PB_%s" % str(bname).replace(".", "_").replace(":", "_")
		if "bone_name" in bone:
			bone.set("bone_name", StringName(bname))
		# Body type
		if "joint_type" in bone and params.has("joint_type"):
			bone.set("joint_type", int(params["joint_type"]))
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape_type: String = optional_string(params, "shape", "capsule")
		match shape_type:
			"sphere":
				var s := SphereShape3D.new()
				s.radius = radius
				col.shape = s
			"box":
				var b := BoxShape3D.new()
				b.size = Vector3(radius * 2.0, length, radius * 2.0)
				col.shape = b
			_:
				var c := CapsuleShape3D.new()
				c.radius = radius
				c.height = maxf(length, radius * 2.0 + 0.01)
				col.shape = c
		# Align capsule along bone axis (Y in Godot capsules)
		col.rotation_degrees = Vector3(0, 0, 90) if optional_bool(params, "align_capsule", true) else Vector3.ZERO
		add_child_with_undo(parent_for_bones, bone, root, "MCP: Ragdoll bone")
		add_child_with_undo(bone, col, root, "MCP: Ragdoll shape")
		created.append({
			"bone_name": bname,
			"path": str(root.get_path_to(bone)),
			"length": length,
			"radius": radius,
		})
		if created.size() >= clampi(optional_int(params, "max_bones", 64), 1, 200):
			break

	mark_current_scene_unsaved()
	return success({
		"skeleton": r0[0],
		"simulator": sim_path,
		"physical_bones": created,
		"count": created.size(),
		"hint": "create_ragdoll_control_script; runtime physical_bones_start_simulation on simulator/skeleton",
	})


func _list_physical_bones(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var start_path: String = optional_string(params, "node_path", ".")
	var start := find_node_by_path(start_path)
	if start == null:
		start = root
	var out: Array = []
	_walk_pb(start, root, out)
	return success({"bones": out, "count": out.size()})


func _walk_pb(n: Node, root: Node, out: Array) -> void:
	if n.get_class() == "PhysicalBone3D":
		out.append({
			"path": str(root.get_path_to(n)),
			"bone_name": n.get("bone_name") if "bone_name" in n else "",
			"class": n.get_class(),
		})
	for c in n.get_children():
		_walk_pb(c, root, out)


func _set_physical_bone_params(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var n := find_node_by_path(r0[0])
	if n == null or n.get_class() != "PhysicalBone3D":
		return error_not_found("PhysicalBone3D")
	var applied := {}
	for k in ["mass", "friction", "bounce", "gravity_scale", "linear_damp", "angular_damp", "can_sleep"]:
		if params.has(k) and k in n:
			n.set(k, params[k])
			applied[k] = n.get(k)
	if params.has("bone_name") and "bone_name" in n:
		n.set("bone_name", StringName(str(params["bone_name"])))
		applied["bone_name"] = str(n.get("bone_name"))
	if params.has("joint_type") and "joint_type" in n:
		n.set("joint_type", int(params["joint_type"]))
		applied["joint_type"] = n.get("joint_type")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _create_ragdoll_control_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/ragdoll_control.gd")
	var content := """extends Node
## Toggle ragdoll simulation on PhysicalBoneSimulator3D / Skeleton3D.
@export var simulator_path: NodePath
@export var skeleton_path: NodePath

func start_ragdoll() -> void:
	var sim := get_node_or_null(simulator_path)
	if sim and sim.has_method("physical_bones_start_simulation"):
		sim.physical_bones_start_simulation()
		return
	var sk := get_node_or_null(skeleton_path)
	if sk and sk.has_method("physical_bones_start_simulation"):
		sk.physical_bones_start_simulation()

func stop_ragdoll() -> void:
	var sim := get_node_or_null(simulator_path)
	if sim and sim.has_method("physical_bones_stop_simulation"):
		sim.physical_bones_stop_simulation()
		return
	var sk := get_node_or_null(skeleton_path)
	if sk and sk.has_method("physical_bones_stop_simulation"):
		sk.physical_bones_stop_simulation()
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var attach: String = optional_string(params, "attach_to", "")
	if not attach.is_empty():
		var root := get_edited_root()
		var parent := find_node_by_path(attach)
		if parent and root:
			var node := Node.new()
			node.name = "RagdollControl"
			node.set_script(load(path))
			if params.has("simulator_path"):
				node.set("simulator_path", NodePath(str(params["simulator_path"])))
			if params.has("skeleton_path"):
				node.set("skeleton_path", NodePath(str(params["skeleton_path"])))
			add_child_with_undo(parent, node, root, "MCP: Ragdoll control")
			mark_current_scene_unsaved()
			return success({"path": path, "attached": str(root.get_path_to(node))})
	return success({"path": path})
