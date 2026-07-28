@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## 3D asset import depth — human Import dock / Advanced Import Settings workflows.
## Extract meshes, instance as inherited, list scene contents, pack MeshLibraries.


func get_commands() -> Dictionary:
	return {
		"list_imported_scene_contents": _list_imported_scene_contents,
		"extract_meshes_from_scene": _extract_meshes_from_scene,
		"extract_materials_from_scene": _extract_materials_from_scene,
		"instance_scene_as_inherited": _instance_scene_as_inherited,
		"pack_mesh_library_from_scene": _pack_mesh_library_from_scene,
		"create_scene_from_gltf": _create_scene_from_gltf,
		"set_gltf_import_flags": _set_gltf_import_flags,
		"list_3d_import_tools": _list_3d_import_tools,
	}


func _list_3d_import_tools(_params: Dictionary) -> Dictionary:
	return success({
		"pipeline": [
			"stage_files_into_res / ensure_imported for .glb/.gltf/.fbx",
			"apply_scene_import_preset or set_gltf_import_flags",
			"list_imported_scene_contents",
			"extract_meshes_from_scene / extract_materials_from_scene",
			"instance_scene_as_inherited or create_scene_from_gltf",
			"pack_mesh_library_from_scene for GridMap",
		],
		"tools": get_commands().keys(),
	})


func _load_packed_scene(path: String) -> PackedScene:
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _list_imported_scene_contents(params: Dictionary) -> Dictionary:
	## Inventory of MeshInstance3D, Skeleton3D, AnimationPlayer under an imported scene.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var packed := _load_packed_scene(path)
	if packed == null:
		return error_not_found(path, "Need an imported PackedScene (.glb/.gltf/.tscn)")
	var root: Node = packed.instantiate()
	if root == null:
		return error_internal("Failed to instantiate %s" % path)
	var meshes: Array = []
	var skeletons: Array = []
	var anim_players: Array = []
	var lights: Array = []
	var cameras: Array = []
	var other: Array = []
	_walk_import(root, root, meshes, skeletons, anim_players, lights, cameras, other)
	var summary := {
		"path": path,
		"root_type": root.get_class(),
		"root_name": str(root.name),
		"meshes": meshes,
		"skeletons": skeletons,
		"animation_players": anim_players,
		"lights": lights,
		"cameras": cameras,
		"other_count": other.size(),
		"mesh_count": meshes.size(),
	}
	root.free()
	return success(summary)


func _walk_import(node: Node, root: Node, meshes: Array, skeletons: Array, anims: Array, lights: Array, cameras: Array, other: Array) -> void:
	var rel := str(root.get_path_to(node)) if node != root else "."
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		var mesh_path := ""
		if mi.mesh and mi.mesh.resource_path:
			mesh_path = mi.mesh.resource_path
		meshes.append({
			"path": rel,
			"name": str(mi.name),
			"mesh_class": mi.mesh.get_class() if mi.mesh else "",
			"mesh_resource_path": mesh_path,
			"surface_count": mi.mesh.get_surface_count() if mi.mesh else 0,
			"has_skin": mi.skin != null,
			"skeleton_path": str(mi.skeleton) if mi.skeleton != NodePath() else "",
		})
	elif node is Skeleton3D:
		var sk: Skeleton3D = node
		skeletons.append({
			"path": rel,
			"name": str(sk.name),
			"bone_count": sk.get_bone_count(),
		})
	elif node is AnimationPlayer:
		var ap: AnimationPlayer = node
		anims.append({
			"path": rel,
			"name": str(ap.name),
			"animations": ap.get_animation_list(),
		})
	elif node is Light3D:
		lights.append({"path": rel, "type": node.get_class(), "name": str(node.name)})
	elif node is Camera3D:
		cameras.append({"path": rel, "name": str(node.name)})
	elif node != root:
		other.append({"path": rel, "type": node.get_class(), "name": str(node.name)})
	for c in node.get_children():
		_walk_import(c, root, meshes, skeletons, anims, lights, cameras, other)


func _extract_meshes_from_scene(params: Dictionary) -> Dictionary:
	## Save each unique Mesh from MeshInstance3D nodes as res:// .res/.tres files.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var dest_dir: String = optional_string(params, "dest_dir", "res://assets/meshes")
	if not dest_dir.begins_with("res://"):
		dest_dir = "res://" + dest_dir.trim_prefix("/")
	dest_dir = dest_dir.rstrip("/")
	var packed := _load_packed_scene(path)
	if packed == null:
		return error_not_found(path)
	var root: Node = packed.instantiate()
	if root == null:
		return error_internal("instantiate failed")
	var save_as_text: bool = optional_bool(params, "text", false)
	var ext := ".tres" if save_as_text else ".res"
	var extracted: Array = []
	var seen: Dictionary = {}  # mesh instance id -> saved path
	var filter: String = optional_string(params, "name_filter", "")
	_extract_meshes_walk(root, root, dest_dir, ext, filter, seen, extracted)
	root.free()
	EditorInterface.get_resource_filesystem().scan()
	return success({
		"source": path,
		"dest_dir": dest_dir,
		"extracted": extracted,
		"count": extracted.size(),
	})


func _extract_meshes_walk(node: Node, root: Node, dest_dir: String, ext: String, filter: String, seen: Dictionary, out: Array) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			pass
		elif not filter.is_empty() and not str(mi.name).contains(filter) and not str(root.get_path_to(mi)).contains(filter):
			pass
		else:
			var mid := mi.mesh.get_instance_id()
			if seen.has(mid):
				out.append({
					"node": str(root.get_path_to(mi)),
					"mesh_path": seen[mid],
					"duplicate": true,
				})
			else:
				var safe_name := str(mi.name).validate_filename().replace(" ", "_")
				if safe_name.is_empty():
					safe_name = "mesh_%d" % mid
				var out_path := dest_dir + "/" + safe_name + ext
				var n := 1
				while FileAccess.file_exists(out_path):
					out_path = dest_dir + "/" + safe_name + "_%d" % n + ext
					n += 1
					if n > 50:
						break
				var derr := ensure_parent_dir(out_path)
				if derr.is_empty():
					var mesh_copy: Mesh = mi.mesh.duplicate(true)
					var err := ResourceSaver.save(mesh_copy, out_path)
					if err == OK:
						seen[mid] = out_path
						out.append({
							"node": str(root.get_path_to(mi)),
							"mesh_path": out_path,
							"surface_count": mesh_copy.get_surface_count(),
							"class": mesh_copy.get_class(),
						})
					else:
						out.append({"node": str(root.get_path_to(mi)), "error": error_string(err)})
	for c in node.get_children():
		_extract_meshes_walk(c, root, dest_dir, ext, filter, seen, out)


func _extract_materials_from_scene(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var dest_dir: String = optional_string(params, "dest_dir", "res://assets/materials")
	if not dest_dir.begins_with("res://"):
		dest_dir = "res://" + dest_dir.trim_prefix("/")
	dest_dir = dest_dir.rstrip("/")
	var packed := _load_packed_scene(path)
	if packed == null:
		return error_not_found(path)
	var root: Node = packed.instantiate()
	var extracted: Array = []
	var seen: Dictionary = {}
	_extract_mats_walk(root, root, dest_dir, seen, extracted)
	root.free()
	EditorInterface.get_resource_filesystem().scan()
	return success({"source": path, "dest_dir": dest_dir, "extracted": extracted, "count": extracted.size()})


func _extract_mats_walk(node: Node, root: Node, dest_dir: String, seen: Dictionary, out: Array) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(i)
				if mat == null:
					continue
				var mid := mat.get_instance_id()
				if seen.has(mid):
					continue
				var safe := ("%s_surf%d" % [str(mi.name), i]).validate_filename()
				var out_path := dest_dir + "/" + safe + ".tres"
				var derr := ensure_parent_dir(out_path)
				if not derr.is_empty():
					continue
				var copy: Material = mat.duplicate(true)
				if ResourceSaver.save(copy, out_path) == OK:
					seen[mid] = out_path
					out.append({
						"node": str(root.get_path_to(mi)),
						"surface": i,
						"material_path": out_path,
						"class": copy.get_class(),
					})
	for c in node.get_children():
		_extract_mats_walk(c, root, dest_dir, seen, out)


func _instance_scene_as_inherited(params: Dictionary) -> Dictionary:
	## Human: Scene → New Inherited Scene… then save.
	var key := "source_path" if params.has("source_path") else "path"
	var res_path := require_res_path(params, key)
	if res_path[1] != null:
		return res_path[1]
	var source: String = res_path[0]
	var save_path: String = optional_string(params, "save_path", "")
	if save_path.is_empty():
		save_path = source.get_basename() + "_inherited.tscn"
	if not save_path.begins_with("res://"):
		save_path = "res://" + save_path.trim_prefix("/")
	if not ResourceLoader.exists(source):
		return error_not_found(source)
	# Inherited scene file format
	var body := """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="%s" id="1"]

[node name="Root" instance=ExtResource("1")]
""" % source
	# Prefer actual root name from packed scene
	var packed := _load_packed_scene(source)
	if packed:
		var inst: Node = packed.instantiate()
		if inst:
			var rname := str(inst.name)
			body = """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="%s" id="1"]

[node name="%s" instance=ExtResource("1")]
""" % [source, rname]
			# Optional root property overrides
			if params.has("overrides") and params["overrides"] is Dictionary:
				var extra := ""
				for k in params["overrides"]:
					extra += "%s = %s\n" % [str(k), _value_to_tscn(params["overrides"][k])]
				body = body.rstrip() + "\n" + extra
			inst.free()
	if FileAccess.file_exists(save_path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % save_path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(save_path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % save_path)
	f.store_string(body)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(save_path)
	var open_it: bool = optional_bool(params, "open", true)
	if open_it:
		EditorInterface.open_scene_from_path(save_path)
	return success({
		"source_path": source,
		"save_path": save_path,
		"opened": open_it,
		"type": "inherited_scene",
	})


func _value_to_tscn(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT, TYPE_FLOAT:
			return str(v)
		TYPE_STRING:
			return "\"%s\"" % str(v).c_escape()
		TYPE_VECTOR3:
			var vec: Vector3 = v
			return "Vector3(%s, %s, %s)" % [vec.x, vec.y, vec.z]
		TYPE_VECTOR2:
			var v2: Vector2 = v
			return "Vector2(%s, %s)" % [v2.x, v2.y]
		_:
			if v is Array and v.size() >= 3:
				return "Vector3(%s, %s, %s)" % [v[0], v[1], v[2]]
			return "\"%s\"" % str(v).c_escape()


func _pack_mesh_library_from_scene(params: Dictionary) -> Dictionary:
	## Collect MeshInstance3D meshes into a MeshLibrary for GridMap.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var out_path: String = optional_string(params, "output_path", "res://assets/mesh_library.tres")
	if not out_path.begins_with("res://"):
		out_path = "res://" + out_path.trim_prefix("/")
	var packed := _load_packed_scene(path)
	if packed == null:
		return error_not_found(path)
	var root: Node = packed.instantiate()
	var lib := MeshLibrary.new()
	var item_id := 0
	var items: Array = []
	_collect_for_library(root, root, lib, item_id, items)
	# item_id updated by ref via items size
	root.free()
	var derr := ensure_parent_dir(out_path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(lib, out_path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(out_path)
	return success({"output_path": out_path, "items": items, "count": items.size()})


func _collect_for_library(node: Node, root: Node, lib: MeshLibrary, _start_id: int, items: Array) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh:
			var id := items.size()
			lib.create_item(id)
			lib.set_item_mesh(id, mi.mesh)
			lib.set_item_name(id, str(mi.name))
			# Optional collision from mesh
			if mi.mesh is ArrayMesh:
				var shape := mi.mesh.create_trimesh_shape()
				if shape:
					lib.set_item_shapes(id, [shape, Transform3D.IDENTITY])
			items.append({"id": id, "name": str(mi.name), "node": str(root.get_path_to(mi))})
	for c in node.get_children():
		_collect_for_library(c, root, lib, _start_id, items)


func _create_scene_from_gltf(params: Dictionary) -> Dictionary:
	## Instance imported glTF into a new editable .tscn (not inherited — full copy of tree as editable).
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var save_path: String = optional_string(params, "save_path", path.get_basename() + ".tscn")
	if not save_path.begins_with("res://"):
		save_path = "res://" + save_path.trim_prefix("/")
	var mode: String = optional_string(params, "mode", "inherited")  # inherited|editable
	if mode == "inherited":
		return _instance_scene_as_inherited({
			"source_path": path,
			"save_path": save_path,
			"overwrite": optional_bool(params, "overwrite", false),
			"open": optional_bool(params, "open", true),
		})
	# Editable: instantiate and pack as new scene (breaks inheritance)
	var packed := _load_packed_scene(path)
	if packed == null:
		return error_not_found(path)
	var inst: Node = packed.instantiate()
	if inst == null:
		return error_internal("instantiate failed")
	_set_owner_recursive(inst, inst)
	var new_packed := PackedScene.new()
	var pack_err := new_packed.pack(inst)
	inst.free()
	if pack_err != OK:
		return error_internal("pack failed: %s" % error_string(pack_err))
	if FileAccess.file_exists(save_path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % save_path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(save_path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(new_packed, save_path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(save_path)
	if optional_bool(params, "open", true):
		EditorInterface.open_scene_from_path(save_path)
	return success({"source": path, "save_path": save_path, "mode": "editable"})


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner_recursive(c, owner)


func _set_gltf_import_flags(params: Dictionary) -> Dictionary:
	## Higher-level glTF/FBX import flags written to .import then reimport.
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var options: Dictionary = {}
	if params.has("import_animations"):
		options["animation/import"] = bool(params["import_animations"])
	if params.has("fps"):
		options["animation/fps"] = int(params["fps"])
	if params.has("ensure_tangents"):
		options["meshes/ensure_tangents"] = bool(params["ensure_tangents"])
	if params.has("generate_lods"):
		options["meshes/generate_lods"] = bool(params["generate_lods"])
	if params.has("create_shadow_meshes"):
		options["meshes/create_shadow_meshes"] = bool(params["create_shadow_meshes"])
	if params.has("light_baking"):
		# 0 disabled, 1 static, 2 dynamic (varies)
		options["meshes/light_baking"] = int(params["light_baking"]) if params["light_baking"] is int else params["light_baking"]
	if params.has("root_type"):
		options["nodes/root_type"] = str(params["root_type"])
	if params.has("root_name"):
		options["nodes/root_name"] = str(params["root_name"])
	if params.has("use_named_skin_binds"):
		options["skins/use_named_skins"] = bool(params["use_named_skin_binds"])
	if params.has("import_as_skeleton_bones"):
		options["nodes/import_as_skeleton_bones"] = bool(params["import_as_skeleton_bones"])
	if params.has("extra") and params["extra"] is Dictionary:
		for k in params["extra"]:
			options[str(k)] = params["extra"][k]
	if options.is_empty():
		return error_invalid_params("Provide flags: import_animations, fps, ensure_tangents, generate_lods, create_shadow_meshes, root_type, extra{}")
	# Reuse import_commands path via project filesystem — write .import directly
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return error_not_found(import_path, "Import the asset first (ensure_imported)")
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return error_internal("Cannot load .import")
	var changed: Array = []
	for k in options:
		var old = cfg.get_value("params", k) if cfg.has_section_key("params", k) else null
		cfg.set_value("params", k, options[k])
		changed.append({"key": k, "old": old, "new": options[k]})
	if cfg.save(import_path) != OK:
		return error_internal("Cannot save .import")
	var reimport: bool = optional_bool(params, "reimport", true)
	if reimport:
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.reimport_files(PackedStringArray([path]))
	return success({"path": path, "changed": changed, "reimport_started": reimport})
