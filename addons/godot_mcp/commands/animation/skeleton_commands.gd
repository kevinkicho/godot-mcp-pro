@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Skeleton3D / BoneAttachment human editor surface (inspect + pose like the skeleton dock).


func get_commands() -> Dictionary:
	return {
		"find_skeletons": _find_skeletons,
		"list_skeleton_bones": _list_skeleton_bones,
		"get_bone_info": _get_bone_info,
		"set_bone_pose": _set_bone_pose,
		"reset_bone_pose": _reset_bone_pose,
		"reset_all_bone_poses": _reset_all_bone_poses,
		"find_bone": _find_bone,
		"get_skeleton_rest": _get_skeleton_rest,
		# BoneMap / retarget surface (tutorials/assets_pipeline/retargeting)
		"create_bone_map": _create_bone_map,
		"get_bone_map_info": _get_bone_map_info,
		"set_bone_map_mapping": _set_bone_map_mapping,
		"auto_map_bones_by_name": _auto_map_bones_by_name,
		"add_bone_attachment": _add_bone_attachment,
		"list_skeleton_profile_bones": _list_skeleton_profile_bones,
	}


func _find_skeleton(node_path: String) -> Skeleton3D:
	var node := find_node_by_path(node_path)
	if node is Skeleton3D:
		return node as Skeleton3D
	return null


func _xform_to_dict(t: Transform3D) -> Dictionary:
	return {
		"origin": {"x": t.origin.x, "y": t.origin.y, "z": t.origin.z},
		"basis": {
			"x": {"x": t.basis.x.x, "y": t.basis.x.y, "z": t.basis.x.z},
			"y": {"x": t.basis.y.x, "y": t.basis.y.y, "z": t.basis.y.z},
			"z": {"x": t.basis.z.x, "y": t.basis.z.y, "z": t.basis.z.z},
		},
	}


func _find_skeletons(params: Dictionary) -> Dictionary:
	## Scan open scene for Skeleton3D nodes (human finds them in scene tree).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var found: Array = []
	_collect_skeletons(root, root, found)
	return success({"skeletons": found, "count": found.size()})


func _collect_skeletons(root: Node, node: Node, out: Array) -> void:
	if node is Skeleton3D:
		var sk: Skeleton3D = node as Skeleton3D
		out.append({
			"node_path": str(root.get_path_to(sk)),
			"name": sk.name,
			"bone_count": sk.get_bone_count(),
			"motion_scale": sk.motion_scale if "motion_scale" in sk else 1.0,
		})
	for child in node.get_children():
		_collect_skeletons(root, child, out)


func _list_skeleton_bones(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var bones: Array = []
	for i in sk.get_bone_count():
		var parent_idx := sk.get_bone_parent(i)
		bones.append({
			"index": i,
			"name": sk.get_bone_name(i),
			"parent": parent_idx,
			"parent_name": sk.get_bone_name(parent_idx) if parent_idx >= 0 else "",
			"enabled": sk.is_bone_enabled(i) if sk.has_method("is_bone_enabled") else true,
		})
	return success({
		"node_path": r0[0],
		"bone_count": sk.get_bone_count(),
		"bones": bones,
	})


func _resolve_bone_index(sk: Skeleton3D, params: Dictionary) -> Array:
	## Returns [index:int, error_or_null]
	if params.has("bone_index"):
		var idx := int(params["bone_index"])
		if idx < 0 or idx >= sk.get_bone_count():
			return [-1, error_invalid_params("bone_index out of range")]
		return [idx, null]
	var bone_name: String = optional_string(params, "bone_name", optional_string(params, "bone", ""))
	if bone_name.is_empty():
		return [-1, error_invalid_params("bone_index or bone_name required")]
	var found := sk.find_bone(bone_name)
	if found < 0:
		return [-1, error_not_found("Bone '%s'" % bone_name)]
	return [found, null]


func _get_bone_info(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var bi := _resolve_bone_index(sk, params)
	if bi[1] != null:
		return bi[1]
	var i: int = bi[0]
	var rest: Transform3D = sk.get_bone_rest(i)
	var pose: Transform3D = sk.get_bone_pose(i)
	var global_pose: Transform3D = sk.get_bone_global_pose(i)
	var parent_idx := sk.get_bone_parent(i)
	var children: Array = []
	if sk.has_method("get_bone_children"):
		for c in sk.get_bone_children(i):
			children.append({"index": c, "name": sk.get_bone_name(c)})
	return success({
		"node_path": r0[0],
		"index": i,
		"name": sk.get_bone_name(i),
		"parent": parent_idx,
		"parent_name": sk.get_bone_name(parent_idx) if parent_idx >= 0 else "",
		"children": children,
		"rest": _xform_to_dict(rest),
		"pose": _xform_to_dict(pose),
		"global_pose": _xform_to_dict(global_pose),
		"pose_position": {
			"x": sk.get_bone_pose_position(i).x,
			"y": sk.get_bone_pose_position(i).y,
			"z": sk.get_bone_pose_position(i).z,
		},
		"pose_rotation": {
			"x": sk.get_bone_pose_rotation(i).x,
			"y": sk.get_bone_pose_rotation(i).y,
			"z": sk.get_bone_pose_rotation(i).z,
			"w": sk.get_bone_pose_rotation(i).w,
		},
		"pose_scale": {
			"x": sk.get_bone_pose_scale(i).x,
			"y": sk.get_bone_pose_scale(i).y,
			"z": sk.get_bone_pose_scale(i).z,
		},
	})


func _set_bone_pose(params: Dictionary) -> Dictionary:
	## Set pose position / rotation (quaternion or euler degrees) / scale - human skeleton dock
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var bi := _resolve_bone_index(sk, params)
	if bi[1] != null:
		return bi[1]
	var i: int = bi[0]
	var changed: Array = []

	if params.has("position"):
		var p = params["position"]
		var pos := Vector3.ZERO
		if p is Dictionary:
			pos = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
		elif p is String:
			# "x,y,z" or Vector3(...)
			var s: String = p
			s = s.replace("Vector3(", "").replace(")", "").strip_edges()
			var parts := s.split(",")
			if parts.size() >= 3:
				pos = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		sk.set_bone_pose_position(i, pos)
		changed.append("position")

	if params.has("rotation") or params.has("rotation_degrees") or params.has("quaternion"):
		if params.has("quaternion"):
			var q = params["quaternion"]
			if q is Dictionary:
				sk.set_bone_pose_rotation(i, Quaternion(
					float(q.get("x", 0)), float(q.get("y", 0)), float(q.get("z", 0)), float(q.get("w", 1))
				))
			changed.append("quaternion")
		else:
			var e := Vector3.ZERO
			var src = params.get("rotation_degrees", params.get("rotation", {}))
			if src is Dictionary:
				e = Vector3(float(src.get("x", 0)), float(src.get("y", 0)), float(src.get("z", 0)))
			# degrees -> quaternion via Basis
			var basis := Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
			sk.set_bone_pose_rotation(i, basis.get_rotation_quaternion())
			changed.append("rotation_degrees")

	if params.has("scale"):
		var s = params["scale"]
		var sc := Vector3.ONE
		if s is Dictionary:
			sc = Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1)))
		elif s is float or s is int:
			sc = Vector3(float(s), float(s), float(s))
		sk.set_bone_pose_scale(i, sc)
		changed.append("scale")

	if changed.is_empty():
		return error_invalid_params("Provide position and/or rotation(_degrees)|quaternion and/or scale")

	mark_current_scene_unsaved()
	return success({
		"bone_index": i,
		"bone_name": sk.get_bone_name(i),
		"changed": changed,
		"pose_position": {
			"x": sk.get_bone_pose_position(i).x,
			"y": sk.get_bone_pose_position(i).y,
			"z": sk.get_bone_pose_position(i).z,
		},
	})


func _reset_bone_pose(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var bi := _resolve_bone_index(sk, params)
	if bi[1] != null:
		return bi[1]
	var i: int = bi[0]
	sk.reset_bone_pose(i)
	mark_current_scene_unsaved()
	return success({"bone_index": i, "bone_name": sk.get_bone_name(i), "reset": true})


func _reset_all_bone_poses(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	if sk.has_method("reset_bone_poses"):
		sk.reset_bone_poses()
	else:
		for i in sk.get_bone_count():
			sk.reset_bone_pose(i)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "reset_all": true, "bone_count": sk.get_bone_count()})


func _find_bone(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var name_r := require_string(params, "bone_name")
	if name_r[1] != null:
		return name_r[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var idx := sk.find_bone(name_r[0])
	if idx < 0:
		return error_not_found("Bone '%s'" % name_r[0])
	return success({"bone_name": name_r[0], "bone_index": idx})


func _get_skeleton_rest(params: Dictionary) -> Dictionary:
	## Export rest poses for all bones (retarget / RESET reference)
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var rests: Array = []
	for i in sk.get_bone_count():
		rests.append({
			"index": i,
			"name": sk.get_bone_name(i),
			"parent": sk.get_bone_parent(i),
			"rest": _xform_to_dict(sk.get_bone_rest(i)),
		})
	return success({"node_path": r0[0], "bones": rests, "count": rests.size()})


func _make_profile(profile_type: String) -> SkeletonProfile:
	match profile_type.to_lower():
		"humanoid", "skeletonprofilehumanoid", "":
			if ClassDB.class_exists("SkeletonProfileHumanoid"):
				return ClassDB.instantiate("SkeletonProfileHumanoid") as SkeletonProfile
			return SkeletonProfile.new()
		_:
			if ClassDB.class_exists(profile_type) and ClassDB.can_instantiate(profile_type):
				var p = ClassDB.instantiate(profile_type)
				if p is SkeletonProfile:
					return p as SkeletonProfile
			return SkeletonProfile.new()


func _create_bone_map(params: Dictionary) -> Dictionary:
	## Create BoneMap resource (retarget wizard core). Optional profile + save path.
	var profile_type: String = optional_string(params, "profile", "humanoid")
	var profile := _make_profile(profile_type)
	var bone_map := BoneMap.new()
	bone_map.profile = profile
	var path: String = optional_string(params, "path", "")
	if not path.is_empty():
		if not path.begins_with("res://"):
			path = "res://" + path.trim_prefix("/")
		var derr := ensure_parent_dir(path)
		if not derr.is_empty():
			return derr
		var err := ResourceSaver.save(bone_map, path)
		if err != OK:
			return error_internal(error_string(err))
		EditorInterface.get_resource_filesystem().update_file(path)
	var bone_names: Array = []
	if profile:
		for i in profile.get_bone_size():
			bone_names.append(str(profile.get_bone_name(i)))
	return success({
		"path": path,
		"profile": profile.get_class() if profile else "",
		"profile_bone_count": bone_names.size(),
		"profile_bones": bone_names,
		"created": true,
	})


func _load_bone_map(path: String) -> BoneMap:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as BoneMap


func _get_bone_map_info(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var bm := _load_bone_map(res[0])
	if bm == null:
		return error_not_found("BoneMap at %s" % res[0])
	var profile: SkeletonProfile = bm.profile
	var mappings: Array = []
	if profile:
		for i in profile.get_bone_size():
			var pname := str(profile.get_bone_name(i))
			var skeleton_bone := ""
			if bm.has_method("get_skeleton_bone_name"):
				skeleton_bone = str(bm.get_skeleton_bone_name(StringName(pname)))
			mappings.append({
				"profile_bone": pname,
				"skeleton_bone": skeleton_bone,
				"mapped": not skeleton_bone.is_empty(),
			})
	return success({
		"path": res[0],
		"profile": profile.get_class() if profile else "",
		"mappings": mappings,
		"mapped_count": _count_mapped(mappings),
	})


func _count_mapped(mappings: Array) -> int:
	var n := 0
	for m in mappings:
		if m is Dictionary and bool(m.get("mapped", false)):
			n += 1
	return n


func _set_bone_map_mapping(params: Dictionary) -> Dictionary:
	## Map one profile bone name -> skeleton bone name (empty string clears).
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var profile_bone_r := require_string(params, "profile_bone")
	if profile_bone_r[1] != null:
		return profile_bone_r[1]
	var skeleton_bone: String = optional_string(params, "skeleton_bone", "")
	var bm := _load_bone_map(res[0])
	if bm == null:
		return error_not_found("BoneMap at %s" % res[0])
	if bm.has_method("set_skeleton_bone_name"):
		bm.set_skeleton_bone_name(StringName(profile_bone_r[0]), StringName(skeleton_bone))
	else:
		return error_internal("BoneMap.set_skeleton_bone_name unavailable")
	var err := ResourceSaver.save(bm, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"profile_bone": profile_bone_r[0],
		"skeleton_bone": skeleton_bone,
	})


func _auto_map_bones_by_name(params: Dictionary) -> Dictionary:
	## Heuristic: for each profile bone, if skeleton has same name (case-insensitive), map it.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var sk_path_r := require_string(params, "skeleton_path")
	if sk_path_r[1] != null:
		return sk_path_r[1]
	var bm := _load_bone_map(res[0])
	if bm == null:
		return error_not_found("BoneMap at %s" % res[0])
	var sk := _find_skeleton(sk_path_r[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % sk_path_r[0])
	var profile: SkeletonProfile = bm.profile
	if profile == null:
		return error_invalid_params("BoneMap has no profile - create_bone_map with profile=humanoid first")
	# Build lowercase name -> actual skeleton name
	var sk_names := {}
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		sk_names[bn.to_lower()] = bn
		# common alternates
		sk_names[bn.to_lower().replace(" ", "_")] = bn
		sk_names[bn.to_lower().replace(".", "_")] = bn
	var mapped: Array = []
	var unmapped: Array = []
	for i in profile.get_bone_size():
		var pname := str(profile.get_bone_name(i))
		var key := pname.to_lower()
		if sk_names.has(key):
			bm.set_skeleton_bone_name(StringName(pname), StringName(sk_names[key]))
			mapped.append({"profile_bone": pname, "skeleton_bone": sk_names[key]})
		else:
			unmapped.append(pname)
	var err := ResourceSaver.save(bm, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"skeleton_path": sk_path_r[0],
		"mapped": mapped,
		"mapped_count": mapped.size(),
		"unmapped": unmapped,
		"unmapped_count": unmapped.size(),
	})


func _add_bone_attachment(params: Dictionary) -> Dictionary:
	## BoneAttachment3D under skeleton - attach weapons/props like human dock.
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk := _find_skeleton(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D at '%s'" % r0[0])
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var att := BoneAttachment3D.new()
	att.name = optional_string(params, "name", "BoneAttachment3D")
	var bone_name: String = optional_string(params, "bone_name", "")
	var bone_index: int = int(params.get("bone_index", -1))
	if not bone_name.is_empty():
		att.bone_name = bone_name
	elif bone_index >= 0:
		att.bone_idx = bone_index
	else:
		return error_invalid_params("bone_name or bone_index required")
	if params.has("override_pose"):
		att.override_pose = bool(params["override_pose"])
	add_child_with_undo(sk, att, root, "MCP: Add BoneAttachment3D")
	return success({
		"node_path": str(root.get_path_to(att)),
		"bone_name": att.bone_name,
		"bone_idx": att.bone_idx if "bone_idx" in att else bone_index,
	})


func _list_skeleton_profile_bones(params: Dictionary) -> Dictionary:
	var profile_type: String = optional_string(params, "profile", "humanoid")
	var profile := _make_profile(profile_type)
	var bones: Array = []
	if profile:
		for i in profile.get_bone_size():
			bones.append({
				"index": i,
				"name": str(profile.get_bone_name(i)),
				"parent": str(profile.get_bone_parent(i)) if profile.has_method("get_bone_parent") else "",
			})
	return success({
		"profile": profile.get_class() if profile else "",
		"bones": bones,
		"count": bones.size(),
	})
