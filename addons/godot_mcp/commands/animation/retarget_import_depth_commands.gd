@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Deep retarget / import UI surface - character import presets, BoneMap apply report, profile.


func get_commands() -> Dictionary:
	return {
		"apply_humanoid_import_preset": _humanoid_import_preset,
		"list_humanoid_import_options": _list_import_options,
		"set_import_retarget_options": _set_retarget_options,
		"build_bone_map_from_skeleton": _build_map_from_sk,
		"validate_bone_map_coverage": _validate_map,
		"get_skeleton_profile_humanoid_info": _profile_info,
		"list_animation_clips_on_import": _list_clips_import,
		"prepare_mixamo_character_import": _prepare_mixamo,
		"prepare_rpm_character_import": _prepare_rpm,
		"retarget_report_for_character": _retarget_report,
		"list_retarget_import_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"set_gltf_import_flags", "apply_scene_import_advanced", "list_scene_import_options",
		"create_bone_map", "create_bone_map_preset", "auto_map_bones_by_name",
		"apply_bone_map_to_skeleton", "pipeline_character_from_gltf", "pipeline_retarget_animations",
	], {
		"flow": [
			"ensure_imported glb",
			"prepare_mixamo_character_import or apply_humanoid_import_preset",
			"pipeline_character_from_gltf / build_bone_map_from_skeleton",
			"validate_bone_map_coverage -> retarget_report_for_character",
		],
	})


func _write_import_options(path: String, options: Dictionary, reimport: bool) -> Dictionary:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return error_not_found(import_path, "Import the asset first (ensure_imported)")
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return error_internal("Cannot load .import")
	var changed: Array = []
	for k in options:
		var key := str(k)
		var old = cfg.get_value("params", key) if cfg.has_section_key("params", key) else null
		cfg.set_value("params", key, options[k])
		changed.append({"key": key, "old": old, "new": options[k]})
	if cfg.save(import_path) != OK:
		return error_internal("Cannot save .import")
	if reimport:
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.reimport_files(PackedStringArray([path]))
	return success({"path": path, "changed": changed, "count": changed.size(), "reimport_started": reimport})


func _humanoid_import_preset(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var preset: String = optional_string(params, "preset", "character_animated")
	var options := {
		"animation/import": true,
		"animation/fps": int(params.get("fps", 30)),
		"animation/trimming": bool(params.get("trimming", false)),
		"animation/remove_immutable_tracks": bool(params.get("remove_immutable_tracks", true)),
		"meshes/ensure_tangents": bool(params.get("ensure_tangents", true)),
		"meshes/generate_lods": bool(params.get("generate_lods", true)),
		"meshes/create_shadow_meshes": bool(params.get("create_shadow_meshes", true)),
		"skins/use_named_skins": bool(params.get("use_named_skins", true)),
		"nodes/import_as_skeleton_bones": bool(params.get("import_as_skeleton_bones", false)),
	}
	match preset.to_lower():
		"character_animated", "humanoid", "mixamo":
			options["animation/import"] = true
			options["skins/use_named_skins"] = true
		"static_prop":
			options["animation/import"] = false
			options["meshes/generate_lods"] = true
		"animation_only":
			options["animation/import"] = true
			options["meshes/generate_lods"] = false
		_:
			pass
	# Godot 4 retarget-related keys when present in importer
	if params.has("rest_fixer") or preset.to_lower() in ["mixamo", "humanoid"]:
		options["animation/import_rest_as_RESET"] = bool(params.get("import_rest_as_RESET", true))
	if params.has("extra") and params["extra"] is Dictionary:
		for k in params["extra"]:
			options[str(k)] = params["extra"][k]
	return _write_import_options(path, options, optional_bool(params, "reimport", true))


func _list_import_options(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return error_not_found(import_path)
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return error_internal("Cannot load .import")
	var all := {}
	var retarget_related: Dictionary = {}
	var anim_related: Dictionary = {}
	var skin_related: Dictionary = {}
	if cfg.has_section("params"):
		for k in cfg.get_section_keys("params"):
			var v = cfg.get_value("params", k)
			all[k] = v
			var ks := str(k).to_lower()
			if "retarget" in ks or "bone" in ks or "skeleton" in ks or "rest" in ks or "profile" in ks:
				retarget_related[k] = v
			if ks.begins_with("animation/") or "anim" in ks:
				anim_related[k] = v
			if "skin" in ks:
				skin_related[k] = v
	return success({
		"path": path,
		"param_count": all.size(),
		"retarget_related": retarget_related,
		"animation_related": anim_related,
		"skin_related": skin_related,
		"all_params": all if optional_bool(params, "include_all", false) else null,
		"hint": "set_import_retarget_options / apply_humanoid_import_preset / apply_scene_import_advanced",
	})


func _set_retarget_options(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var options: Dictionary = {}
	# Friendly names -> common Godot 4 scene importer keys (version-tolerant)
	var map := {
		"import_animations": "animation/import",
		"fps": "animation/fps",
		"trimming": "animation/trimming",
		"remove_immutable_tracks": "animation/remove_immutable_tracks",
		"import_rest_as_RESET": "animation/import_rest_as_RESET",
		"remove_immutable": "animation/remove_immutable_tracks",
		"use_named_skins": "skins/use_named_skins",
		"ensure_tangents": "meshes/ensure_tangents",
		"generate_lods": "meshes/generate_lods",
		"create_shadow_meshes": "meshes/create_shadow_meshes",
		"import_as_skeleton_bones": "nodes/import_as_skeleton_bones",
		"root_scale": "nodes/root_scale",
		"apply_root_scale": "nodes/apply_root_scale",
	}
	for friendly in map:
		if params.has(friendly):
			options[map[friendly]] = params[friendly]
	if params.has("options") and params["options"] is Dictionary:
		for k in params["options"]:
			options[str(k)] = params["options"][k]
	if options.is_empty():
		return error_invalid_params("Provide friendly flags or options{}. See list_humanoid_import_options.")
	return _write_import_options(res[0], options, optional_bool(params, "reimport", true))


func _build_map_from_sk(params: Dictionary) -> Dictionary:
	## Create BoneMap resource by auto-mapping open skeleton against humanoid profile.
	var r0 := require_string(params, "skeleton_path")
	if r0[1] != null:
		return r0[1]
	var sk_node := find_node_by_path(r0[0])
	if sk_node == null or not (sk_node is Skeleton3D):
		return error_not_found("Skeleton3D")
	var sk := sk_node as Skeleton3D
	var path: String = optional_string(params, "path", "res://retarget/bone_map_auto.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var profile: SkeletonProfile = null
	if ClassDB.class_exists("SkeletonProfileHumanoid"):
		profile = ClassDB.instantiate("SkeletonProfileHumanoid") as SkeletonProfile
	else:
		profile = SkeletonProfile.new()
	var bm := BoneMap.new()
	bm.profile = profile
	var mapped: Array = []
	var unmapped: Array = []
	if profile:
		for i in profile.get_bone_size():
			var pname := str(profile.get_bone_name(i))
			var sk_idx := sk.find_bone(pname)
			if sk_idx < 0:
				# fuzzy / mixamo
				for j in sk.get_bone_count():
					var sn := sk.get_bone_name(j)
					var snl := sn.to_lower().replace("mixamorig:", "").replace(":", "")
					var pl := pname.to_lower()
					if snl == pl or pl in snl or snl.ends_with(pl):
						sk_idx = j
						break
			if sk_idx >= 0 and bm.has_method("set_skeleton_bone_name"):
				bm.set_skeleton_bone_name(StringName(pname), StringName(sk.get_bone_name(sk_idx)))
				mapped.append({"profile": pname, "skeleton": sk.get_bone_name(sk_idx)})
			else:
				unmapped.append(pname)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", true):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var err := ResourceSaver.save(bm, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"skeleton_path": r0[0],
		"mapped": mapped,
		"mapped_count": mapped.size(),
		"unmapped": unmapped,
		"coverage": float(mapped.size()) / float(maxi(mapped.size() + unmapped.size(), 1)),
	})


func _validate_map(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	if not ResourceLoader.exists(res[0]):
		return error_not_found(res[0])
	var bm: BoneMap = load(res[0]) as BoneMap
	if bm == null:
		return error_internal("Not a BoneMap")
	var profile: SkeletonProfile = bm.profile
	var mapped: Array = []
	var unmapped: Array = []
	if profile:
		for i in profile.get_bone_size():
			var pname := str(profile.get_bone_name(i))
			var sname := ""
			if bm.has_method("get_skeleton_bone_name"):
				sname = str(bm.get_skeleton_bone_name(StringName(pname)))
			if sname.is_empty():
				unmapped.append(pname)
			else:
				mapped.append({"profile": pname, "skeleton": sname})
	var total := mapped.size() + unmapped.size()
	return success({
		"path": res[0],
		"profile": profile.get_class() if profile else "",
		"mapped_count": mapped.size(),
		"unmapped": unmapped,
		"coverage": float(mapped.size()) / float(maxi(total, 1)),
		"ready": unmapped.is_empty() or mapped.size() >= int(total * 0.7),
	})


func _profile_info(_params: Dictionary) -> Dictionary:
	var bones: Array = []
	if ClassDB.class_exists("SkeletonProfileHumanoid"):
		var p: SkeletonProfile = ClassDB.instantiate("SkeletonProfileHumanoid") as SkeletonProfile
		if p:
			for i in p.get_bone_size():
				bones.append({
					"index": i,
					"name": str(p.get_bone_name(i)),
					"parent": str(p.get_bone_parent(i)) if p.has_method("get_bone_parent") else "",
				})
			return success({
				"class": "SkeletonProfileHumanoid",
				"bone_count": bones.size(),
				"bones": bones,
			})
	return success({
		"class": "SkeletonProfile",
		"bone_count": 0,
		"bones": [],
		"note": "SkeletonProfileHumanoid unavailable in this Godot build",
	})


func _list_clips_import(params: Dictionary) -> Dictionary:
	## List animations from an imported scene path without opening in editor.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not ResourceLoader.exists(path):
		return error_not_found(path)
	var packed := load(path) as PackedScene
	if packed == null:
		return error_internal("Not a PackedScene")
	var root: Node = packed.instantiate()
	var clips: Array = []
	_walk_anims(root, root, clips)
	root.free()
	return success({"path": path, "clips": clips, "count": clips.size()})


func _walk_anims(scene_root: Node, n: Node, out: Array) -> void:
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			if lib == null:
				continue
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				out.append({
					"player": str(scene_root.get_path_to(ap)),
					"library": str(lib_name),
					"name": str(anim_name),
					"length": anim.length if anim else 0.0,
					"track_count": anim.get_track_count() if anim else 0,
				})
	for c in n.get_children():
		_walk_anims(scene_root, c, out)


func _prepare_mixamo(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var steps: Array = []
	steps.append(_humanoid_import_preset({
		"path": res[0],
		"preset": "mixamo",
		"fps": params.get("fps", 30),
		"import_rest_as_RESET": true,
		"use_named_skins": true,
		"reimport": optional_bool(params, "reimport", true),
		"extra": params.get("extra", {}),
	}))
	return success({
		"path": res[0],
		"profile": "mixamo",
		"steps": steps,
		"next": [
			"pipeline_character_from_gltf path=... profile=mixamo",
			"create_bone_map_preset profile=mixamo",
			"build_bone_map_from_skeleton after instancing",
		],
	})


func _prepare_rpm(params: Dictionary) -> Dictionary:
	## Ready Player Me oriented import defaults.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var steps: Array = []
	steps.append(_humanoid_import_preset({
		"path": res[0],
		"preset": "humanoid",
		"fps": params.get("fps", 30),
		"use_named_skins": true,
		"generate_lods": true,
		"reimport": optional_bool(params, "reimport", true),
		"extra": params.get("extra", {}),
	}))
	return success({
		"path": res[0],
		"profile": "rpm",
		"steps": steps,
		"next": [
			"pipeline_character_from_gltf profile=rpm",
			"list_blend_shapes on face mesh for expressions",
			"apply_avatar_material_pack for clothing textures",
		],
	})


func _retarget_report(params: Dictionary) -> Dictionary:
	## Composite health report for a character node path + optional bone map.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var sk: Skeleton3D = null
	if node is Skeleton3D:
		sk = node as Skeleton3D
	else:
		sk = _find_sk(node)
	var report := {
		"node_path": r0[0],
		"has_skeleton": sk != null,
		"bone_count": sk.get_bone_count() if sk else 0,
		"animation_players": [],
		"mesh_instances": [],
		"bone_map": null,
		"issues": [],
		"score": 0.0,
	}
	_collect_char_nodes(node, root, report)
	if sk == null:
		(report["issues"] as Array).append("No Skeleton3D under character")
	elif sk.get_bone_count() < 10:
		(report["issues"] as Array).append("Very few bones - may not be humanoid")
	if (report["animation_players"] as Array).is_empty():
		(report["issues"] as Array).append("No AnimationPlayer")
	if (report["mesh_instances"] as Array).is_empty():
		(report["issues"] as Array).append("No MeshInstance3D")
	if params.has("bone_map_path"):
		var vr := _validate_map({"path": str(params["bone_map_path"])})
		report["bone_map"] = vr.get("result", vr)
		if vr.has("result") and not bool(vr["result"].get("ready", false)):
			(report["issues"] as Array).append("BoneMap coverage incomplete")
	var score := 1.0
	score -= 0.15 * float((report["issues"] as Array).size())
	if sk:
		score += 0.1
	report["score"] = clampf(score, 0.0, 1.0)
	report["ready_for_gameplay"] = (report["issues"] as Array).size() <= 1 and sk != null
	return success(report)


func _find_sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f := _find_sk(c)
		if f:
			return f
	return null


func _collect_char_nodes(n: Node, root: Node, report: Dictionary) -> void:
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		var names: Array = []
		for libn in ap.get_animation_library_list():
			var lib := ap.get_animation_library(libn)
			if lib:
				for an in lib.get_animation_list():
					names.append(str(an) if str(libn).is_empty() else "%s/%s" % [libn, an])
		(report["animation_players"] as Array).append({
			"path": str(root.get_path_to(ap)),
			"animations": names,
			"count": names.size(),
		})
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		(report["mesh_instances"] as Array).append({
			"path": str(root.get_path_to(mi)),
			"surfaces": mi.mesh.get_surface_count() if mi.mesh else 0,
			"blend_shapes": mi.mesh.get_blend_shape_count() if mi.mesh else 0,
			"has_skin": mi.skin != null,
		})
	for c in n.get_children():
		_collect_char_nodes(c, root, report)
