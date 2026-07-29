@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Skeleton rest authorship - permanent rest edits, copy rest, body-part tags, validate.


func get_commands() -> Dictionary:
	return {
		"set_bone_rest": _set_bone_rest,
		"copy_skeleton_rest": _copy_rest,
		"apply_pose_as_rest": _pose_as_rest,
		"scale_bone_rest": _scale_bone_rest,
		"tag_skeleton_body_parts": _tag_body_parts,
		"get_skeleton_body_part_map": _get_body_part_map,
		"validate_skeleton_for_humanoid": _validate_humanoid_skeleton,
		"list_skeleton_rest_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"list_skeleton_bones", "get_bone_info", "set_bone_pose", "get_skeleton_rest",
		"create_bone_map", "auto_map_bones_by_name", "apply_bone_map_to_skeleton",
	])


func _sk(path: String) -> Skeleton3D:
	var n := find_node_by_path(path)
	return n as Skeleton3D if n is Skeleton3D else null


func _resolve_bone(sk: Skeleton3D, params: Dictionary) -> Array:
	if params.has("bone_index"):
		var idx := int(params["bone_index"])
		if idx < 0 or idx >= sk.get_bone_count():
			return [-1, error_invalid_params("bone_index out of range")]
		return [idx, null]
	var bn := optional_string(params, "bone_name", optional_string(params, "bone", ""))
	if bn.is_empty():
		return [-1, error_invalid_params("bone_index or bone_name required")]
	var found := sk.find_bone(bn)
	if found < 0:
		return [-1, error_not_found("Bone '%s'" % bn)]
	return [found, null]


func _dict_to_xform(d: Dictionary) -> Transform3D:
	var origin := Vector3(
		float(d.get("origin", d).get("x", 0) if d.get("origin") is Dictionary else d.get("x", 0)),
		float(d.get("origin", d).get("y", 0) if d.get("origin") is Dictionary else d.get("y", 0)),
		float(d.get("origin", d).get("z", 0) if d.get("origin") is Dictionary else d.get("z", 0))
	)
	if d.has("origin") and d["origin"] is Dictionary:
		var o: Dictionary = d["origin"]
		origin = Vector3(float(o.get("x", 0)), float(o.get("y", 0)), float(o.get("z", 0)))
	var basis := Basis.IDENTITY
	if d.has("basis") and d["basis"] is Dictionary:
		var b: Dictionary = d["basis"]
		var bx: Dictionary = b.get("x", {})
		var by: Dictionary = b.get("y", {})
		var bz: Dictionary = b.get("z", {})
		basis = Basis(
			Vector3(float(bx.get("x", 1)), float(bx.get("y", 0)), float(bx.get("z", 0))),
			Vector3(float(by.get("x", 0)), float(by.get("y", 1)), float(by.get("z", 0))),
			Vector3(float(bz.get("x", 0)), float(bz.get("y", 0)), float(bz.get("z", 1)))
		)
	elif d.has("rotation_degrees") and d["rotation_degrees"] is Dictionary:
		var e: Dictionary = d["rotation_degrees"]
		basis = Basis.from_euler(Vector3(
			deg_to_rad(float(e.get("x", 0))),
			deg_to_rad(float(e.get("y", 0))),
			deg_to_rad(float(e.get("z", 0)))
		))
	return Transform3D(basis, origin)


func _set_bone_rest(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _sk(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D")
	var bi := _resolve_bone(sk, params)
	if bi[1] != null:
		return bi[1]
	var i: int = bi[0]
	var rest: Transform3D
	if params.has("rest") and params["rest"] is Dictionary:
		rest = _dict_to_xform(params["rest"])
	elif params.has("use_current_pose") and bool(params["use_current_pose"]):
		rest = sk.get_bone_pose(i)
	else:
		return error_invalid_params("rest{} or use_current_pose=true required")
	sk.set_bone_rest(i, rest)
	if optional_bool(params, "reset_pose", true):
		sk.reset_bone_pose(i)
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"bone_index": i,
		"bone_name": sk.get_bone_name(i),
		"rest_set": true,
	})


func _pose_as_rest(params: Dictionary) -> Dictionary:
	## Bake current poses into rest for all bones (or listed bones).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _sk(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D")
	var bones: Array = params.get("bones", [])
	var indices: Array = []
	if bones.is_empty():
		for i in sk.get_bone_count():
			indices.append(i)
	else:
		for b in bones:
			if b is int:
				indices.append(int(b))
			else:
				var idx := sk.find_bone(str(b))
				if idx >= 0:
					indices.append(idx)
	var changed: Array = []
	for i in indices:
		sk.set_bone_rest(int(i), sk.get_bone_pose(int(i)))
		sk.reset_bone_pose(int(i))
		changed.append({"index": int(i), "name": sk.get_bone_name(int(i))})
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "changed": changed, "count": changed.size()})


func _copy_rest(params: Dictionary) -> Dictionary:
	## Copy rest transforms from source skeleton to target by bone name.
	var src_r := require_string(params, "source_path")
	if src_r[1] != null:
		return src_r[1]
	var dst_r := require_string(params, "target_path")
	if dst_r[1] != null:
		return dst_r[1]
	var src := _sk(src_r[0])
	var dst := _sk(dst_r[0])
	if src == null or dst == null:
		return error_not_found("source and target Skeleton3D required")
	var copied: Array = []
	var missing: Array = []
	for i in src.get_bone_count():
		var name_s := src.get_bone_name(i)
		var j := dst.find_bone(name_s)
		if j < 0:
			missing.append(name_s)
			continue
		dst.set_bone_rest(j, src.get_bone_rest(i))
		if optional_bool(params, "reset_pose", true):
			dst.reset_bone_pose(j)
		copied.append(name_s)
	mark_current_scene_unsaved()
	return success({
		"source_path": src_r[0],
		"target_path": dst_r[0],
		"copied": copied,
		"copied_count": copied.size(),
		"missing_on_target": missing,
	})


func _scale_bone_rest(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _sk(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D")
	var bi := _resolve_bone(sk, params)
	if bi[1] != null:
		return bi[1]
	var i: int = bi[0]
	var scale_f := float(params.get("scale", 1.0))
	if params.has("scale_vec") and params["scale_vec"] is Dictionary:
		var sv: Dictionary = params["scale_vec"]
		var rest := sk.get_bone_rest(i)
		rest.basis = rest.basis.scaled(Vector3(
			float(sv.get("x", 1)), float(sv.get("y", 1)), float(sv.get("z", 1))
		))
		sk.set_bone_rest(i, rest)
	else:
		var rest2 := sk.get_bone_rest(i)
		rest2.basis = rest2.basis.scaled(Vector3.ONE * scale_f)
		sk.set_bone_rest(i, rest2)
	if optional_bool(params, "reset_pose", true):
		sk.reset_bone_pose(i)
	mark_current_scene_unsaved()
	return success({"bone_index": i, "bone_name": sk.get_bone_name(i), "scaled": true})


func _default_body_parts() -> Dictionary:
	## Approximate humanoid name patterns -> body part tags
	return {
		"hips": ["Hips", "hip", "Pelvis", "Root"],
		"spine": ["Spine", "spine", "Chest", "UpperChest"],
		"head": ["Head", "head", "Neck", "neck"],
		"left_arm": ["LeftArm", "LeftUpperArm", "LeftForeArm", "LeftHand", "LeftShoulder"],
		"right_arm": ["RightArm", "RightUpperArm", "RightForeArm", "RightHand", "RightShoulder"],
		"left_leg": ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase"],
		"right_leg": ["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"],
	}


func _tag_body_parts(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _sk(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D")
	var patterns: Dictionary = params.get("parts", _default_body_parts())
	var map := {}
	for part in patterns:
		map[str(part)] = []
		var names: Array = patterns[part] if patterns[part] is Array else [patterns[part]]
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			for pat in names:
				if str(pat).to_lower() in bn.to_lower() or bn == str(pat):
					map[str(part)].append({"index": i, "name": bn})
					break
	sk.set_meta("mcp_body_parts", map)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "parts": map})


func _get_body_part_map(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _sk(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D")
	if sk.has_meta("mcp_body_parts"):
		return success({"node_path": r0[0], "parts": sk.get_meta("mcp_body_parts"), "cached": true})
	return _tag_body_parts({"node_path": r0[0]})


func _validate_humanoid_skeleton(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sk := _sk(r0[0])
	if sk == null:
		return error_not_found("Skeleton3D")
	var required := [
		"Hips", "Spine", "Head", "LeftUpperArm", "RightUpperArm",
		"LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftFoot", "RightFoot",
	]
	# Also accept common alternates
	var alts := {
		"LeftUpperArm": ["LeftArm", "mixamorig:LeftArm"],
		"RightUpperArm": ["RightArm", "mixamorig:RightArm"],
		"LeftUpperLeg": ["LeftUpLeg", "mixamorig:LeftUpLeg"],
		"RightUpperLeg": ["RightUpLeg", "mixamorig:RightUpLeg"],
		"Hips": ["mixamorig:Hips", "Pelvis"],
		"Head": ["mixamorig:Head"],
	}
	var found: Array = []
	var missing: Array = []
	for req in required:
		var ok := sk.find_bone(req) >= 0
		if not ok and alts.has(req):
			for a in alts[req]:
				if sk.find_bone(str(a)) >= 0:
					ok = true
					found.append({"profile": req, "matched": a})
					break
		elif ok:
			found.append({"profile": req, "matched": req})
		if not ok:
			# fuzzy
			var fuzzy := false
			for i in sk.get_bone_count():
				if req.to_lower() in sk.get_bone_name(i).to_lower():
					found.append({"profile": req, "matched": sk.get_bone_name(i), "fuzzy": true})
					fuzzy = true
					break
			if not fuzzy:
				missing.append(req)
	var score := float(found.size()) / float(required.size())
	return success({
		"node_path": r0[0],
		"bone_count": sk.get_bone_count(),
		"found": found,
		"missing": missing,
		"coverage": score,
		"humanoid_ready": missing.is_empty() or score >= 0.7,
		"hint": "create_bone_map_preset + auto_map_bones_by_name if missing",
	})
